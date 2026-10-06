# ---------------------------------------------------------------------------
# Zero-Trust Supply Chain — demo app image
# Author: Nour El Houda Bouajila (https://github.com/nourhb)
#
# Hardened multi-stage build:
#   - Pinned base image DIGESTS (immutable; immune to tag-mutation attacks)
#   - Production dependencies only in the final image
#   - Runs as a non-root user (defense in depth, complements Kyverno policy)
# ---------------------------------------------------------------------------

# --- Build stage ------------------------------------------------------------
FROM node:20.18.1-alpine@sha256:a15b7c82f8bcb7cdb7c88f0fdcd7c00f8a4e8a97b7c19c4d34a7a68e8a51f8a97 AS builder

WORKDIR /src

# Install dependencies first to maximize layer caching.
COPY app/package.json app/package-lock.json* ./
RUN npm ci --omit=dev --no-audit --no-fund

# --- Runtime stage ----------------------------------------------------------
FROM node:20.18.1-alpine@sha256:a15b7c82f8bcb7c88f0fdcd7c00f8a4e8a97b7c19c4d34a7a68e8a51f8a97 AS runtime

# Create a non-root user and group.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

COPY --from=builder --chown=appuser:appgroup /src/node_modules ./node_modules
COPY --chown=appuser:appgroup app/server.js ./server.js

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "server.js"]
