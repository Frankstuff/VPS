# Deploy the website with GitHub Actions

The workflow is [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml). The files are prepared in this checkout; adding them here does not install anything on the VPS or activate a workflow on GitHub. Complete the one-time setup below and get the source onto `main` before expecting automatic deployments.

For this repository, the existing SSH setup is `root@159.223.121.165:22`, with repository secrets `VPS_SSH_PRIVATE_KEY` and `VPS_SSH_KNOWN_HOSTS` and variables `VPS_HOST` and `VPS_USER`. Keep those existing credentials; the generic new-account/key instructions below are reference material, not steps to repeat. The remaining first-deployment task is to verify or prepare `/var/www/pester-ai/releases` and point the existing HTTPS Nginx server block at `/var/www/pester-ai/current`. Do that when publishing is authorized, preserving the existing Certbot certificate configuration. Local website development does not change the VPS.

## What happens when you push

```text
You push source code to main
    ↓
GitHub starts a temporary Ubuntu machine
    ↓
npm ci → npm run build → deployment tests
    ↓
SSH + rsync upload dist/ into a NEW release folder on the VPS
    ↓
Switch current to that completed folder
    ↓
Check the public pages and assets; restore the old link if checks fail
```

The VPS does not poll GitHub or download a build when it boots. GitHub's runner connects to the VPS and pushes the files when the workflow runs. Nginx keeps serving the installed files even after the runner is gone or your laptop is off. After a VPS reboot, Nginx serves the same installed release from disk, assuming its service starts normally.

| Event | This workflow does |
| --- | --- |
| Push to `main`, including a merged pull request | Build, test, upload, activate, and verify |
| Pull request targeting `main` | Build and test; no deployment credentials used |
| Actions → Build and deploy website → Run workflow, selecting `main` | Build, test, and deploy again |
| Manual run selecting another branch | Build and test only |
| Publish a GitHub Release or push a tag | No separate run from that event |

A **push to main** updates the branch containing your source code. A **GitHub Release** is a separately published version associated with a Git tag, often with notes and downloads. You can add a release-based launch process later; this project deploys changes when they reach `main`. The VPS's *release directories* are simply folders for individual deployments, independent of GitHub Releases. See [GitHub's workflow trigger documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows).

The runner uses Node 24. `npm ci` installs the versions recorded in `package-lock.json`. `npm run build` finds the project's local TypeScript and Vite executables, checks types, and writes `dist/`; it does not start a permanent server. Only the generated HTML, CSS, JavaScript, images, and a small release marker are uploaded. No `node_modules/`, source code, `.env` file, or SSH key goes into Nginx's directory. The VPS does not need Node or npm.

## 1. Prepare the VPS once

These examples assume Ubuntu/Debian, Nginx with a working HTTPS certificate, and a dedicated non-root SSH user called `deploy`. Adapt the username and host to your actual server. The SSH host must be reachable from GitHub's hosted runners.

Using your existing administrator login, install the deployment utilities and create a directory writable by the deployment account:

```sh
sudo apt-get update
sudo apt-get install -y rsync curl util-linux
# Create the account only if you do not already have one:
sudo adduser --disabled-password --gecos "" deploy
sudo install -d -o deploy -g deploy -m 755 /var/www/pester-ai /var/www/pester-ai/releases
sudo install -d -o deploy -g deploy -m 700 /home/deploy/.ssh
```

The deployment account needs SSH access, read access to earlier releases, and write access to this site's directory. It does not need sudo or permission to edit Nginx. Keep other projects in their own directories.

On your computer, create a **new, dedicated** key for this workflow. Choose a different filename if this one already exists:

```sh
ssh-keygen -t ed25519 -N '' -C 'github-actions-pester-ai' -f ~/.ssh/pester_ai_actions
```

This creates a private key at `~/.ssh/pester_ai_actions` and a public key ending in `.pub`. Install the **public** key as a line in `/home/deploy/.ssh/authorized_keys` on the VPS, using your administrator login. Set that file's owner to `deploy:deploy` and permissions to `600`. Keep the private key out of the repository and chat; it will go into GitHub Secrets.

Verify the VPS's host key before giving it to automation. For example, collect its Ed25519 public host key on your computer, replacing `YOUR_VPS_HOST` and using your actual SSH port:

