# doctr's Torch/torchvision CPU kernels are verified in the Linux x86_64
# runtime used by Cloud Run/App Runner/Azure. Keep the OCR image architecture
# explicit: an ARM64 developer image can import Torch but segfault in the
# torchvision model forward path under Docker's Linux ARM64 wheel.
ARG OCR_PLATFORM=linux/amd64
FROM --platform=${OCR_PLATFORM} python:3.11-slim
ARG OCR_PLATFORM

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libfontconfig1 \
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libcairo2 \
    libgdk-pixbuf-2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy the declared sources and the Linux release lock first (for better Docker
# caching and reproducible image builds).
COPY requirements.txt requirements-production-ocr.txt requirements-production-ocr-linux-x86_64.lock ./

# Install the canonical customer-facing production profile. OCR is part of the
# document contract; keeping it out of this image would make scanned-policy
# behavior differ between local and deployed environments.
RUN pip install --upgrade pip && \
    test "$(uname -m)" = "x86_64" && \
    pip install --no-cache-dir --timeout 1000 --retries 5 --require-hashes \
      --extra-index-url https://download.pytorch.org/whl/cpu \
      -r requirements-production-ocr-linux-x86_64.lock

# Copy application code and the canonical, versioned legal documents rendered
# by the public frontend. Do not copy a second legal-content representation.
COPY src/ src/
COPY docs/legal/ docs/legal/

# Create necessary directories
RUN mkdir -p /app/uploads /app/temp /app/storage/documents

# Set Python path
ENV PYTHONPATH="/app"
ENV PLATFORM="${OCR_PLATFORM}"

# Create a non-root user and switch to it for defense-in-depth.
# Cloud Run provides runtime isolation, but a Python RCE should not give
# an attacker root inside the container (CSO Finding #1).
RUN adduser --disabled-password --gecos "" coverwise && \
    chown -R coverwise:coverwise /app
USER coverwise

# Cloud Run injects PORT at runtime; 8080 is the local fallback.
EXPOSE 8080

CMD ["sh", "-c", "uvicorn src.app.main:app --host 0.0.0.0 --port ${PORT:-8080} --log-level info"]
