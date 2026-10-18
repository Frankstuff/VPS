# Pajak Enterprises / Pester AI

A public website for Pester AI (styled **Pester.ai**), built by Franciszek Pajak as a sole proprietor under the Pajak Enterprises name.

This is a **frontend preview**, not an operating SMS program. There is no sign-in, account storage, real enrollment, phone verification, focus monitoring, or Bird integration. The signup page uses a fictional number and keeps its example choices only in the page. It never sends or saves a consent record. Do not describe this preview as a working enrollment flow when registering with Bird.

The proposed flow sends SMS to a consenting accountability partner. The person focusing can choose an advance notification or no advance notification; they do not subscribe to SMS in that role. Notification delivery and permission requests are not implemented. Both participants would accept the agreement, with SMS consent recorded separately for the recipient.

The basic backend uses **managed Convex Cloud**. It provides a public program-status query and a `/health` HTTP endpoint. The product page can read that status when a deployment URL is configured. It does not yet store consent or personal information. See [docs/convex.md](docs/convex.md) for account setup, commands, and the distinction between frontend and backend deployment.

## Start here

From a terminal in this repository:

```sh
npm ci
npm run dev
```

Open the URL Vite prints, normally `http://127.0.0.1:5173`. Edit `index.html`, save, and the browser updates. Stop the server with `Ctrl+C`. For this Conductor workspace's assigned port, use `npm run dev -- --port 55020 --strictPort` and open `http://localhost:55020`.

Review all six pages before publishing: `/`, `/pester-ai/`, `/sms/`, `/sms-terms/`, `/privacy/`, and `/contact/`. On `/sms/`, try both roles, change the schedule, and submit the example with the unchecked-by-default permissions selected. The resulting summary is temporary and does not enroll anyone.

**Local review does not publish anything.** After approval, commit the source files and merge a pull request into `main`. The deployment workflow builds and tests pull requests, then builds and uploads `dist/` when the change reaches `main`. Pushing this feature branch alone does not deploy it. The VPS's Nginx root still needs to match `/var/www/pester-ai/current` before the first deployment; see [deployment setup](docs/deployment.md).

Dependencies are already installed in this workspace, so you can skip `npm ci` here. Run it when starting from a fresh clone or restoring dependencies from the lockfile.

## What we installed, and where

The website and deployment source were copied from the `basseterre` worktree into this workspace without changing that worktree. Continue editing and reviewing here:

```text
/Users/franciszekpajak/conductor/workspaces/vps/regina
```

The original frontend was created with Node.js and npm using:

```sh
npm install --save-dev --save-exact typescript vite @types/node@22
```

- **Node.js** runs tools on your computer. It is installed on the machine, outside this repo.
- **npm** downloads packages and runs the commands listed in `package.json`.
- **TypeScript (`typescript`)** supplies the type checker, invoked as `tsc`.
- **Vite (`vite`)** supplies the development server and production bundler.
- **`@types/node`** describes Node's APIs to TypeScript, for the build configuration.
- **`--save-dev`** records these as development/build dependencies.
- **`--save-exact`** records the installed versions without a loose version range. `package-lock.json` also records the full dependency tree.

Everything downloaded for this project goes in `node_modules/`. Nothing was installed globally. You do not download the TypeScript compiler's source yourself or edit the files in `node_modules/`.

For the managed backend, we also ran `npm install --save-exact convex@1.46.0`. This package supplies both the Convex client used by the frontend and the CLI that synchronizes backend code to Convex Cloud.

The checked-in `.nvmrc` suggests Node 24, matching GitHub Actions. This project also supports Node 22.12+ on the 22.x line; nvm is optional.

## Three places, one flow

```text
1. REPOSITORY ON YOUR COMPUTER
   HTML + CSS + TypeScript + configuration + dependency lists
                         │
                         │ tools installed in node_modules/
                         │ npm run build
                         ▼
2. GENERATED OUTPUT ON YOUR COMPUTER
   dist/ = finished HTML, CSS, JavaScript, and assets
                         │
                         │ upload the CONTENTS of dist/
                         ▼
3. VPS WEB DIRECTORY
   Nginx sends these files to the visitor's browser
```

The tools and output are physically inside your local project folder. The key distinction is **what Git tracks**: downloaded dependencies and generated artifacts are ignored. You can build locally; the GitHub Actions workflow also builds on a temporary GitHub-hosted Ubuntu machine, then uploads the artifacts over SSH when changes reach `main`.

The browser executes the generated JavaScript. Nginx does not compile TypeScript. This static frontend does not require Node.js, npm, or Vite on the VPS when you build it on your computer.

## What code belongs in the repo

