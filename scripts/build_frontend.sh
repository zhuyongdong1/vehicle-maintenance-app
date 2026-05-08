#!/usr/bin/env bash
set -euo pipefail

if [ -z "${API_KEY:-}" ]; then
  echo "API_KEY is required. Use the same value as the backend API_KEY." >&2
  exit 1
fi

API_BASE_URL="${API_BASE_URL:-https://ulbooks.cn/api}"
APP_DOMAIN="${APP_DOMAIN:-ulbooks.cn}"
PUBSPEC_VERSION="$(awk '/^version:/ {print $2; exit}' frontend/pubspec.yaml)"
APP_VERSION="${APP_VERSION:-${PUBSPEC_VERSION%%+*}}"
APP_BUILD_NUMBER="${APP_BUILD_NUMBER:-${PUBSPEC_VERSION##*+}}"
APP_UPDATE_MANIFEST_URL="${APP_UPDATE_MANIFEST_URL:-https://${APP_DOMAIN}/downloads/app-version.json}"
TARGET="${1:-web}"

cd "$(dirname "$0")/../frontend"

common_args=(
  "--dart-define=API_KEY=${API_KEY}"
  "--dart-define=API_BASE_URL=${API_BASE_URL}"
  "--dart-define=APP_DOMAIN=${APP_DOMAIN}"
  "--dart-define=APP_VERSION=${APP_VERSION}"
  "--dart-define=APP_BUILD_NUMBER=${APP_BUILD_NUMBER}"
  "--dart-define=APP_UPDATE_MANIFEST_URL=${APP_UPDATE_MANIFEST_URL}"
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
