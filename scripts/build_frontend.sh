#!/usr/bin/env bash
set -euo pipefail

if [ -z "${API_KEY:-}" ]; then
  echo "API_KEY is required. Use the same value as the backend API_KEY." >&2
  exit 1
fi

API_BASE_URL="${API_BASE_URL:-https://ulbooks.cn/api}"
APP_DOMAIN="${APP_DOMAIN:-ulbooks.cn}"
TARGET="${1:-web}"

cd "$(dirname "$0")/../frontend"

common_args=(
  "--dart-define=API_KEY=${API_KEY}"
  "--dart-define=API_BASE_URL=${API_BASE_URL}"
  "--dart-define=APP_DOMAIN=${APP_DOMAIN}"
)

case "$TARGET" in
  web)
    flutter build web --release "${common_args[@]}"
    ;;
  apk)
    flutter build apk --release "${common_args[@]}"
    ;;
  *)
    echo "Usage: API_KEY=... $0 [web|apk]" >&2
    exit 1
    ;;
esac
