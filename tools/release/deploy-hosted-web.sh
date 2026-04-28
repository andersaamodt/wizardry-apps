#!/bin/sh

# Deploy hosted web bundle to a self-hosted target over SSH.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: deploy-hosted-web.sh BUNDLE_DIR

Deploys hosted web artifacts via rsync/ssh using deploy env vars.
USAGE
  exit 0
  ;;
esac

set -eu

bundle_dir=${1-}

if [ -z "$bundle_dir" ] || [ ! -d "$bundle_dir" ]; then
  printf '%s\n' "deploy-hosted-web: BUNDLE_DIR required" >&2
  exit 2
fi

if [ -z "${WEB_DEPLOY_HOST-}" ] || [ -z "${WEB_DEPLOY_USER-}" ] || [ -z "${WEB_DEPLOY_PATH-}" ] || [ -z "${WEB_DEPLOY_SSH_KEY_BASE64-}" ]; then
  printf '%s\n' "deploy-hosted-web: missing deploy secrets" >&2
  exit 1
fi

valid_deploy_host() {
  case "${1-}" in ""|*[!A-Za-z0-9.-]*|.*|*.|*..*) return 1 ;; esac
}

valid_deploy_user() {
  case "${1-}" in ""|*[!A-Za-z0-9._-]*) return 1 ;; esac
}

valid_deploy_path() {
  case "${1-}" in /*) ;; *) return 1 ;; esac
  case "$1" in *..*|*'//'*) return 1 ;; esac
  case "$1" in *[!A-Za-z0-9._/-]*) return 1 ;; esac
}

valid_deploy_host "$WEB_DEPLOY_HOST" || {
  printf '%s\n' "deploy-hosted-web: invalid deploy host" >&2
  exit 2
}

valid_deploy_user "$WEB_DEPLOY_USER" || {
  printf '%s\n' "deploy-hosted-web: invalid deploy user" >&2
  exit 2
}

valid_deploy_path "$WEB_DEPLOY_PATH" || {
  printf '%s\n' "deploy-hosted-web: invalid deploy path" >&2
  exit 2
}

if ! command -v rsync >/dev/null 2>&1 || ! command -v ssh >/dev/null 2>&1 || ! command -v openssl >/dev/null 2>&1; then
  printf '%s\n' "deploy-hosted-web: rsync, ssh, and openssl are required" >&2
  exit 1
fi

key_file=$(mktemp "${TMPDIR:-/tmp}/web-deploy.XXXXXX.key")
trap 'rm -f "$key_file"' EXIT HUP INT TERM
printf '%s' "$WEB_DEPLOY_SSH_KEY_BASE64" | openssl base64 -d -A > "$key_file"
chmod 600 "$key_file"

rsync -az --delete \
  -e "ssh -i $key_file -o StrictHostKeyChecking=no" \
  "$bundle_dir/" \
  "$WEB_DEPLOY_USER@$WEB_DEPLOY_HOST:$WEB_DEPLOY_PATH/"
