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

# ── 3. Create DMG (before notarizing so we notarize the DMG directly) ─────────
echo "▶ Creating DMG..."
hdiutil create \
  -volname "${APP_NAME} ${VERSION}" \
  -srcfolder "$APP_PATH" \
  -ov -format UDZO \
  "$DMG_PATH"

# ── 4. Notarize DMG ────────────────────────────────────────────────────────────
echo "▶ Notarizing (this takes a few minutes)..."
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

# ── 5. Staple ─────────────────────────────────────────────────────────────────
echo "▶ Stapling..."
xcrun stapler staple "$DMG_PATH"

# ── 6. Verify ─────────────────────────────────────────────────────────────────
echo "▶ Verifying..."
spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH"

# ── 7. Publish GitHub release ─────────────────────────────────────────────────
echo "▶ Publishing GitHub release ${TAG}..."
gh release create "$TAG" \
  "$DMG_PATH" \
  --title "${APP_NAME} ${TAG}" \
  --generate-notes

echo ""
echo "✅ Released: ${TAG}"
echo "   DMG: ${DMG_PATH}"
