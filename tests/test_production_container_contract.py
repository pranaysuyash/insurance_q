"""Regression contracts for the customer-facing container profile."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_canonical_container_installs_ocr_enabled_profile_and_linux_runtime_libs():
    dockerfile = (ROOT / "Dockerfile").read_text(encoding="utf-8")

    assert "requirements-production-ocr-linux-x86_64.lock" in dockerfile
    assert "ARG OCR_PLATFORM=linux/amd64" in dockerfile
    assert "FROM --platform=${OCR_PLATFORM} python:3.11-slim" in dockerfile
    assert "libgl1" in dockerfile
    assert "libpangoft2-1.0-0" in dockerfile
    assert "libgdk-pixbuf-2.0-0" in dockerfile
    assert "download.pytorch.org/whl/cpu" in dockerfile
    assert "--require-hashes" in dockerfile
    assert 'ENV PLATFORM="${OCR_PLATFORM}"' in dockerfile
    assert "COPY docs/legal/ docs/legal/" in dockerfile


def test_production_ocr_profile_is_pinned_and_reuses_slim_core_contract():
    profile = (ROOT / "requirements-production-ocr.txt").read_text(encoding="utf-8")

    assert "-r requirements.txt" in profile
    assert "torch==2.1.0" in profile
    assert "torchvision==0.16.0" in profile
    assert "python-doctr==1.0.1" in profile
    requirements = (ROOT / "requirements.txt").read_text(encoding="utf-8")
    assert "redis==5.0.1" in requirements
    assert "PyJWT==2.13.0" in requirements
    assert "python-jose" not in requirements
    lock = (ROOT / "requirements-production-ocr-linux-x86_64.lock").read_text(
        encoding="utf-8"
    )
    assert "torch==2.1.0+cpu" in lock
    assert "--hash=sha256:" in lock


def test_cloud_run_deploy_image_uses_model_bearing_memory_budget():
    # Canonical deploy path is Cloud Run + Supabase. The legacy AWS App Runner
    # and Azure deploy scripts were agent-built dead paths and have been removed,
    # so this contract now guards only the canonical Cloud Run deploy script.
    cloud_run = (ROOT / "tools/deploy_cloud_run.sh").read_text(encoding="utf-8")
    assert 'COVERWISE_CLOUD_RUN_MEMORY:-4Gi' in cloud_run


def test_production_sbom_generator_uses_the_canonical_locked_linux_profile():
    generator = (ROOT / "tools" / "generate_production_sbom.sh").read_text(
        encoding="utf-8"
    )

    assert "requirements-production-ocr-linux-x86_64.lock" in generator
    assert "--require-hashes" in generator
    assert "--format cyclonedx-json" in generator
    assert "not treated as a passing audit" in generator
