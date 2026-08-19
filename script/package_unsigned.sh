#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CueDex"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/CueDex.xcodeproj"
DERIVED_DATA="$ROOT_DIR/.build/ReleaseDerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR=""
ARCH_REQUEST="universal"

usage() {
  cat <<'EOF'
usage: ./script/package_unsigned.sh [--arch universal|x86_64|arm64]

  universal  Build for Intel and Apple silicon (default)
  x86_64     Build for Intel Macs only
  arm64      Build for Apple silicon Macs only
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      if [[ $# -lt 2 ]]; then
        echo "error: --arch requires a value" >&2
        usage >&2
        exit 2
      fi
      ARCH_REQUEST="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$ARCH_REQUEST" in
  universal)
    BUILD_ARCHS="arm64 x86_64"
    ARCH_LABEL="universal"
    REQUIRED_ARCHITECTURES=(arm64 x86_64)
    ;;
  x86_64|x64|intel)
    BUILD_ARCHS="x86_64"
    ARCH_LABEL="x86_64"
    REQUIRED_ARCHITECTURES=(x86_64)
    ;;
  arm64|apple-silicon)
    BUILD_ARCHS="arm64"
    ARCH_LABEL="arm64"
    REQUIRED_ARCHITECTURES=(arm64)
    ;;
  *)
    echo "error: unsupported architecture: $ARCH_REQUEST" >&2
    usage >&2
    exit 2
    ;;
esac

cleanup() {
  if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
    rm -rf -- "$STAGING_DIR"
  fi
}

trap cleanup EXIT INT TERM

for required_command in xcodebuild codesign lipo hdiutil ditto shasum; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "error: required command not found: $required_command" >&2
    exit 1
  fi
done

echo "Building Release app ($BUILD_ARCHS)..."
xcodebuild \
  -quiet \
  -project "$PROJECT_PATH" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  ARCHS="$BUILD_ARCHS" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  clean build

if [[ ! -d "$APP_BUNDLE" || ! -x "$APP_BINARY" ]]; then
  echo "error: expected app bundle was not produced: $APP_BUNDLE" >&2
  exit 1
fi

ARCHITECTURES="$(lipo -archs "$APP_BINARY")"
for required_architecture in "${REQUIRED_ARCHITECTURES[@]}"; do
  if [[ " $ARCHITECTURES " != *" $required_architecture "* ]]; then
    echo "error: missing $required_architecture architecture; found: $ARCHITECTURES" >&2
    exit 1
  fi
done
if [[ "$ARCH_LABEL" != "universal" && "$ARCHITECTURES" != "$BUILD_ARCHS" ]]; then
  echo "error: expected only $BUILD_ARCHS; found: $ARCHITECTURES" >&2
  exit 1
fi

echo "Applying an ad-hoc signature..."
codesign --force --sign - --timestamp=none "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION-$ARCH_LABEL-unsigned.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"

mkdir -p "$DIST_DIR"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cuedex-package.XXXXXX")"
ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating $(basename "$DMG_PATH")..."
hdiutil create \
  -quiet \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

echo "Verifying disk image..."
hdiutil verify -quiet "$DMG_PATH"

CHECKSUM="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
printf '%s  %s\n' "$CHECKSUM" "$(basename "$DMG_PATH")" > "$CHECKSUM_PATH"

echo
echo "Package complete"
echo "  App version:  $VERSION ($BUILD_NUMBER)"
echo "  Architectures: $ARCHITECTURES"
echo "  DMG:          $DMG_PATH"
echo "  SHA-256:      $CHECKSUM"
echo
echo "This package is ad-hoc signed and not notarized. macOS Gatekeeper may"
echo "require users to approve CueDex in System Settings > Privacy & Security."
