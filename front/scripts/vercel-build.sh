#!/usr/bin/env bash
set -euo pipefail

if [[ "${API_URL:-}" != https://* ]]; then
  echo 'Configure API_URL in Vercel with the public HTTPS API URL, including /api/v1.' >&2
  exit 1
fi
if [[ "$API_URL" == https://localhost* || "$API_URL" == https://127.* ]]; then
  echo 'API_URL must be publicly reachable, not localhost.' >&2
  exit 1
fi

FLUTTER_VERSION=3.47.3
if [[ ! -x .flutter-sdk/bin/flutter ]]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git .flutter-sdk
fi
export PATH="$PWD/.flutter-sdk/bin:$PATH"
flutter config --no-analytics
flutter pub get
flutter build web --release --dart-define="API_URL=${API_URL%/}"
