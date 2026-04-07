#!/bin/bash
# Scripts/release.sh — Archive, notarize, staple, package DMG, and publish to GitHub.
#
# One-time credential setup (stores in your keychain, never needs repeating):
#   xcrun notarytool store-credentials "wifi-check-notary" \
#     --key ~/.private_keys/AuthKey_<KEY_ID>.p8 \
#     --key-id <KEY_ID> \
#     --issuer <ISSUER_ID>
#
# Usage:
#   ./Scripts/release.sh
#
set -euo pipefail

# ── Config ─────────────────────────────────────────────────────────────────────
SCHEME="WiFiCheck"
PROJECT="WiFiCheck.xcodeproj"
EXPORT_OPTIONS="Scripts/ExportOptions.plist"
NOTARY_PROFILE="wifi-check-notary"   # keychain profile name from store-credentials

# ── Derived values ─────────────────────────────────────────────────────────────
PLIST="WiFiCheck/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST")
TAG="v${VERSION}.${BUILD}"
APP_NAME="WiFi Check"
DMG_NAME="${APP_NAME// /-}-${VERSION}"

ARCHIVE_PATH="build/${SCHEME}.xcarchive"
EXPORT_PATH="build/export"
DMG_PATH="build/${DMG_NAME}.dmg"

echo "▶ ${APP_NAME} ${VERSION} (build ${BUILD}) → ${TAG}"
mkdir -p build

# ── 1. Archive ─────────────────────────────────────────────────────────────────
echo "▶ Archiving..."
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  -allowProvisioningUpdates \
  | grep -E "^(error:|warning:|Build succeeded|Archive succeeded|/)" || true

# ── 2. Export (Developer ID signed) ───────────────────────────────────────────
echo "▶ Exporting..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

# Locate the exported .app (product name may differ from display name)
APP_PATH=$(find "$EXPORT_PATH" -maxdepth 1 -name "*.app" | head -1)
if [ -z "$APP_PATH" ]; then
  echo "error: no .app found in ${EXPORT_PATH}" >&2
  exit 1
fi
echo "▶ Found app: ${APP_PATH}"

# ── 3. Create DMG with drag-to-Applications layout ────────────────────────────
echo "▶ Creating DMG..."

STAGING_DMG="build/staging.dmg"
APP_BUNDLE=$(basename "$APP_PATH")
MOUNT_DIR="/Volumes/${APP_NAME} ${VERSION}"

# Size: app + padding for background images and metadata
APP_SIZE_MB=$(du -sm "$APP_PATH" | awk '{print $1}')
STAGING_SIZE=$((APP_SIZE_MB + 20))

# Create a writable staging image
hdiutil create \
  -megabytes "$STAGING_SIZE" \
  -volname "${APP_NAME} ${VERSION}" \
  -fs HFS+ \
  -ov \
  "$STAGING_DMG"

hdiutil attach "$STAGING_DMG" \
  -mountpoint "$MOUNT_DIR" \
  -noautoopen \
  -readwrite

# Populate the volume
cp -r "$APP_PATH" "$MOUNT_DIR/"
ln -s /Applications "$MOUNT_DIR/Applications"

mkdir -p "$MOUNT_DIR/.background"
cp "Scripts/dmg-background.png" "$MOUNT_DIR/.background/dmg-background.png"
[ -f "Scripts/dmg-background@2x.png" ] && \
  cp "Scripts/dmg-background@2x.png" "$MOUNT_DIR/.background/dmg-background@2x.png"

# Configure window layout via Finder
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "${APP_NAME} ${VERSION}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 640, 480}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set background picture of viewOptions to file ".background:dmg-background.png"
    set position of item "${APP_BUNDLE}" of container window to {130, 180}
    set position of item "Applications" of container window to {410, 180}
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

sync
sleep 1
hdiutil detach "$MOUNT_DIR" -quiet

# Convert to compressed read-only final DMG
hdiutil convert "$STAGING_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" \
  -ov

rm -f "$STAGING_DMG"

# ── 4. Notarize DMG ────────────────────────────────────────────────────────────
echo "▶ Notarizing (this takes a few minutes)..."
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

# ── 5. Staple ─────────────────────────────────────────────────────────────────
echo "▶ Stapling..."
xcrun stapler staple "$DMG_PATH"

# ── 6. Verify ─────────────────────────────────────────────────────────────────
echo "▶ Verifying staple..."
xcrun stapler validate "$DMG_PATH"

# ── 7. Publish GitHub release ─────────────────────────────────────────────────
echo "▶ Publishing GitHub release ${TAG}..."
gh release create "$TAG" \
  "$DMG_PATH" \
  --title "${APP_NAME} ${TAG}" \
  --generate-notes

echo ""
echo "✅ Released: ${TAG}"
echo "   DMG: ${DMG_PATH}"
