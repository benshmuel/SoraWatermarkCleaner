# Use Python 3.12 slim image
FROM python:3.12-slim

# Install system dependencies including FFmpeg
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install uv for faster dependency installation
RUN pip install --no-cache-dir uv

# Copy project files
COPY pyproject.toml ./
COPY sorawm ./sorawm
COPY resources ./resources
COPY start_server.py ./

# Install Python dependencies using uv
RUN uv pip install --system --no-cache -r pyproject.toml

# Create necessary directories
RUN mkdir -p /app/outputs /app/logs /app/uploads

# Expose port (Cloud Run will set PORT env variable)
ENV PORT=8080
EXPOSE 8080

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"

# Run the server
CMD python start_server.py --host 0.0.0.0 --port ${PORT} --workers 1

