#!/usr/bin/env bash
# Runs on the Linux VPS. Requires Bash, GNU coreutils, rsync, curl, and flock.
set -Eeuo pipefail

fail() { printf 'Release activation failed: %s\n' "$*" >&2; exit 1; }
[[ $# == 3 ]] || fail 'Expected DEPLOY_ROOT RELEASE_ID SITE_URL.'
root=$1
release_id=$2
site_url=${3%/}
[[ "$root" == /* && "$root" != / && -d "$root" ]] || fail 'Invalid deployment root.'
[[ "$release_id" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$ ]] || fail 'Invalid release ID.'
[[ "$site_url" =~ ^https?://[a-zA-Z0-9][a-zA-Z0-9.:-]*$ ]] || fail 'Invalid site origin.'
root=$(cd "$root" && pwd -P)
release="$root/releases/$release_id"
current="$root/current"

# Also serialize manual deployments made outside GitHub Actions.
exec 9>"$root/.deploy.lock"
flock -x -w 60 9 || fail 'Another deployment is still activating.'

[[ -d "$release" && ! -L "$release" && ! -L "$root/releases" ]] || fail 'Expected a real release directory.'
[[ -z "$(find "$release" -type l -print -quit)" ]] || fail 'Release contains symbolic links.'
[[ -f "$release/__release.txt" && "$(cat "$release/__release.txt")" == "$release_id" ]] || fail 'Release marker does not match.'
pages=(index.html pester-ai/index.html sms/index.html sms-terms/index.html privacy/index.html contact/index.html)
for page in "${pages[@]}" favicon.svg; do
  [[ -s "$release/$page" ]] || fail "Missing file: $page"
done
[[ -d "$release/assets" ]] || fail 'Missing assets directory.'
mapfile -d '' -t assets < <(find "$release/assets" -type f -print0)
[[ ${#assets[@]} -gt 0 ]] || fail 'No built assets found.'

previous=''
if [[ -L "$current" ]]; then
  previous=$(readlink -f "$current") || fail 'Cannot resolve the existing current link.'
  [[ -d "$previous" && "$previous" == "$root/releases/"* && "$previous" != "$release" ]] || fail 'Current must point to a different, existing release under releases/.'
elif [[ -e "$current" ]]; then
  fail 'current is a real file or directory; migrate it to a release before deploying.'
fi

# Old open tabs may still request the previous build's content-hashed assets.
# Retain them without overwriting any files from the new build.
if [[ -n "$previous" && -d "$previous/assets" ]]; then
  rsync -rpt --ignore-existing --chmod=D755,F644 "$previous/assets/" "$release/assets/"
fi

temporary=$(mktemp -d "$root/.activate.XXXXXX")
activated=false
cleanup() {
  result=$?
  trap - EXIT
  if (( result != 0 )) && [[ "$activated" == true && -L "$current" && "$(readlink "$current")" == "$release" ]]; then
    if [[ -n "$previous" ]]; then
      ln -s "$previous" "$temporary/rollback"
      mv -Tf "$temporary/rollback" "$current"
      printf 'Restored previous release: %s\n' "$previous" >&2
    else
      rm -- "$current"
      printf 'Removed failed first-release link; no previous release existed.\n' >&2
    fi
  fi
  rm -rf -- "$temporary"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

ln -s "$release" "$temporary/current"
# GNU mv -T replaces the link itself in one filesystem operation.
# Set the flag first so a signal immediately after mv still triggers rollback.
activated=true
mv -Tf "$temporary/current" "$current"

verify_file() {
  local path=$1 expected=$2
  curl --fail --silent --show-error --location --retry 2 --retry-delay 1 \
    --connect-timeout 5 --max-time 15 \
    "$site_url/$path?deployment=$release_id" -o "$temporary/response" || fail "Cannot fetch /$path."
  cmp -s "$expected" "$temporary/response" || fail "Public /$path does not match the uploaded release. Check Nginx's root and any CDN caching."
}

# The marker proves the domain is serving THIS release, not an older website.
verify_file __release.txt "$release/__release.txt"
for page in "${pages[@]}"; do
  path=${page%index.html}
  verify_file "$path" "$release/$page"
done
verify_file favicon.svg "$release/favicon.svg"
for asset in "${assets[@]}"; do
  verify_file "${asset#"$release/"}" "$asset"
done

printf 'Deployed release %s to %s\n' "$release_id" "$site_url"
