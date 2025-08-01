FROM rust:1.84-slim as builder

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
# Use v0.5.0 which doesn't have the edition2024 dependency issue
ARG MISTRAL_RS_VERSION=v0.5.0
RUN git clone --depth 1 --branch ${MISTRAL_RS_VERSION} https://github.com/EricLBuehler/mistral.rs.git
WORKDIR /build/mistral.rs

# Build the mistralrs-server binary
# Note: Metal feature requires macOS to actually use Metal, but we can build with the feature flag
# For Linux builds, this will compile but Metal won't be available at runtime
RUN cargo build --release --features metal || \
    cargo build --release

# Runtime stage - using debian slim for smaller image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the built binary
COPY --from=builder /build/mistral.rs/target/release/mistralrs-server /usr/local/bin/mistralrs-server

# Copy entrypoint script
COPY docker-entrypoint-v5.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Create directories for models and config
RUN mkdir -p /models /config

# Set environment variables
ENV MISTRAL_MODEL_PATH=/models
ENV RUST_LOG=info
ENV MISTRAL_PORT=11434

# Expose the default port (compatible with Ollama)
EXPOSE 11434

# Health check endpoint - using OpenAI-compatible models endpoint
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:${MISTRAL_PORT}/v1/models || exit 1

# Use entrypoint script for flexible configuration
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]