```text
index.html                 Homepage: first place to change the headline
pester-ai/index.html       Product description, message examples, FAQs
sms/index.html             Signup preview and consent disclosures
sms-terms/index.html       Proposed SMS program terms
privacy/index.html         Current preview privacy policy and planned service
contact/index.html         Operator name, sole proprietor identity, support email
src/
  main.ts                  Shared behavior: mobile navigation
  program.ts               Reads public status on the product page
  sms.ts                   Interactive signup preview, no backend requests
  styles.css               Layout, responsive rules, and component styles
  tokens.css               Shared colors and fonts
public/
  favicon.svg              Static asset copied into the build output
convex/
  program.ts               Public read-only program-status query
  http.ts                  GET /health HTTP endpoint
  schema.ts                Empty database schema; no personal records yet
  _generated/              Convex-generated API/types; keep these in Git
  tsconfig.json            Backend type-checking rules
.env.example               Names of environment settings, without real credentials
vite.config.ts             Tells Vite to build all six HTML entry points
tsconfig.json              TypeScript type-checking rules
package.json               Dependency list and npm scripts
package-lock.json          Exact installed dependency tree
.gitignore                 Files that stay out of Git
.nvmrc                     Suggested Node version
deploy/nginx.conf.example  Example production web-server configuration
deploy/deploy.sh           Uploads a build over SSH from the GitHub runner
deploy/activate-release.sh Switches the live release and rolls back failed checks
deploy/tests/activation.sh Linux integration tests for deployment and rollback
.github/workflows/deploy.yml  Builds pull requests; deploys main to the VPS
docs/                      Build/deployment and future backend notes
```

We used plain HTML, CSS, and TypeScript for these six content pages. A UI framework is not required for the menu and preview. Vite can also build a React frontend later.

**HTML** describes the content and form structure. **CSS** controls appearance. **TypeScript** adds behavior. `sms/index.html` still contains its disclosures without JavaScript; the interactive controls stay disabled until the TypeScript module loads. The static HTML also makes each page straightforward to read during review.

Headers and footers are intentionally present in each HTML file, so they work without JavaScript. If you change a shared link or the operator details, update it across all six files. A future component/template system can reduce that repetition.

## What stays out of Git

| File or directory | Why it is ignored |
| --- | --- |
| `node_modules/` | Downloaded packages; recreated by `npm ci` |
| `dist/` | Generated artifacts; recreated by `npm run build` |
| `.env`, `.env.*` | Machine-specific settings and potential secrets; `.env.example` is allowed |
| `.context/`, `.playwright-mcp/`, `.convex/` | Local agent notes, browser-test output, and local Convex caches |
| `.DS_Store`, logs, TypeScript build cache | Machine-generated files |

Commit the HTML, CSS, TypeScript, assets, configuration, documentation, **both package files**, and `.gitignore`. Git does not ignore a file merely because it is in your project folder; `.gitignore` supplies those rules.

Do not commit credentials. The Convex CLI's machine login stays outside the repo, and project deployment settings go in ignored `.env.local`. Bird keys and Better Auth secrets will belong in backend settings when those features are added. A value placed in browser code or exposed through a `VITE_*` variable is public; the browser receives only the public Convex URL here.

## Build the actual artifacts

From the repository root, run:

```sh
npm run build
```

The script does two things:

1. `tsc --noEmit` checks frontend TypeScript, then `tsc --noEmit -p convex/tsconfig.json` checks the backend. Here the checker intentionally does **not** produce JavaScript.
2. `vite build` transforms TypeScript, bundles code, processes CSS, and writes `dist/`.

The output looks like this (hashes change when the content changes):

```text
dist/
├── index.html
├── favicon.svg
├── assets/
│   ├── ...-HASH.js
│   └── ...-HASH.css
├── pester-ai/index.html
├── sms/index.html
├── sms-terms/index.html
├── privacy/index.html
└── contact/index.html
```

Each route has a real file. `/sms/` maps to `sms/index.html`. This is a multi-page website, not a single HTML file pretending to be every URL. The intended route is `/pester-ai/`.

## How npm finds Vite, and which command starts a server

`npm run build` means "read the `build` command from `package.json` and execute it." npm does not infer a build tool from the presence of TypeScript files. This project's scripts are:

```json
"scripts": {
  "dev": "vite --host 127.0.0.1",
  "typecheck": "tsc --noEmit && tsc --noEmit -p convex/tsconfig.json",
  "build": "npm run typecheck && vite build",
  "preview": "vite preview --host 127.0.0.1",
  "backend:setup": "convex dev --configure --dev-deployment cloud --once",
  "backend:dev": "convex dev",
  "backend:push": "convex dev --once",
  "backend:check": "convex run program:getPublicStatus"
}
```