```sh
ssh-keyscan -t ed25519 -p 22 YOUR_VPS_HOST > ~/.ssh/pester_ai_known_hosts
ssh-keygen -lf ~/.ssh/pester_ai_known_hosts
```

Compare that fingerprint with the VPS's own fingerprint, obtained through your provider's console or an already trusted administrator connection:

```sh
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

After they match, the collected `known_hosts` entry identifies the server that GitHub may connect to. Scanning alone does not authenticate the server. The workflow requires this stored key and refuses an unknown or changed server key.

Test the dedicated account from your computer, using the matching host and port:

```sh
ssh -i ~/.ssh/pester_ai_actions -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$HOME/.ssh/pester_ai_known_hosts" \
  deploy@YOUR_VPS_HOST 'test -w /var/www/pester-ai && command -v rsync && command -v curl && command -v flock'
```

## 2. Point Nginx at this website once

Nginx's root should be `/var/www/pester-ai/current`, where `current` is a **symbolic link**, a filesystem shortcut:

```text
/var/www/pester-ai/
├── releases/
│   ├── bootstrap/
│   ├── <commit>-<workflow-run>-<attempt>/
│   └── ...
└── current → releases/<installed-release>/
```

If this is the first deployment, seed a complete initial release before switching Nginx's root. That lets an existing website continue serving while you prepare the replacement. On your computer, from the repository root:

```sh
npm ci
npm run build
ssh -i ~/.ssh/pester_ai_actions deploy@YOUR_VPS_HOST 'mkdir /var/www/pester-ai/releases/bootstrap'
rsync -rptz --chmod=D755,F644 -e 'ssh -i ~/.ssh/pester_ai_actions' \
  dist/ deploy@YOUR_VPS_HOST:/var/www/pester-ai/releases/bootstrap/
ssh -i ~/.ssh/pester_ai_actions deploy@YOUR_VPS_HOST \
  'ln -sT /var/www/pester-ai/releases/bootstrap /var/www/pester-ai/current'
```

These are first-time examples using port 22; add your SSH port if it differs and use your verified host-key settings. `ln -sT` deliberately fails if `current` already exists. Do not overwrite a real directory: move it to a release directory and create the link deliberately. You do not repeat this bootstrap for future updates.

Use [`deploy/nginx.conf.example`](../deploy/nginx.conf.example) as a reference when updating the existing HTTPS server block for the domain. Its certificate paths must match the VPS. Do not create a second server block for the same hostname. The essential lines are:

```nginx
root /var/www/pester-ai/current;
index index.html;
```

On the VPS, check the configuration and reload only if the check succeeds:

```sh
sudo nginx -t && sudo systemctl reload nginx
```

This is the step that replaces the domain's existing public website. Check `/`, `/pester-ai/`, `/sms/`, `/sms-terms/`, `/privacy/`, and `/contact/` over HTTPS, including direct visits and refreshes. A nonexistent page should return 404. For example, `/sms/` reads `/var/www/pester-ai/current/sms/index.html`.

Once configured, Nginx needs no reload on ordinary deployments: the workflow replaces the `current` link. Keep Nginx's `open_file_cache` off for this site (its default), so the switch is visible immediately. If a CDN sits in front of Nginx, allow HTML revalidation and do not cache `/__release.txt`; the example adds a no-store header for that marker. Disable transformations that rewrite HTML or assets if using the workflow's exact-content checks.

## 3. Add settings in GitHub

Open the [repository's Actions secrets and variables settings](https://github.com/Frankstuff/VPS/settings/secrets/actions). These are **repository** secrets and variables, not environment settings.

Add these under **Secrets**:

| Secret | Value |
| --- | --- |
| `VPS_SSH_PRIVATE_KEY` | The entire dedicated private key file, including its BEGIN/END lines |
| `VPS_SSH_KNOWN_HOSTS` | The verified contents of `~/.ssh/pester_ai_known_hosts` |

If you use the GitHub CLI, these commands read the files without printing their contents:

```sh
gh secret set VPS_SSH_PRIVATE_KEY --repo Frankstuff/VPS < ~/.ssh/pester_ai_actions
gh secret set VPS_SSH_KNOWN_HOSTS --repo Frankstuff/VPS < ~/.ssh/pester_ai_known_hosts
```

Add these under **Variables**:

| Variable | Value |
| --- | --- |
| `VPS_HOST` | Required: the server's public DNS hostname or IPv4 address, without `https://` |
| `VPS_USER` | Required: the SSH account, for example `deploy` |
| `VPS_PORT` | Optional; defaults to `22` |
| `VPS_DEPLOY_PATH` | Optional; defaults to `/var/www/pester-ai`. Use an absolute path without spaces, dots, or a trailing slash. |
| `SITE_URL` | Optional; defaults to `https://pajakenterprises.com`. Use the canonical HTTPS origin, without a path. |
| `VITE_CONVEX_URL` | Optional: the public production `https://YOUR-DEPLOYMENT.convex.cloud` URL. Leave unset until Convex is ready. |

