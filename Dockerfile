FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install essential system dependencies
# build-essential might be needed for some pip packages
# curl is a general utility, kept for now but can be reviewed
# libgl1-mesa-glx, libglib2.0-0, and others are needed for OpenCV and other vision libs
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libgtk2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ src/

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Default command (will be overridden by docker-compose)
CMD ["uvicorn", "src.rag.service:app", "--host", "0.0.0.0", "--port", "8000"] 