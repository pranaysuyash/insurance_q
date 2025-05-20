FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install essential system dependencies
# build-essential might be needed for some pip packages
# curl is a general utility, kept for now but can be reviewed
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
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