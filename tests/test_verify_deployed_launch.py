"""Regression tests for the release-gating deployed launch verifier."""

from __future__ import annotations

import sys
from unittest.mock import Mock

import tools.verify_deployed_launch as verifier


def test_request_accepts_empty_success_body(monkeypatch):
    response = Mock()
    response.status = 204
    response.headers.items.return_value = []
    response.read.return_value = b""

    context = Mock()
    context.__enter__ = Mock(return_value=response)
    context.__exit__ = Mock(return_value=False)
    monkeypatch.setattr(verifier, "urlopen", Mock(return_value=context))

    status, headers, payload = verifier.request(
        "https://api.example", "/healthz", method="OPTIONS", origin="https://app.example"
    )

    assert status == 204
    assert headers == {}
    assert payload == {}


def test_deployed_verifier_fails_when_health_is_degraded(monkeypatch):
    calls: list[tuple[str, str]] = []

    def fake_request(base_url: str, path: str, **kwargs):
        calls.append((kwargs.get("method", "GET"), path))
        if path == "/healthz":
            return 200, {}, {"status": "live", "version": "2.0.0"}
        if path == "/readyz":
            return 200, {}, {"status": "ready"}
        if path == "/health":
            return 503, {}, {"status": "degraded"}
        if path == "/documents?page=1&limit=10" and "token" not in kwargs:
            return 401, {}, {}
        if path == "/user/anonymous":
            index = sum(1 for _, called_path in calls if called_path == path)
            return 200, {}, {
                "access_token": f"token-{index}",
                "user": {"uid": f"anon:{index}"},
            }
        if path == "/user/profile":
            token = kwargs["token"]
            index = token.rsplit("-", 1)[-1]
            return 200, {}, {"uid": f"anon:{index}"}
        if path == "/documents?page=1&limit=10":
            return 200, {}, {"documents": []}
        raise AssertionError(f"unexpected request: {path} {kwargs}")

    monkeypatch.setattr(verifier, "request", fake_request)
    monkeypatch.setattr(sys, "argv", ["verify_deployed_launch.py", "--base-url", "https://api.example", "--allow-identity-creation"])

    assert verifier.main() == 1
    assert ("GET", "/health") in calls


def test_deployed_verifier_accepts_healthy_service(monkeypatch):
    def fake_request(base_url: str, path: str, **kwargs):
        if path == "/healthz":
            return 200, {}, {"status": "live", "version": "2.0.0"}
        if path == "/readyz":
            return 200, {}, {"status": "ready"}
        if path == "/health":
            return 200, {}, {"status": "ok"}
        if path == "/documents?page=1&limit=10" and "token" not in kwargs:
            return 401, {}, {}
        if path == "/user/anonymous":
            index = fake_request.identity_count
            fake_request.identity_count += 1
            return 200, {}, {
                "access_token": f"token-{index}",
                "user": {"uid": f"anon:{index}"},
            }
        if path == "/user/profile":
            index = kwargs["token"].rsplit("-", 1)[-1]
            return 200, {}, {"uid": f"anon:{index}"}
        if path == "/documents?page=1&limit=10":
            return 200, {}, {"documents": []}
        raise AssertionError(f"unexpected request: {path} {kwargs}")

    fake_request.identity_count = 0
    monkeypatch.setattr(verifier, "request", fake_request)
    monkeypatch.setattr(sys, "argv", ["verify_deployed_launch.py", "--base-url", "https://api.example", "--allow-identity-creation"])

    assert verifier.main() == 0


def test_deployed_verifier_can_gate_internal_outbox_worker(monkeypatch):
    def fake_request(base_url: str, path: str, **kwargs):
        if base_url == "https://worker.internal" and path == "/readyz":
            return 200, {}, {"status": "ready", "worker": "outbox"}
        if path == "/healthz":
            return 200, {}, {"status": "live", "version": "2.0.0"}
        if path == "/readyz":
            return 200, {}, {"status": "ready"}
        if path == "/health":
            return 200, {}, {"status": "ok"}
        if path == "/documents?page=1&limit=10" and "token" not in kwargs:
            return 401, {}, {}
        if path == "/user/anonymous":
            index = fake_request.identity_count
            fake_request.identity_count += 1
            return 200, {}, {
                "access_token": f"token-{index}",
                "user": {"uid": f"anon:{index}"},
            }
        if path == "/user/profile":
            index = kwargs["token"].rsplit("-", 1)[-1]
            return 200, {}, {"uid": f"anon:{index}"}
        if path == "/documents?page=1&limit=10":
            return 200, {}, {"documents": []}
        raise AssertionError(f"unexpected request: {base_url} {path} {kwargs}")

    fake_request.identity_count = 0
    monkeypatch.setattr(verifier, "request", fake_request)
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "verify_deployed_launch.py",
            "--base-url",
            "https://api.example",
            "--worker-url",
            "https://worker.internal",
            "--allow-identity-creation",
        ],
    )

    assert verifier.main() == 0


def test_deployed_verifier_default_does_not_create_identities(monkeypatch):
    calls = []

    def fake_request(base_url: str, path: str, **kwargs):
        calls.append((path, kwargs.get("method", "GET")))
        if path == "/healthz":
            return 200, {}, {"status": "live", "version": "2.0.0"}
        if path == "/readyz":
            return 200, {}, {"status": "ready"}
        if path == "/health":
            return 200, {}, {"status": "ok"}
        if path == "/documents?page=1&limit=10":
            return 401, {}, {}
        raise AssertionError(f"unexpected request: {path} {kwargs}")

    monkeypatch.setattr(verifier, "request", fake_request)
    monkeypatch.setattr(sys, "argv", ["verify_deployed_launch.py", "--base-url", "https://api.example"])

    assert verifier.main() == 0
    assert ("/user/anonymous", "POST") not in calls


def test_deployed_verifier_rejects_non_https_urls_without_requests(monkeypatch):
    monkeypatch.setattr(
        verifier,
        "request",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("non-HTTPS URL must not be requested")
        ),
    )
    monkeypatch.setattr(
        sys,
        "argv",
        ["verify_deployed_launch.py", "--base-url", "http://api.example"],
    )

    assert verifier.main() == 2


def test_deployed_verifier_requires_worker_url_when_requested(monkeypatch):
    monkeypatch.setattr(
        verifier,
        "request",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("missing worker URL must fail before requests")
        ),
    )
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "verify_deployed_launch.py",
            "--base-url",
            "https://api.example",
            "--require-worker",
        ],
    )

    assert verifier.main() == 2
