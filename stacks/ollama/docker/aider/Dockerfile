FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Install aider
RUN pip install --no-cache-dir aider-chat

# Create workspace directory
RUN mkdir -p /workspace

# Set working directory
WORKDIR /workspace

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Default command
CMD ["/bin/bash"]