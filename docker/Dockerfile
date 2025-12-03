# ===================================================================
# ALN Programming Language Dockerfile v12.0.0 (PRODUCTION)
# Hardened Sovereign Replication Executor + ALN Runtime Environment
# ===================================================================

# -------------------- Stage 1: Build Executor ---------------------
FROM ubuntu:22.04 as executor

LABEL maintainer="jacob-scott-farmer"
LABEL description="Universal sovereign replication protocol executor with JSF/ALN compatibility"

RUN apt-get update && apt-get install -y \
    jq \
    openssl \
    bash \
    coreutils \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Add executor binary/script
WORKDIR /executor
COPY tools/jsf-exec.sh /usr/local/bin/jsf-exec
RUN chmod +x /usr/local/bin/jsf-exec


# -------------------- Stage 2: ALN Runtime ------------------------
FROM alpine:3.19

# Environment variables
ENV ALN_VERSION="12.0.0" \
    ALN_RUNTIME="12.0.0" \
    COMPLIANCE_MODE="FULL" \
    COMPLIANCE_SCORE_THRESHOLD="98.5" \
    SYSTEM_HEALTH_THRESHOLD="95.0" \
    DEPENDENCY_VERSION="12.0.0" \
    ALN_ENVIRONMENT="production" \
    PYTHONUNBUFFERED="1" \
    TZ="America/New_York" \
    ALN_LOG_LEVEL="info" \
    ALN_SECURITY_LEVEL="quantum_stealth" \
    ALN_COMPLIANCE_ENFORCE="true" \
    ALN_BUILD_MODE="production" \
    ALN_API_KEY_OPENAI="" \
    ALN_API_KEY_ANTHROPIC="" \
    ALN_API_KEY_QWEN="" \
    ALN_API_KEY_MISTRAL=""

# Create ALN app dir
WORKDIR /app/aln

# Copy executor binary from ubuntu stage
COPY --from=executor /usr/local/bin/jsf-exec /usr/local/bin/jsf-exec

# Copy application files
COPY . /app/aln

# Install runtime dependencies (Alpine-based)
RUN apk add --no-cache \
    curl \
    openssl \
    bash \
    openssh \
    ca-certificates \
    jq \
    coreutils \
    && update-ca-certificates

# Set permissions for startup and healthcheck scripts
RUN chmod +x /app/aln/start.sh && \
    chmod +x /app/aln/healthcheck.sh

# Expose services
EXPOSE 8080
EXPOSE 8443

# Define entrypoint (runs ALN runtime stack by default)
ENTRYPOINT ["/app/aln/start.sh"]
