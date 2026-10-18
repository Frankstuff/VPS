# Managed Convex: the first backend connection

Convex Cloud runs the backend and database. Your VPS still serves the frontend files with Nginx. No Convex server, Docker container, or database needs to run on the VPS for this setup.

## What is implemented

- `convex/program.ts`: the public `program:getPublicStatus` query returns the product name, preview stage, closed SMS enrollment, and channel choices. This is public metadata, not a consent record.
- `convex/http.ts`: `GET /health` returns JSON confirming that the HTTP handler is reachable. It does not test authentication, Bird, or a database write.
- `convex/schema.ts`: an empty schema, ready for private application tables later. There are no personal records or public write functions yet.
- `src/program.ts`: the product page reads public program status using Convex's HTTP client. If there is no configured URL, a timeout, or an error, the static preview notice remains visible.

The signup preview still sends and stores nothing. Better Auth, phone verification, durable consent records, notifications, and Bird sending are future work.

Having these files in the repo does not create a cloud deployment. Complete the account/project setup below before expecting a live endpoint or a successful `backend:check`.

## Connect a Convex account and cloud project

The Convex package is installed locally with `npm install --save-exact convex@1.46.0`. Its CLI is available through npm scripts and `npx convex`.

For the first setup, from the repository root:

```sh
npm run backend:setup
```

Follow the browser login if prompted, select your personal team and a new **Pester AI** project (or the existing Pester AI project), and use a **cloud development deployment**. The script explicitly requests cloud hosting; it does not start a local Convex database. It synchronizes the functions once and exits.

The CLI writes configuration into `.env.local`, normally including:

```text
CONVEX_DEPLOYMENT=dev:your-deployment-name
VITE_CONVEX_URL=https://your-deployment-name.convex.cloud
VITE_CONVEX_SITE_URL=https://your-deployment-name.convex.site
```

Those are illustrative values, not working endpoints. The CLI supplies your real names. Keep `.env.local` out of Git. `.env.example` documents the names without configuring a fake connection.

Restart the Vite dev server after changing the environment configuration, then visit `/pester-ai/`. The enrollment notice near the bottom reads public status from Convex; there is deliberately no technical connection dashboard in the product's signup flow.

## Two addresses, one managed deployment

| Address | Purpose |
| --- | --- |
| `https://YOUR-DEPLOYMENT.convex.cloud` | Convex client calls, such as `program:getPublicStatus` |
| `https://YOUR-DEPLOYMENT.convex.site/health` | The custom HTTP route defined in `convex/http.ts` |

The client query is not a normal browser page at `/program/getPublicStatus`. Convex's client library sends the function call using Convex's API protocol. The `.convex.site` route is a conventional HTTP endpoint that you can open in a browser or with curl.

These deployment URLs are public addresses. They are not administrator keys. Access to future private records must be checked inside backend functions even though the address is public.

## Commands you will use

```sh
# Terminal 1: synchronize backend edits to the configured cloud dev deployment
npm run backend:dev

# Terminal 2: serve and update the frontend on your computer
npm run dev
```

`backend:dev` watches files and uploads backend changes. The backend itself runs on Convex's servers and stays available after you close the terminal or your laptop.

```sh
# Upload the current backend once, then exit
npm run backend:push

# Call the deployed public query from the CLI
npm run backend:check

# Check both frontend and backend types, then build frontend artifacts
npm run build
```

Expected public query result:

```json
{
  "name": "Pester AI",
  "stage": "preview",
  "smsEnrollmentOpen": false,
  "smsRecipient": "accountability_partner",
  "advanceWarning": "optional_notification"
}
```

With the actual `.convex.site` hostname substituted:

```sh
curl --fail https://YOUR-DEPLOYMENT.convex.site/health
```

The expected health response is `{"ok":true,"service":"pester-ai","stage":"preview"}`. Neither command sends an SMS.

## What belongs where

- Commit `convex/` source, its `_generated/` client/server types, `src/program.ts`, the package files, and `.env.example`. Convex generates `_generated/` during backend synchronization; it is deliberately committed so the frontend can build without cloud credentials.
- Ignore `.env.local`, `node_modules/`, `dist/`, and `.convex/` local caches.
- Upload only `dist/` contents to the VPS's public web directory.
- Upload backend functions with the Convex CLI; copying `convex/` onto the VPS does not deploy them to Convex Cloud.

Only `VITE_CONVEX_URL`, a public address, is needed by this frontend. Never expose a Convex deploy key, account access token, Better Auth secret, or Bird key through a `VITE_*` variable.

## Development versus production

Use the development deployment while building the application. Before a real launch, deploy the backend to the project's separate production deployment and build the frontend with that production URL. Convex provides a combined backend-deploy/frontend-build command:

```sh
npx convex deploy --cmd 'npm run build'
```

That deploys the backend and supplies the production Convex URL to the frontend build. Uploading the resulting `dist/` to Nginx is still a separate step. The workflow in [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) currently builds and deploys the **frontend only**. Set the repository Actions variable `VITE_CONVEX_URL` to the production deployment's public URL after deploying the backend. Extending the workflow to deploy Convex functions too would require a production deploy key stored as a GitHub secret; that step is not configured yet. See [deployment.md](deployment.md) for the VPS workflow setup.

Moving data between development and production is not automatic. The next backend milestone is Better Auth plus authenticated, versioned agreement acceptance, verified SMS consent, and withdrawal handling.

## Official references

- [Convex CLI setup](https://docs.convex.dev/cli/overview)
- [JavaScript and HTTP clients](https://docs.convex.dev/client/javascript/overview)
- [HTTP actions](https://docs.convex.dev/functions/http-actions)
- [Building a separately hosted frontend](https://docs.convex.dev/production/hosting/custom)
