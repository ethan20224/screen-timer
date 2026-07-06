#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ScreenTime"
BUILD_CONFIG="release"
APP_BUNDLE="$ROOT_DIR/.build/$APP_NAME.app"
INSTALL_DIR="/Applications"

echo "Building $APP_NAME ($BUILD_CONFIG)..."
swift build -c "$BUILD_CONFIG" --package-path "$ROOT_DIR"

BIN_PATH="$ROOT_DIR/.build/$BUILD_CONFIG/$APP_NAME"
if [ ! -f "$BIN_PATH" ]; then
    echo "Build output not found at $BIN_PATH" >&2
    exit 1
fi

echo "Assembling app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Sources/$APP_NAME/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "Code signing (ad-hoc)..."
codesign --sign - --force --deep "$APP_BUNDLE"

echo "Installing to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$APP_BUNDLE" "$INSTALL_DIR/$APP_NAME.app"

echo "Done. Launch with: open $INSTALL_DIR/$APP_NAME.app"
