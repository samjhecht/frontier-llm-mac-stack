FROM rust:1.75-slim AS builder

WORKDIR /app

COPY Cargo.toml ./
COPY src ./src

RUN cargo build --release

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/mistral-ollama-proxy /app/

EXPOSE 11434

ENV MISTRAL_URL=http://mistral:8080
ENV BIND_ADDRESS=0.0.0.0:11434

CMD ["/app/mistral-ollama-proxy"]