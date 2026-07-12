FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    software-properties-common \
    git \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (for better Docker caching)
COPY requirements.txt .

# Install the production dependency set. Local OCR/ML extras stay outside the
# Cloud Run image so the single runtime remains smaller and cheaper to start.
RUN pip install --upgrade pip && \
    pip install --no-cache-dir --timeout 1000 --retries 5 -r requirements.txt

# Copy application code
COPY src/ src/

# Create necessary directories
RUN mkdir -p /app/uploads /app/temp /app/storage/documents

# Set Python path
ENV PYTHONPATH="/app"

# Cloud Run injects PORT at runtime; 8080 is the local fallback.
EXPOSE 8080

CMD ["sh", "-c", "uvicorn src.app.main:app --host 0.0.0.0 --port ${PORT:-8080} --log-level info"]
