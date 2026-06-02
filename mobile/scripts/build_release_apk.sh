#!/usr/bin/env bash
set -euo pipefail
API_BASE_URL="${1:-${API_BASE_URL:-http://10.0.2.2:3000}}"
cd "$(dirname "$0")/.."
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL="$API_BASE_URL"
mkdir -p ../dist
cp build/app/outputs/flutter-apk/app-release.apk ../dist/EMP-Control.apk
echo "APK copied to dist/EMP-Control.apk"
