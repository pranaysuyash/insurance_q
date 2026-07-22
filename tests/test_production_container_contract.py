"""Regression contracts for the customer-facing container profile."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_canonical_container_installs_ocr_enabled_profile_and_linux_runtime_libs():
    dockerfile = (ROOT / "Dockerfile").read_text(encoding="utf-8")

    assert "requirements-production-ocr.txt" in dockerfile
    assert "ARG OCR_PLATFORM=linux/amd64" in dockerfile
    assert "FROM --platform=${OCR_PLATFORM} python:3.11-slim" in dockerfile
    assert "libgl1" in dockerfile
    assert "libpangoft2-1.0-0" in dockerfile
    assert "libgdk-pixbuf-2.0-0" in dockerfile
    assert "download.pytorch.org/whl/cpu" in dockerfile
    assert 'ENV PLATFORM="${OCR_PLATFORM}"' in dockerfile


def test_production_ocr_profile_is_pinned_and_reuses_slim_core_contract():
    profile = (ROOT / "requirements-production-ocr.txt").read_text(encoding="utf-8")

    assert "-r requirements.txt" in profile
    assert "torch==2.1.0" in profile
    assert "torchvision==0.16.0" in profile
    assert "python-doctr[torch]==0.7.0" in profile
    requirements = (ROOT / "requirements.txt").read_text(encoding="utf-8")
    assert "redis==5.0.1" in requirements


def test_cloud_run_and_legacy_generated_images_use_model_bearing_memory_budget():
    cloud_run = (ROOT / "tools/deploy_cloud_run.sh").read_text(encoding="utf-8")
    aws = (ROOT / "deploy_aws_multiarch.sh").read_text(encoding="utf-8")
    app_runner = (ROOT / "deploy_enhanced_rag.sh").read_text(encoding="utf-8")
    azure = (ROOT / "scripts/deploy_full_backend_to_azure.sh").read_text(encoding="utf-8")

    assert 'COVERWISE_CLOUD_RUN_MEMORY:-4Gi' in cloud_run
    assert '"Memory": "4096"' in aws
    assert '"Memory": "4096"' in app_runner
    assert "requirements-production-ocr.txt" in aws
    assert "requirements-production-ocr.txt" in azure
    assert "download.pytorch.org/whl/cpu" in aws
    assert "download.pytorch.org/whl/cpu" in azure
