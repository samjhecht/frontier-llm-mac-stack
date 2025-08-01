# Unified Dockerfile for mistral.rs with configurable build modes
# Usage:
#   CUDA build: docker build --build-arg BUILD_MODE=cuda --build-arg BUILD_FEATURES=cuda .
#   Metal build: docker build --build-arg BUILD_MODE=metal --build-arg BUILD_FEATURES=metal --build-arg MISTRAL_RS_VERSION=v0.5.0 .
#   Prebuilt: docker build --build-arg BUILD_MODE=prebuilt -f Dockerfile.prebuilt .

ARG BUILD_MODE=cuda
ARG MISTRAL_RS_VERSION=v0.6.0
ARG BUILD_FEATURES=cuda
ARG RUNTIME_BASE=nvidia/cuda:12.2.0-runtime-ubuntu22.04

# Builder stage - only used for source builds
FROM rust:1.84-slim as builder
ARG MISTRAL_RS_VERSION
ARG BUILD_FEATURES

# Install required dependencies for building
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    curl \
    git \
    pkg-config \
    libssl-dev \
    python3 \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone and build mistral.rs
WORKDIR /build
RUN git clone --depth 1 --branch ${MISTRAL_RS_VERSION} https://github.com/EricLBuehler/mistral.rs.git
WORKDIR /build/mistral.rs

# Build the mistralrs-server binary
RUN cargo build --release --features ${BUILD_FEATURES}

# Runtime stage
FROM ${RUNTIME_BASE}
ARG BUILD_MODE
ARG USE_V5_MODE=false

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the built binary
COPY --from=builder /build/mistral.rs/target/release/mistralrs-server /usr/local/bin/mistralrs-server

# Copy entrypoint script
COPY docker-entrypoint-unified.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Create directories for models and config
RUN mkdir -p /models /config

# Set environment variables
ENV MISTRAL_MODEL_PATH=/models
ENV RUST_LOG=info
ENV MISTRAL_PORT=8080
ENV MISTRAL_USE_V5_MODE=${USE_V5_MODE}

# Expose the default port
EXPOSE 8080

# Health check endpoint - using OpenAI-compatible models endpoint
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8080/v1/models || exit 1

# Use entrypoint script for flexible configuration
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]