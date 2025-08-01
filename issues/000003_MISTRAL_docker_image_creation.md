# MISTRAL_000003: Create Mistral.rs Docker Image

## Objective
Create a custom Docker image for Mistral.rs that includes all necessary dependencies and configurations for running the inference server.

## Context
Mistral.rs requires Rust and specific system dependencies. We need to create an optimized Docker image that can run on Mac Studio with proper GPU/Metal support.

## Tasks

### 1. Create Base Dockerfile
- Create `stacks/mistral/docker/Dockerfile`
- Use multi-stage build for optimization
- Include Rust toolchain and build dependencies
- Add OpenSSL and other required system libraries

### 2. Build Mistral.rs from Source
- Clone mistral.rs repository in build stage
- Configure for optimal Mac Studio performance
- Enable Metal acceleration support
- Build release binary with appropriate features

### 3. Create Runtime Image
- Use minimal base image for runtime
- Copy only necessary binaries and libraries
- Set up model storage volume mount points
- Configure environment variables

### 4. Add Health Check and Entrypoint
- Create entrypoint script for flexible configuration
- Implement health check endpoint verification
- Add graceful shutdown handling
- Support for dynamic model loading

## Implementation Details

```dockerfile
# stacks/mistral/docker/Dockerfile
FROM rust:1.75 as builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Clone and build mistral.rs
WORKDIR /build
RUN git clone https://github.com/EricLBuehler/mistral.rs.git
WORKDIR /build/mistral.rs

# Build with Metal support for Mac
RUN cargo build --release --features metal

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libssl3 \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy binary
COPY --from=builder /build/mistral.rs/target/release/mistralrs-server /usr/local/bin/

# Create model directory
RUN mkdir -p /models

# Set environment
ENV MISTRAL_MODELS_PATH=/models
ENV RUST_LOG=info

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/mistralrs-server"]
```

## Success Criteria
- Docker image builds successfully
- Mistral.rs server starts and responds to health checks
- Models can be loaded from mounted volumes
- Performance is optimized for Mac Studio hardware

## Estimated Changes
- ~100 lines of Dockerfile
- ~50 lines of entrypoint script
- Configuration files