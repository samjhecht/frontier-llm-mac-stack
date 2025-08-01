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


## Proposed Solution

After analyzing the existing code and mistral.rs capabilities, I will implement the following:

1. **Create a Metal-enabled Dockerfile** - Update the existing Dockerfile to build with Metal support instead of CUDA for Mac Studio compatibility
2. **Create a flexible entrypoint script** - Build an entrypoint that can handle various configuration options and model loading scenarios
3. **Update build script** - Modify the build script to support both CUDA and Metal builds based on the target platform
4. **Add health check implementation** - Ensure proper health checking against the mistral.rs server endpoints

### Implementation Steps:

1. Create a new Dockerfile that:
   - Uses multi-stage build with Rust base image
   - Builds mistral.rs with `metal` feature for Mac acceleration
   - Creates a minimal runtime image
   - Properly configures model paths and environment variables

2. Create an entrypoint script that:
   - Supports dynamic configuration via environment variables
   - Handles model loading parameters
   - Implements graceful shutdown
   - Provides flexible server startup options

3. Update the build script to:
   - Detect the target platform (Mac vs Linux)
   - Build appropriate Docker image based on platform
   - Skip NVIDIA runtime check on Mac
   - Tag images appropriately

4. Test the complete solution:
   - Verify Docker image builds successfully
   - Ensure mistral.rs server starts properly
   - Test health check endpoint
   - Verify Metal acceleration is available