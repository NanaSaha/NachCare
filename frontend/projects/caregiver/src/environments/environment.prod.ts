// Production environment — used only when Angular builds with
// `--configuration production` via the `fileReplacements` wired in
// angular.json (see docs/adr/0015-render-demo-deployment.md). The dev
// `environment.ts` (localhost:3001) is untouched and stays the default
// for `ng serve`.
//
// apiOrigin points at the Rails API's Render URL. Render's default
// subdomain pattern is `https://<service-name>.onrender.com` — this
// must match the backend web service's `name` in the repo-root
// render.yaml exactly (currently `nachcare-backend`).
export const environment = {
  apiOrigin: 'https://nachcare-backend.onrender.com',
  // Production VAPID public key (freshly generated for this deployment,
  // NOT the dev-only keypair in ops/docker-compose.yml — see ADR-0015).
  // Public key only, safe to ship in the client bundle; the matching
  // private key lives only in the backend web/worker services' env vars
  // on Render, entered manually (marked `sync: false` in render.yaml).
  vapidPublicKey: 'BAOBpVebURrXotJG-C0ARFfc2BJw4xX5O6qyklhChPqGb3SbYD4tPxvrK68pcEL3oVf0_nwIkonhsQpE33ZzLAA',
};
