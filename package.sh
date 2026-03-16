#!/bin/bash
set -euo pipefail

APP_NAME="2x Claude"
BUNDLE_ID="com.junwatu.2xclaude"
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/dist"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

echo "==> Building release binary..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1

BINARY="$SCRIPT_DIR/.build/release/Claude2xUsage"
if [ ! -f "$BINARY" ]; then
    echo "ERROR: Release binary not found at $BINARY"
    exit 1
fi

echo "==> Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_DIR/Contents/MacOS/Claude2xUsage"

# Copy mascot icon to Resources
cp "$SCRIPT_DIR/mascot.png" "$APP_DIR/Contents/Resources/mascot.png"

# Create icns from mascot.png (best-effort)
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
if command -v sips &>/dev/null && command -v iconutil &>/dev/null; then
    echo "==> Generating app icon..."
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size "$SCRIPT_DIR/mascot.png" --out "$ICONSET_DIR/icon_${size}x${size}.png" &>/dev/null
        double=$((size * 2))
        sips -z $double $double "$SCRIPT_DIR/mascot.png" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" &>/dev/null
    done
    iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns" 2>/dev/null && \
        ICON_ENTRY="<key>CFBundleIconFile</key><string>AppIcon</string>" || \
        ICON_ENTRY=""
    rm -rf "$ICONSET_DIR"
else
    ICON_ENTRY=""
fi

# Write Info.plist
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>Claude2xUsage</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    $ICON_ENTRY
</dict>
</plist>
PLIST

# Ad-hoc code sign (required for SMAppService / Launch at Login)
echo "==> Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_DIR"

echo "==> App bundle created at: $APP_DIR"

# Create DMG
DMG_PATH="$BUILD_DIR/2xClaude-$VERSION.dmg"
echo "==> Creating DMG..."
rm -f "$DMG_PATH"

# Create a temporary folder for DMG contents
DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_DIR" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "2x Claude" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH" 2>/dev/null

rm -rf "$DMG_STAGING"

echo ""
echo "================================================"
echo "  Packaging complete!"
echo "  App:  $APP_DIR"
echo "  DMG:  $DMG_PATH"
echo "================================================"
echo ""
echo "To install: open $DMG_PATH and drag to Applications."
