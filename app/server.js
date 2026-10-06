// Zero-Trust Supply Chain — demo microservice
// Author: Nour El Houda Bouajila (https://github.com/nourhb)
//
// A minimal Express service used to demonstrate the secure supply chain:
// the image built from this source is signed (Cosign, keyless), attested
// (SLSA provenance + SBOM), and only admitted to the cluster by Kyverno
// after its signature is verified.

'use strict';

const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;

// Liveness probe target — answers even if the app is degraded.
app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok', service: 'zero-trust-demo-app' });
});

// Readiness probe target — only 200 when the service can serve traffic.
app.get('/ready', (_req, res) => {
  res.status(200).json({ status: 'ready' });
});

app.get('/', (_req, res) => {
  res.json({
    message: 'Hello from the zero-trust supply chain demo!',
    signed: true,
    provenance: 'SLSA',
  });
});

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`zero-trust-demo-app listening on port ${PORT}`);
});
