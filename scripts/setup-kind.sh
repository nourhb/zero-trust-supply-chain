#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Zero-Trust Supply Chain — local Kind demo
# Author: Nour El Houda Bouajila (https://github.com/nourhb)
#
# Spins up a local Kind cluster, installs Kyverno, applies the admission
# policies, then demonstrates:
#   BLOCKED: an unsigned image (e.g. nginx:latest) is REJECTED at admission
#   (also rejected for using the mutable :latest tag)
#   ALLOWED: only a properly signed + attested image pinned by digest would
#   be admitted (requires a real pipeline digest — see notes below)
#
# Usage:
#   ./scripts/setup-kind.sh [signed-image@sha256:digest]
#
# Requires: docker, kind, kubectl, helm
# ---------------------------------------------------------------------------
set -euo pipefail

KYVERNO_VERSION="v3.3.6"
CLUSTER_NAME="zero-trust-demo"
SIGNED_IMAGE="${1:-}"

echo "==> [1/5] Creating Kind cluster '${CLUSTER_NAME}'..."
kind create cluster --name "${CLUSTER_NAME}" --wait 120s

echo "==> [2/5] Installing Kyverno ${KYVERNO_VERSION}..."
helm repo add kyverno https://kyverno.github.io/kyverno/ > /dev/null
helm repo update > /dev/null
helm upgrade --install kyverno kyverno/kyverno \
  --version "${KYVERNO_VERSION}" \
  --namespace kyverno --create-namespace \
  --set admissionController.replicas=1 \
  --set backgroundController.replicas=1 \
  --set cleanupController.replicas=1 \
  --wait

echo "==> [3/5] Applying zero-trust admission policies..."
kubectl apply -f kyverno/

echo "==> [4/5] DEMO: unsigned image is BLOCKED..."
set +e
# Try to create a Pod with an unsigned, mutable-tag image — admission must reject it.
cat <<'EOF' | kubectl apply --dry-run=server -f - > /tmp/blocked.log 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: unsigned-demo
  namespace: default
spec:
  containers:
    - name: app
      image: nginx:latest
EOF
if [ $? -ne 0 ]; then
  echo "BLOCKED as expected:"
  grep -o "mutabled[^\"']*\|pinned by digest[^\"']*\|signature[^\"']*" /tmp/blocked.log | head -3
else
  echo "WARNING: unsigned pod was NOT blocked — check policy installation."
fi
set -e

echo
echo "==> [5/5] DEMO: signed image pinned by digest..."
if [ -z "${SIGNED_IMAGE}" ]; then
  cat <<'EOF'
  Skipped (no signed image provided).

  To see the ALLOW path end-to-end:
    1. Push this repo to GitHub and let .github/workflows/supply-chain.yaml run.
    2. Copy the digest from the "Report image digest" step summary.
    3. Re-run: ./scripts/setup-kind.sh ghcr.io/nourhb/zero-trust-supply-chain/demo-app@sha256:<digest>

  Note: admission of a real signed image also requires the cluster to reach
  Rekor (https://rekor.sigstore.dev) for signature verification.
EOF
else
  kubectl create namespace supply-chain-demo --dry-run=client -o yaml | kubectl apply -f -
  sed "s|sha256:DIGEST_PLACEHOLDER|${SIGNED_IMAGE##*@sha256:}|" kubernetes/deployment.yaml \
    | kubectl apply --dry-run=server -f - && echo "ALLOWED: signed, attested, digest-pinned image admitted."
fi

echo
echo "==> Demo complete. Tear down with: kind delete cluster --name ${CLUSTER_NAME}"
