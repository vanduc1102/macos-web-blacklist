#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

# Ensure application bundle exists
if [ ! -d "WebBlacklist.app" ]; then
    echo "🔨 WebBlacklist.app not found. Building first..."
    ./scripts/build-app.sh
fi

DMG_NAME="${1:-WebBlacklist.dmg}"
VOL_NAME="Web Blacklist"
STAGING_DIR="/tmp/web_blacklist_dmg_staging_$$"

echo "💿 Creating DMG package: $DMG_NAME..."
rm -rf "$STAGING_DIR" "$DMG_NAME"
mkdir -p "$STAGING_DIR"

# Copy App bundle
cp -R "WebBlacklist.app" "$STAGING_DIR/"

# Create symlink to Applications
ln -s /Applications "$STAGING_DIR/Applications"

# Add a first-time setup guide for Gatekeeper
cat << 'EOF' > "$STAGING_DIR/FIRST_TIME_OPEN.txt"
===================================================
  Web Blacklist - Installation & First Launch Guide
===================================================

1. INSTALL:
   Drag 'WebBlacklist' into the 'Applications' folder.

2. FIRST TIME OPENING (Gatekeeper prompt):
   Because this is an open-source app distributed outside
   the Mac App Store, macOS may show:
   "Apple could not verify WebBlacklist is free of malware..."

   To open it (only needed on the very first launch):
   -------------------------------------------------
   👉 Option A (Recommended):
      Right-click (or Control-click) WebBlacklist in Applications,
      select "Open", then click "Open" on the dialog.

   👉 Option B (System Settings):
      Go to System Settings -> Privacy & Security -> Security,
      and click "Open Anyway".

   👉 Option C (Terminal):
      Open Terminal and run:
      xattr -cr /Applications/WebBlacklist.app

3. ENJOY:
   Look for the shield icon in your macOS menu bar!
EOF

# Ad-hoc sign the app in staging again if needed
codesign --force --deep --sign - "$STAGING_DIR/WebBlacklist.app" 2>/dev/null || true

# Generate compressed read-only DMG
hdiutil create -volname "$VOL_NAME" \
               -srcfolder "$STAGING_DIR" \
               -ov \
               -format UDZO \
               "$DMG_NAME"

rm -rf "$STAGING_DIR"

echo "✅ DMG generated successfully: $DIR/$DMG_NAME"
