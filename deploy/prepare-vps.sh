#!/usr/bin/env bash
# One-time migration of this VPS's existing Certbot-managed site.
# Run remotely as root; ordinary deployments do not edit Nginx.
set -Eeuo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
umask 022

[[ $(id -u) == 0 ]] || { echo 'Preparation requires root.' >&2; exit 1; }
for utility in nginx systemctl rsync curl flock python3; do
  command -v "$utility" >/dev/null
done

config=/etc/nginx/sites-available/default
deploy_root=/var/www/pester-ai
[[ $(readlink -f /etc/nginx/sites-enabled/default) == "$config" ]]
nginx -t
systemctl is-active --quiet nginx
install -d -m 755 "$deploy_root" "$deploy_root/releases"
exec 9>"$deploy_root/.deploy.lock"
flock -w 30 9

if [[ -e "$deploy_root/current" || -L "$deploy_root/current" ]]; then
  [[ -L "$deploy_root/current" ]]
  [[ $(readlink -f "$deploy_root/current") == "$deploy_root/releases/"* ]]
  python3 - "$config" <<'PY'
import pathlib, re, sys
config = pathlib.Path(sys.argv[1]).read_text()
assert re.findall(r"(?m)^\s*root\s+([^;]+);", config) == ["/var/www/pester-ai/current"], "Unexpected existing Nginx root"
PY
  curl --fail --silent --show-error --max-time 15 --noproxy '*' \
    --resolve pajakenterprises.com:443:127.0.0.1 https://pajakenterprises.com/ >/dev/null
  echo 'The deployment directory is already configured; current release preserved.'
  exit 0
fi

test -s /var/www/html/index.html
install -d -m 700 /var/backups/pester-ai
backup=$(mktemp -d /var/backups/pester-ai/nginx.XXXXXX)
cp -a "$config" "$backup/default.conf"
changed=0
finish() {
  result=$?
  trap - EXIT
  if (( result != 0 && changed == 1 )); then
    echo 'Preparation failed; restoring the original Nginx configuration.' >&2
    cp -a "$backup/default.conf" "$config"
    nginx -t && systemctl reload nginx
    # Keep the copied files for inspection, but allow a safe retry.
    if [[ -L "$deploy_root/current" && $(readlink "$deploy_root/current") == "$seed" ]]; then
      rm -- "$deploy_root/current"
    fi
  fi
  exit "$result"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

python3 - "$config" "$backup/prepared.conf" <<'PY'
import pathlib, re, sys
source = pathlib.Path(sys.argv[1]).read_text()
assert re.search(r"(?m)^\s*server_name\s+pajakenterprises\.com\s+www\.pajakenterprises\.com\s*;", source), "Unexpected server names"
assert "/etc/letsencrypt/live/pajakenterprises.com/fullchain.pem" in source, "Expected existing certificate configuration"
assert len(re.findall(r"(?m)^\s*server\s*\{", source)) == 1, "Expected one existing server block"
assert re.findall(r"(?m)^\s*root\s+([^;]+);", source) == ["/var/www/html"], "Unexpected existing root"
assert not re.search(r"(?m)^\s*open_file_cache\b", source), "Review existing file cache settings first"
replacement = """    root /var/www/pester-ai/current;
    open_file_cache off;

    # HTTPS uses the existing Certbot certificate and renewal configuration.
    if ($scheme = http) {
        return 301 https://pajakenterprises.com$request_uri;
    }

    location = /__release.txt {
        add_header Cache-Control "no-store" always;
        try_files $uri =404;
    }"""
updated, count = re.subn(r"(?m)^[ \t]*root[ \t]+/var/www/html[ \t]*;", lambda _: replacement, source)
assert count == 1
pathlib.Path(sys.argv[2]).write_text(updated)
PY

seed="$deploy_root/releases/bootstrap-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -m 755 "$seed"
rsync -rpt --chmod=D755,F644 /var/www/html/ "$seed/"
cmp /var/www/html/index.html "$seed/index.html"
ln -sT "$seed" "$deploy_root/current"
changed=1
install -m 644 "$backup/prepared.conf" "$config"
nginx -t
systemctl reload nginx

for domain in pajakenterprises.com www.pajakenterprises.com; do
  curl --fail --silent --show-error --max-time 15 --noproxy '*' \
    --resolve "$domain:443:127.0.0.1" "https://$domain/" >"$backup/response.html"
  cmp "$seed/index.html" "$backup/response.html"
  redirect=$(curl --silent --show-error --max-time 15 --noproxy '*' \
    --resolve "$domain:80:127.0.0.1" --output /dev/null \
    --write-out '%{http_code} %{redirect_url}' "http://$domain/")
  [[ "$redirect" == '301 https://pajakenterprises.com/' ]]
done
echo "Prepared $deploy_root/current; the previous website is still serving."
echo "Original Nginx configuration backed up at $backup/default.conf"
