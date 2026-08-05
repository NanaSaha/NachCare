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
};
