# Threat Model

**Project:** zero-trust supply chain · **Author:** Nour El Houda Bouajila (https://github.com/nourhb)

This document maps realistic supply-chain attacks (STRIDE-style) to the
concrete mitigations implemented in this repository. The guiding principle:
**never trust, always verify** — every artifact is authenticated at every
stage, and the cluster re-verifies everything at admission time.

## Threat → Mitigation matrix

| # | Threat | STRIDE | Attack scenario | Mitigation in this project |
|---|--------|--------|-----------------|----------------------------|
| 1 | Image tampering in registry | Tampering | Attacker with registry credentials overwrites `demo-app:v1` with a backdoored image | Cosign **keyless signature** on every build; Kyverno `require-signed-images` rejects anything not signed by the CI identity |
| 2 | Tag mutability / tag confusion | Tampering | Attacker (or accident) repoints `:latest` to different bytes; deploys drift silently | `disallow-mutable-tags` policy **forces digest pinning** (`image@sha256:...`); pipeline never publishes `:latest` |
| 3 | Malicious build via compromised CI | Tampering / Elevation | Attacker with CI access builds a trojaned image *through* the legitimate pipeline, earning a valid signature | **SLSA provenance attestation** records source repo, commit, builder; `require-slsa-provenance` verifies the build came from GitHub-hosted runners and this exact repo |
| 4 | Dependency confusion / vulnerable deps | Tampering | Malicious or CVE-ridden package pulled into the image | **Signed SBOM** (Syft, SPDX) bound to the digest; **Trivy scan** fails the pipeline on CRITICAL; multi-stage build keeps only production deps |
| 5 | Long-lived signing key theft | Spoofing | Attacker steals a private signing key and signs malicious images that pass verification | **Keyless signing**: no private keys exist. Fulcio issues short-lived certs only after verifying GitHub OIDC identity; every signature is logged in **Rekor** |
| 6 | Rogue certificate issuance | Spoofing | Compromised CA issues a signing cert for our identity without our knowledge | **Rekor transparency log**: all signatures are public and auditable; `cosign verify` and Kyverno check Rekor inclusion |
| 7 | Unsigned image deployed by insider | Repudiation / Elevation | Someone `kubectl run`s an unvetted image directly into the cluster | Kyverno `validationFailureAction: Enforce` — the API server **rejects** the Pod before it is created |
| 8 | Base image compromise | Tampering | Upstream `node:alpine` tag is repointed to malicious content | Dockerfile pins base images **by digest**; Dependabot-style updates change the digest explicitly |
| 9 | Container breakout at runtime | Elevation | Exploited app escapes to the host | Defense in depth: **non-root user**, `readOnlyRootFilesystem`, dropped capabilities, `RuntimeDefault` seccomp, resource limits, probes |
| 10 | Debug/ephemeral container backdoor | Elevation | `kubectl debug` injects an ephemeral container with an unvetted image into a running Pod | `disallow-mutable-tags` also covers `ephemeralContainers` — they must be digest-pinned too |

## Trust boundaries

```
Developer laptop ──▶ GitHub (source of truth) ──▶ GHCR (artifacts) ──▶ Cluster (admission)
     │                      │                           │                     │
     │ push                 │ OIDC identity             │ signatures          │ Kyverno
     ▼                      ▼                           ▼                     │ re-verifies
  Code review          Fulcio + Rekor              Cosign verify         everything
```

No single compromise breaks the chain: stealing registry credentials is not
enough (images must be signed), stealing CI access is not enough (provenance
must match), and the cluster trusts neither — it verifies.

## Out of scope (acknowledged)

- **Runtime threats** (zero-days in the kernel, side-channel attacks) — mitigated by hardening, not eliminated.
- **Sigstore infrastructure compromise** — trusted as a public-good root of trust, same as any CA; Rekor's transparency makes silent abuse detectable.
- **GitHub Actions runner compromise** — reduced by requiring `github-hosted` runners in the SLSA check and by OIDC-scoped permissions (`permissions:` block is minimal).
