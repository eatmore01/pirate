#!/bin/sh
set -eu



CONFIG="${1:-debug}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Manager Dev}"

cd "$(dirname "$0")"

swift build -c "$CONFIG"

BIN_PATH=".build/$CONFIG/Pirate"
APP_DIR="dist/Pirate.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/Pirate"
cp Packaging/Info.plist "$APP_DIR/Contents/Info.plist"
cp Packaging/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

codesign --force --sign "$SIGN_IDENTITY" "$APP_DIR"

echo "Built and signed: $APP_DIR"
codesign -dv "$APP_DIR" 2>&1
