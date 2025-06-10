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

# Install Python dependencies with extended timeout and retries
RUN pip install --upgrade pip && \
    pip install --no-cache-dir --timeout 1000 --retries 5 -r requirements.txt

# Copy application code
COPY src/ src/

# Create necessary directories
RUN mkdir -p /app/uploads /app/temp

# Set Python path
ENV PYTHONPATH="/app"

# Expose port (this will be overridden by Azure App Service)
EXPOSE 8000

# Default command (will be overridden by startup command in Azure)
CMD ["uvicorn", "src.app.main:app", "--host", "0.0.0.0", "--port", "8000", "--log-level", "info"] 