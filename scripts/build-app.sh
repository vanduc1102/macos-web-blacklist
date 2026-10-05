#!/usr/bin/env bash
set -e

# Change to project root directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "🔨 Building WebBlacklist in release mode for Apple Silicon (arm64)..."
swift build -c release --arch arm64

BIN_PATH="$(swift build -c release --arch arm64 --show-bin-path)/WebBlacklist"

APP_BUNDLE="WebBlacklist.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "📦 Packaging $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy binary
cp "$BIN_PATH" "$MACOS/WebBlacklist"
chmod +x "$MACOS/WebBlacklist"

# Copy Info.plist
cp "Resources/Info.plist" "$CONTENTS/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS/PkgInfo"

# Copy AppIcon if exists
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi

# Ad-hoc sign the bundle
echo "✍️  Ad-hoc code signing $APP_BUNDLE..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ Build and packaging complete!"
echo "📍 Application created at: $DIR/$APP_BUNDLE"
