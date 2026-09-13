#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
case "$MODE" in run|--debug|--logs|--telemetry|--verify|--build) ;; *) echo "Usage: $0 [--build|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;; esac
case "${BUILD_CONFIGURATION:-Debug}" in
  debug|Debug) CONFIGURATION=Debug ;;
  release|Release) CONFIGURATION=Release ;;
  *) echo "BUILD_CONFIGURATION must be Debug or Release." >&2; exit 2 ;;
esac
xcodebuild -project "$ROOT_DIR/RegionTranslate.xcodeproj" -scheme RegionTranslate \
  -configuration "$CONFIGURATION" -destination 'platform=macOS' \
  -derivedDataPath "$ROOT_DIR/.derivedData" build
APP_BUNDLE="$ROOT_DIR/.derivedData/Build/Products/$CONFIGURATION/RegionTranslate.app"
codesign --verify --strict "$APP_BUNDLE"
ASSESSMENT=$(spctl --assess --type execute --verbose=4 "$APP_BUNDLE" 2>&1) || {
  case "$ASSESSMENT" in
    *CSSMERR_TP_CERT_REVOKED*|*revoked*|*malware*)
      echo "$ASSESSMENT" >&2
      echo "Build stopped: macOS blocks this signing identity. Select a trusted certificate in Xcode's Signing & Capabilities." >&2
      exit 1
      ;;
  esac
}
mkdir -p "$ROOT_DIR/dist"
if [[ -d "$ROOT_DIR/dist/RegionTranslate.app" ]]; then
  rm -rf "$ROOT_DIR/dist/RegionTranslate.app"
fi
ditto "$APP_BUNDLE" "$ROOT_DIR/dist/RegionTranslate.app"
codesign --verify --deep --strict "$ROOT_DIR/dist/RegionTranslate.app"
pkill -x RegionTranslate >/dev/null 2>&1 || true
case "$MODE" in
  --build) exit 0 ;;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/RegionTranslate" ;;
  *)
    /usr/bin/open -n "$APP_BUNDLE"
    case "$MODE" in
      --verify) sleep 1; pgrep -x RegionTranslate ;;
      --logs) /usr/bin/log stream --info --style compact --predicate 'process == "RegionTranslate"' ;;
      --telemetry) /usr/bin/log stream --info --style compact --predicate 'subsystem == "local.RegionTranslate"' ;;
    esac
    ;;
esac
