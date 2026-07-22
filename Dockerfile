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

# Copy requirements first (for better Docker caching)
COPY requirements.txt requirements-production-ocr.txt .

# Install the canonical customer-facing production profile. OCR is part of the
# document contract; keeping it out of this image would make scanned-policy
# behavior differ between local and deployed environments.
RUN pip install --upgrade pip && \
    if [ "$(uname -m)" = "x86_64" ]; then \
      pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu \
        torch==2.1.0 torchvision==0.16.0; \
    fi && \
    pip install --no-cache-dir --timeout 1000 --retries 5 -r requirements-production-ocr.txt

# Copy application code
COPY src/ src/

# Create necessary directories
RUN mkdir -p /app/uploads /app/temp /app/storage/documents

# Set Python path
ENV PYTHONPATH="/app"
ENV PLATFORM="${OCR_PLATFORM}"

# Cloud Run injects PORT at runtime; 8080 is the local fallback.
EXPOSE 8080

CMD ["sh", "-c", "uvicorn src.app.main:app --host 0.0.0.0 --port ${PORT:-8080} --log-level info"]
