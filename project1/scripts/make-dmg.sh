#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/FrameScript.app"
DMG_PATH="$BUILD_DIR/FrameScript-macOS.dmg"
ARM_BUILD="$PROJECT_DIR/.build-arm64"
INTEL_BUILD="$PROJECT_DIR/.build-x86_64"

rm -rf "$BUILD_DIR" "$ARM_BUILD" "$INTEL_BUILD"
mkdir -p "$BUILD_DIR" "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

swift build --package-path "$PROJECT_DIR" --build-path "$ARM_BUILD" --configuration release --triple arm64-apple-macosx13.0
swift build --package-path "$PROJECT_DIR" --build-path "$INTEL_BUILD" --configuration release --triple x86_64-apple-macosx13.0

ARM_BINARY="$(find "$ARM_BUILD" -type f -name FrameScript -path '*/release/*' -print -quit)"
INTEL_BINARY="$(find "$INTEL_BUILD" -type f -name FrameScript -path '*/release/*' -print -quit)"
test -n "$ARM_BINARY" && test -x "$ARM_BINARY"
test -n "$INTEL_BINARY" && test -x "$INTEL_BINARY"

lipo -create "$ARM_BINARY" "$INTEL_BINARY" -output "$APP_DIR/Contents/MacOS/FrameScript"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
lipo -verify_arch arm64 x86_64 "$APP_DIR/Contents/MacOS/FrameScript"

hdiutil create \
  -volname "FrameScript" \
  -srcfolder "$APP_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"
hdiutil verify "$DMG_PATH"

MOUNT_DIR="$(mktemp -d)"
cleanup() {
  hdiutil detach "$MOUNT_DIR" -quiet || true
  rmdir "$MOUNT_DIR" 2>/dev/null || true
}
trap cleanup EXIT
hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_DIR" -quiet
test -x "$MOUNT_DIR/FrameScript.app/Contents/MacOS/FrameScript"
test -f "$MOUNT_DIR/FrameScript.app/Contents/Info.plist"
echo "Verified universal macOS DMG: $DMG_PATH"