The public Convex URL is built into the browser's JavaScript. Changing it requires a new frontend build. Never put a Convex deploy key or Bird credential into a `VITE_*` variable.

The build and tests work without SSH settings. A deployment from `main` fails with a named missing-setting error until the required credentials and variables exist.

## 4. Put the source on main

Commit the source, the workflow, deployment scripts, `package.json`, and `package-lock.json`. The `convex/_generated/` files also belong in Git so the build can check types without logging into Convex. Keep `node_modules/`, `dist/`, and private settings ignored.

Push or merge those changes to `main` after configuring the VPS and repository settings. Watch **Actions → Build and deploy website**. Manual runs become available once the workflow file is on the default branch. There is no need to upload `dist/` to GitHub or commit build artifacts.

## Failed deployments and rollback

The workflow builds and tests before connecting to the VPS. Each run gets its own release folder. Upload errors leave `current` untouched. Before activation, the server script checks all six pages, the assets, and the release marker. It then switches the link atomically and fetches the public pages and assets to compare them with the uploaded files. A failed verification restores the previous link. On a failed first deployment with no previous link, it removes the new link instead. A release can be briefly visible during verification.

An interrupted SSH upload leaves an unused release folder; it does not overwrite the live files. Normal shell termination during activation triggers rollback, but a machine crash or forced kill can bypass shell cleanup. After such an interruption, inspect `current` and the public site before rerunning. GitHub queues deployments rather than canceling one halfway through; the VPS also locks activation to prevent simultaneous switches.

To roll back manually, substitute the exact earlier release name. This checks the public files and restores the starting link if verification fails. From your computer, in the repository:

```sh
ssh -i ~/.ssh/pester_ai_actions deploy@YOUR_VPS_HOST \
  'bash -s -- /var/www/pester-ai EARLIER_RELEASE_ID https://pajakenterprises.com' \
  < deploy/activate-release.sh
```

For a manually seeded `bootstrap` release, create its marker first (`printf 'bootstrap\n' > /var/www/pester-ai/releases/bootstrap/__release.txt` on the VPS), then use `bootstrap` as the release ID.

Old releases are kept for rollback. Old content-hashed assets are also carried into the next release so a visitor with an older page open can still load them. This uses increasing disk space; there is no automatic deletion policy yet. Inspect disk usage periodically and remove only releases you no longer need, never the active directory. A cleanup policy for carried-forward assets can be added as the site grows.

## Convex remains a separate deployment

This workflow uploads the static frontend. Convex Cloud runs application functions and the database separately. Browsers call its public URL directly, without an Nginx reverse proxy. Backend secrets and database files never belong in the public web directory.

The build checks backend TypeScript, but does not upload backend functions. Deploy them with the Convex CLI as described in [convex.md](convex.md), then supply the public production URL through `VITE_CONVEX_URL`. Adding a Convex production deployment step later would require a separate deploy credential. No Convex or Bird credential is needed for this static preview.

## Test the deployment code

On Linux with Bash, Python 3, rsync, curl, GNU coreutils, and `flock`:

```sh
bash deploy/tests/activation.sh
```

The tests create temporary releases and local HTTP servers. They exercise successful updates, retention of old assets, incomplete uploads, incorrect public responses, rollback, failed first deployments, and protection of an existing real `current` directory. They do not connect to the VPS or send SMS.
