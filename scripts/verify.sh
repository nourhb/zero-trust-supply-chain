#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Zero-Trust Supply Chain — manual verification script
# Author: Nour El Houda Bouajila (https://github.com/nourhb)
#
# Verifies, for any image digest produced by this pipeline:
#   1. Keyless Cosign signature (Fulcio cert + Rekor transparency log)
#   2. SLSA provenance attestation (proves HOW and WHERE it was built)
#   3. SBOM attestation (signed software bill of materials)
#
# Usage:
#   ./scripts/verify.sh ghcr.io/nourhb/zero-trust-supply-chain/demo-app@sha256:<digest>
#
# Requires: cosign v2.x
# ---------------------------------------------------------------------------
set -euo pipefail

IMAGE="${1:?Usage: $0 <image@sha256:digest>}"
REPO="nourhb/zero-trust-supply-chain"
WORKFLOW="supply-chain.yaml"
IDENTITY="https://github.com/${REPO}/.github/workflows/${WORKFLOW}@refs/heads/main"
ISSUER="https://token.actions.githubusercontent.com"

echo "==> Verifying image: ${IMAGE}"
echo

echo "--- [1/3] Cosign signature (keyless: Fulcio + Rekor) ---"
cosign verify \
  --certificate-identity "${IDENTITY}" \
  --certificate-oidc-issuer "${ISSUER}" \
  "${IMAGE}"
echo "OK: signature valid, issued to ${IDENTITY}, logged in Rekor."
echo

echo "--- [2/3] SLSA provenance attestation ---"
cosign verify-attestation \
  --type slsaprovenance \
  --certificate-identity "${IDENTITY}" \
  --certificate-oidc-issuer "${ISSUER}" \
  "${IMAGE}" | head -c 600
echo
echo "OK: SLSA provenance present and signed by the trusted CI identity."
echo

echo "--- [3/3] SBOM attestation ---"
cosign verify-attestation \
  --type spdxjson \
  --certificate-identity "${IDENTITY}" \
  --certificate-oidc-issuer "${ISSUER}" \
  "${IMAGE}" > /dev/null
echo "OK: signed SBOM bound to this exact digest."
echo

echo "==> All verifications passed. This image is trusted."