The `&&` means run `vite build` only if the type check succeeds. Script names are project-defined: another repository's `build` command can do different work.

While running a script, npm adds the project's `node_modules/.bin/` to `PATH`, the list of places the shell searches for commands. In this Mac checkout, npm created these links when installing the packages:

```text
node_modules/.bin/vite → ../vite/bin/vite.js
node_modules/.bin/tsc  → ../typescript/bin/tsc
```

So the `vite` command finds the installed Vite program, which runs using Node.js. `vite build` reads `vite.config.ts`, follows the six HTML pages' script and stylesheet references, processes the referenced files, and writes `dist/`. The TypeScript types are removed from browser JavaScript. The downloaded build tools themselves are not copied into the website.

| Command | What it does | Does a server keep running? |
| --- | --- | --- |
| `npm run typecheck` | Checks the TypeScript; creates no website files | No |
| `npm run build` | Checks types, writes `dist/`, and exits | No |
| `npm run dev` | Starts Vite's development server, transforms source as needed, and updates the browser when you edit | Yes, usually at `http://127.0.0.1:5173/` |
| `npm run preview` | Starts a local server for an already-built `dist/` | Yes, usually at `http://127.0.0.1:4173/` |

`localhost` and `127.0.0.1` refer to your own computer; the port identifies which local service to connect to. The server must be running for the browser to reach it. Stop the dev or preview command with `Ctrl+C` in its terminal. The Vite servers are tools for your computer; Nginx will serve the uploaded artifacts on the VPS.

`npm run backend:dev` is different: it watches your `convex/` files and synchronizes changes to a managed cloud development deployment. Convex keeps running those functions after your local command exits. `npm run build` checks backend types but does not deploy the backend.

To inspect the generated files locally:

```sh
npm run preview
```

Open its printed address, usually `http://127.0.0.1:4173`. This serves `dist/` for checking; it is **not** the production server. Rebuild after source edits to change the preview. Opening `dist/index.html` directly using `file://` is not equivalent to serving the website over HTTP.

## What "Nginx serves a route directly" means

When a visitor types `https://pajakenterprises.com/privacy/` into the address bar, the browser asks Nginx for `/privacy/`. With the example configuration, Nginx reads `privacy/index.html` from the web directory and returns it. The visitor can open or refresh that URL without first visiting the homepage, and no application server needs to generate the page.

There are two common alternatives:

- **Browser routing:** Nginx returns the same main HTML file for several paths. JavaScript in the browser reads the path and renders the corresponding screen. This is common for single-page apps and needs an appropriate server fallback to handle direct visits.
- **Reverse proxying:** Nginx forwards a request to a running backend, and relays its response. A request that saves SMS consent would need that backend behavior; simply serving an HTML file cannot write a trusted consent record to your database.

A site can combine these approaches. For example, Nginx can serve the six public pages as files while the browser separately calls a Convex backend for account and consent operations.

## What to copy to the VPS

Copy the **contents** of `dist/`, not the whole repo, into Nginx's configured web root. For example:

```text
/var/www/pester-ai/current/
├── index.html
├── assets/
├── favicon.svg
├── sms/index.html
└── ...the other page folders
```

Do not copy `src/`, `node_modules/`, private environment files, or the build configuration into the public directory. You never need to paste your source TypeScript into Nginx.

The workflow in [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) automates building and uploading when changes reach `main`. Pull requests build and test without deploying. It requires one-time SSH credentials, GitHub variables, and the Nginx root configuration in [docs/deployment.md](docs/deployment.md). No VPS changes have been made from this checkout. The existing live site at pajakenterprises.com remains separate until that setup and deployment happen.

## What is next

This preview establishes the product description and proposed consent flow. The basic managed Convex connection is described in [docs/convex.md](docs/convex.md). Real SMS enrollment still needs Better Auth, verified consent storage, and the decisions documented in [docs/backend-next.md](docs/backend-next.md). The plan now uses Convex Cloud for application functions/data and Bird for SMS; self-hosting Convex is postponed.

## Official references

- [TypeScript installation](https://www.typescriptlang.org/download/)
- [npm script execution and local command lookup](https://docs.npmjs.com/cli/v10/commands/npm-run-script/)
- [Nginx static files and reverse proxying](https://nginx.org/en/docs/beginners_guide.html)
- [Vite multi-page builds](https://vite.dev/guide/build#multi-page-app)
- [Vite static deployment](https://vite.dev/guide/static-deploy)
- [Bird SMS consent](https://bird.com/explained/sms/how-do-i-collect-sms-opt-ins)
- [Bird 10DLC registration](https://bird.com/docs/guides/sms/10dlc)
- [Bird opt-outs and keywords](https://bird.com/docs/guides/sms/opt-outs-and-keywords)
