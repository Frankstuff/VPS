#!/usr/bin/env bash
# Linux integration tests. All files and the HTTP server are local/temporary.
set -Eeuo pipefail
repository=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
temporary=$(mktemp -d)
server_pid=''
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf -- "$temporary"
}
trap cleanup EXIT
root="$temporary/site"
mkdir -p "$root/releases"

# An ephemeral port avoids conflicts with other services on CI or a developer's
# machine. Requests resolve current each time, as the production server does.
python3 - "$root/current" "$temporary/port" >"$temporary/http.log" 2>&1 <<'PY' &
import functools
import http.server
import pathlib
import sys

handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=sys.argv[1])
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
pathlib.Path(sys.argv[2]).write_text(str(server.server_port))
server.serve_forever()
PY
server_pid=$!
for (( attempt = 0; attempt < 50; attempt++ )); do
  [[ -s "$temporary/port" ]] && break
  sleep 0.1
done
[[ -s "$temporary/port" ]] || { cat "$temporary/http.log" >&2; exit 1; }
site_url="http://127.0.0.1:$(cat "$temporary/port")"

fixture() {
  local id=$1 page
  mkdir -p "$root/releases/$id/assets"
  for page in index.html pester-ai/index.html sms/index.html sms-terms/index.html privacy/index.html contact/index.html; do
    mkdir -p "$root/releases/$id/$(dirname "$page")"
    printf '<!doctype html><title>%s %s</title>\n' "$id" "$page" > "$root/releases/$id/$page"
  done
  printf '%s\n' "$id" > "$root/releases/$id/__release.txt"
  printf '<svg xmlns="http://www.w3.org/2000/svg"/>\n' > "$root/releases/$id/favicon.svg"
  printf '/* %s */\n' "$id" > "$root/releases/$id/assets/$id.css"
}

activate() { bash "$repository/deploy/activate-release.sh" "$root" "$1" "$site_url"; }
expect_current() {
  [[ -L "$root/current" && "$(readlink "$root/current")" == "$root/releases/$1" ]] || {
    printf 'Expected current to remain on %s\n' "$1" >&2; exit 1;
  }
}
expect_failure() {
  if "$@" >"$temporary/failure.log" 2>&1; then
    printf 'Expected failure: %s\n' "$*" >&2; exit 1
  fi
}

fixture first
activate first
expect_current first

fixture second
activate second
expect_current second
cmp "$root/releases/first/assets/first.css" "$root/current/assets/first.css"
printf 'PASS: first deploy, atomic update, and retained old assets\n'

fixture incomplete
rm "$root/releases/incomplete/privacy/index.html"
expect_failure activate incomplete
expect_current second
printf 'PASS: incomplete release leaves the live release untouched\n'

fixture mismatch
# Simulate a domain whose Nginx root points at a different website.
expect_failure bash "$repository/deploy/activate-release.sh" "$root" mismatch "$site_url/wrong-root"
expect_current second
# The helper rejects origins with paths before activation. To exercise rollback
# after activation, return an incorrect marker from an otherwise working server.
python3 - "$temporary/wrong-port" >"$temporary/wrong-http.log" 2>&1 <<'PY' &
import http.server
import pathlib
import sys

class WrongSite(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"an unrelated website\n")

server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), WrongSite)
pathlib.Path(sys.argv[1]).write_text(str(server.server_port))
server.serve_forever()
PY
wrong_pid=$!
# Both servers must be cleaned up even if an assertion fails.
trap 'kill "$wrong_pid" 2>/dev/null || true; wait "$wrong_pid" 2>/dev/null || true; cleanup' EXIT
for (( attempt = 0; attempt < 50; attempt++ )); do
  [[ -s "$temporary/wrong-port" ]] && break
  sleep 0.1
done
wrong_url="http://127.0.0.1:$(cat "$temporary/wrong-port")"
expect_failure bash "$repository/deploy/activate-release.sh" "$root" mismatch "$wrong_url"
expect_current second
[[ "$(cat "$temporary/failure.log")" == *'Restored previous release:'* ]]
printf 'PASS: public verification failure restores the previous release\n'

rm "$root/current"
expect_failure bash "$repository/deploy/activate-release.sh" "$root" mismatch "$wrong_url"
[[ ! -e "$root/current" && ! -L "$root/current" ]]
printf 'PASS: failed first deployment removes its current link\n'

mkdir "$root/current"
printf 'keep me\n' > "$root/current/existing.txt"
expect_failure activate mismatch
[[ -f "$root/current/existing.txt" && ! -L "$root/current" ]]
printf 'PASS: existing real directory is preserved\n'

expect_failure bash "$repository/deploy/activate-release.sh" "$root" ../escape "$site_url"
printf 'PASS: invalid release ID is rejected\n'
