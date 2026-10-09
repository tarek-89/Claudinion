#!/usr/bin/env bash
# Builds Claudinion.app into ./build. Pass --install to also copy it to ~/Applications and open it.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Claudinion"
VERSION="$(tr -d '[:space:]' < VERSION)"
MIN_MACOS="14.0"
BUILD="build"
APP="$BUILD/$APP_NAME.app"

if ! command -v swiftc >/dev/null; then
    echo "swiftc not found. Install the Xcode Command Line Tools first:  xcode-select --install" >&2
    exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Universal binary: Apple silicon and Intel.
for arch in arm64 x86_64; do
    echo "Compiling for ${arch}..."
    swiftc -O -swift-version 5 -target "$arch-apple-macos$MIN_MACOS" \
        Sources/Claudinion/main.swift -o "$BUILD/$APP_NAME-$arch"
done
lipo -create -output "$APP/Contents/MacOS/$APP_NAME" "$BUILD/$APP_NAME-arm64" "$BUILD/$APP_NAME-x86_64"
rm "$BUILD/$APP_NAME-arm64" "$BUILD/$APP_NAME-x86_64"

# App icon, drawn by the app itself.
ICONSET="$BUILD/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
"$APP/Contents/MacOS/$APP_NAME" --icon "$BUILD/icon.png"
for size in 16 32 128 256 512; do
    sips -z $size $size "$BUILD/icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "$BUILD/icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET" "$BUILD/icon.png"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>io.github.tarek-89.claudinion</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x "$APP_NAME" 2>/dev/null || true
    mkdir -p "$HOME/Applications"
    rm -rf "$HOME/Applications/$APP_NAME.app"
    cp -R "$APP" "$HOME/Applications/"
    open "$HOME/Applications/$APP_NAME.app"
    echo "Installed to ~/Applications/$APP_NAME.app"
fi
