#!/usr/bin/env bash
# Run on the build machine, from the repository root. No sudo required.
set -Eeuo pipefail

: "${VPS_HOST:?Set the VPS_HOST GitHub Actions variable}"
: "${VPS_USER:?Set the VPS_USER GitHub Actions variable}"
: "${VPS_SSH_PRIVATE_KEY:?Set the VPS_SSH_PRIVATE_KEY GitHub Actions secret}"
: "${VPS_SSH_KNOWN_HOSTS:?Set the VPS_SSH_KNOWN_HOSTS GitHub Actions secret}"
: "${RELEASE_ID:?Set a unique RELEASE_ID}"
VPS_PORT=${VPS_PORT:-22}
DEPLOY_ROOT=${DEPLOY_ROOT:-/var/www/pester-ai}
SITE_URL=${SITE_URL:-https://pajakenterprises.com}

fail() { printf 'Deployment stopped: %s\n' "$*" >&2; exit 1; }

# Keep values safe when passed through SSH's remote command shell.
[[ "$VPS_HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || fail 'Use a DNS hostname or IPv4 address for VPS_HOST.'
[[ "$VPS_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || fail 'Invalid VPS_USER.'
[[ "$VPS_PORT" =~ ^[1-9][0-9]{0,4}$ ]] || fail 'Invalid VPS_PORT.'
(( VPS_PORT <= 65535 )) || fail 'Invalid VPS_PORT.'
[[ "$DEPLOY_ROOT" =~ ^/[a-zA-Z0-9_/-]+$ && "$DEPLOY_ROOT" != / && "$DEPLOY_ROOT" != */ ]] || fail 'Use an absolute DEPLOY_ROOT without spaces, dots, or a trailing slash.'
[[ "$RELEASE_ID" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$ ]] || fail 'Invalid RELEASE_ID.'
[[ "$SITE_URL" =~ ^https://[a-zA-Z0-9][a-zA-Z0-9.:-]*/?$ ]] || fail 'SITE_URL must be the public HTTPS origin, without a path.'

for page in index.html pester-ai/index.html sms/index.html sms-terms/index.html privacy/index.html contact/index.html favicon.svg; do
  [[ -s "dist/$page" ]] || fail "Missing build output: dist/$page. Run npm run build first."
done
[[ -d dist/assets && -n "$(find dist/assets -type f -print -quit)" ]] || fail 'Missing built assets.'
[[ -z "$(find dist -type l -print -quit)" ]] || fail 'The build output must not contain symbolic links.'
printf '%s\n' "$RELEASE_ID" > dist/__release.txt

umask 077
credentials=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/vps-deploy.XXXXXX")
trap 'rm -rf -- "$credentials"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
chmod 700 "$credentials"
printf '%s\n' "$VPS_SSH_PRIVATE_KEY" | tr -d '\r' > "$credentials/key"
printf '%s\n' "$VPS_SSH_KNOWN_HOSTS" | tr -d '\r' > "$credentials/known_hosts"
chmod 600 "$credentials/key" "$credentials/known_hosts"
unset VPS_SSH_PRIVATE_KEY VPS_SSH_KNOWN_HOSTS

ssh_options=(
  -F /dev/null -T -i "$credentials/key" -p "$VPS_PORT"
  -o BatchMode=yes -o IdentitiesOnly=yes
  -o IdentityAgent=none -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no
  -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$credentials/known_hosts"
  -o GlobalKnownHostsFile=/dev/null -o ConnectionAttempts=1
  -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=3
)
target="$VPS_USER@$VPS_HOST"
release="$DEPLOY_ROOT/releases/$RELEASE_ID"

# A fresh folder ensures a failed or interrupted upload never touches current.
# The deployment account must already own the parent directory (see the guide).
# shellcheck disable=SC2029 # Expand validated arguments locally for the remote shell.
ssh "${ssh_options[@]}" "$target" \
  "umask 022 && test -d '$DEPLOY_ROOT' && test -w '$DEPLOY_ROOT' && mkdir -p '$DEPLOY_ROOT/releases' && mkdir -m 755 '$release'"

printf -v ssh_transport '%q ' ssh "${ssh_options[@]}"
rsync -rptz --chmod=D755,F644 --delay-updates \
  -e "$ssh_transport" dist/ "$target:$release/"

# All arguments above allow only shell-safe characters. The script is streamed
# over SSH; it is never placed in the public website directory.
# shellcheck disable=SC2029 # Expand validated arguments locally for the remote shell.
ssh "${ssh_options[@]}" "$target" \
  "bash -s -- '$DEPLOY_ROOT' '$RELEASE_ID' '$SITE_URL'" < deploy/activate-release.sh
