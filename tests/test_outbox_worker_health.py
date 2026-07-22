"""Tests for the Cloud Run worker's non-mutating health contract."""

from __future__ import annotations

import asyncio
from unittest.mock import MagicMock, patch

from src.models.job_outbox import JobType
from src.workers.outbox_worker import _health_client


def _probe(path: str) -> bytes:
    async def run() -> bytes:
        server = await asyncio.start_server(_health_client, "127.0.0.1", 0)
        port = server.sockets[0].getsockname()[1]
        try:
            reader, writer = await asyncio.open_connection("127.0.0.1", port)
            writer.write(f"GET {path} HTTP/1.1\r\nHost: worker\r\n\r\n".encode())
            await writer.drain()
            response = await reader.read()
            writer.close()
            await writer.wait_closed()
            return response
        finally:
            server.close()
            await server.wait_closed()

    return asyncio.run(run())


def test_worker_health_listener_returns_ready_for_cloud_run_probe():
    response = _probe("/readyz")
    assert response.startswith(b"HTTP/1.1 200 OK")
    assert b'"worker":"outbox"' in response


def test_worker_health_listener_does_not_expose_unknown_routes():
    response = _probe("/admin")
    assert response.startswith(b"HTTP/1.1 404 Not Found")


def test_account_deletion_handler_is_async_boundary():
    from src.workers.outbox_worker import _register_handlers

    dispatcher = MagicMock()
    with patch(
        "src.services.account_lifecycle_service.process_deletion"
    ) as process:
        _register_handlers(dispatcher)
    handlers = {
        call.args[0]: call.args[1]
        for call in dispatcher.register.call_args_list
    }
    handler = handlers[JobType.ACCOUNT_DELETION]
    job = MagicMock()
    job.payload = {"request_id": "request-1", "account_uid": "account-1"}

    async def run():
        await handler(job)
        process.assert_called_once_with("request-1", "account-1")

    asyncio.run(run())
