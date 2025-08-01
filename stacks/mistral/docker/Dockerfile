FROM rust:1.75-slim as builder

# Install required dependencies for building
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    curl \
    git \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone and build mistral.rs
WORKDIR /build
ARG MISTRAL_RS_VERSION=v0.6.0
RUN git clone --depth 1 --branch ${MISTRAL_RS_VERSION} https://github.com/EricLBuehler/mistral.rs.git
WORKDIR /build/mistral.rs

# Build the mistralrs-server binary
RUN cargo build --release --features cuda

# Runtime stage
ARG CUDA_VERSION=12.2.0
FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the built binary
COPY --from=builder /build/mistral.rs/target/release/mistralrs-server /usr/local/bin/mistralrs-server

# Create directories for models and config
RUN mkdir -p /models /config

# Set environment variables
ENV MISTRAL_MODEL_PATH=/models
ENV RUST_LOG=info

# Expose the default port
EXPOSE 11434

# Health check endpoint - using OpenAI-compatible models endpoint
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:11434/v1/models || exit 1

# Run the server
ENTRYPOINT ["mistralrs-server"]
CMD ["--port", "11434", "--model-path", "/models"]