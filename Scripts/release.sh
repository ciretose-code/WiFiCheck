#!/bin/bash
# Scripts/release.sh — Archive, notarize, staple, package DMG, and publish to GitHub.
#
# One-time credential setup (stores in your keychain, never needs repeating):
#   xcrun notarytool store-credentials "wifi-check-notary" \
#     --key ~/Code/.private_keys/AuthKey_<KEY_ID>.p8 \
#     --key-id <KEY_ID> \
#     --issuer <ISSUER_ID>
#
# Release signing (Hash/Check): minisign secret key at
#   ~/Code/.private_keys/ciretose.key
# Override with MINISIGN_SECRET_KEY if needed. Signing prompts for the key password.
#
# Usage:
#   ./Scripts/release.sh
#
set -euo pipefail

# ── Config ─────────────────────────────────────────────────────────────────────
SCHEME="WiFiCheck"
PROJECT="WiFiCheck.xcodeproj"
EXPORT_OPTIONS_TEMPLATE="Scripts/ExportOptions.plist.template"
EXPORT_OPTIONS="Scripts/ExportOptions.plist"   # generated; gitignored
NOTARY_PROFILE="wifi-check-notary"   # keychain profile name from store-credentials
MINISIGN_SECRET_KEY="${MINISIGN_SECRET_KEY:-$HOME/Code/.private_keys/ciretose.key}"

# Resolve Apple Team ID from the environment or Config/Local.xcconfig (never committed).
resolve_team_id() {
  if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
    printf '%s' "$DEVELOPMENT_TEAM"
    return
  fi
  if [ -f Config/Local.xcconfig ]; then
    local team
    team=$(sed -n 's/^DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*//p' Config/Local.xcconfig | tr -d '[:space:]' | head -1)
    if [ -n "$team" ] && [ "$team" != "YOUR_TEAM_ID" ]; then
      printf '%s' "$team"
      return
    fi
  fi
  echo "error: set DEVELOPMENT_TEAM or copy Config/Local.xcconfig.template → Config/Local.xcconfig" >&2
  exit 1
}

# ── Derived values ─────────────────────────────────────────────────────────────
PLIST="WiFiCheck/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST")
APP_NAME="WiFi Check"
GITHUB_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
CURRENT_BRANCH=$(git branch --show-current)
TEAM_ID="$(resolve_team_id)"

ARCHIVE_PATH="build/${SCHEME}.xcarchive"
EXPORT_PATH="build/export"

mkdir -p build

# Materialize export options with the local Team ID (placeholder stays out of git).
sed "s/TEAM_ID_PLACEHOLDER/${TEAM_ID}/" "$EXPORT_OPTIONS_TEMPLATE" > "$EXPORT_OPTIONS"
echo "▶ Using Team ID from local config (not committed)"


# ── 1. Archive (build phase increments CFBundleVersion in Info.plist) ──────────
echo "▶ Archiving ${APP_NAME} ${VERSION}..."
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  -allowProvisioningUpdates \
  | grep -E "^(error:|warning:|Build succeeded|Archive succeeded|/)" || true

# Read the incremented build number from the archive
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST")
TAG="v${VERSION}.${BUILD}"
DMG_NAME="${APP_NAME// /-}-${VERSION}"
DMG_PATH="build/${DMG_NAME}.dmg"
echo "▶ ${APP_NAME} ${VERSION} (build ${BUILD}) → ${TAG}"
echo "▶ GitHub repo: ${GITHUB_REPO}"

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
MOUNT_DIR="/Volumes/WiFiCheck-staging"

# Clean up any leftover state from a previous run
[ -f "$STAGING_DMG" ] && rm -f "$STAGING_DMG"
if [ -d "$MOUNT_DIR" ]; then
  hdiutil detach "$MOUNT_DIR" -quiet -force 2>/dev/null || true
fi

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

mkdir -p "$MOUNT_DIR/.background"
cp "Scripts/dmg-background.png" "$MOUNT_DIR/.background/dmg-background.png"
[ -f "Scripts/dmg-background@2x.png" ] && \
  cp "Scripts/dmg-background@2x.png" "$MOUNT_DIR/.background/dmg-background@2x.png"

# Configure window layout via Finder (alias gives Applications proper icon)
osascript <<APPLESCRIPT
tell application "Finder"
  -- Create alias before entering tell disk scope so startup disk resolves correctly
  set theDisk to disk "WiFiCheck-staging"
  make new alias file to folder "Applications" of startup disk at theDisk
  tell theDisk
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

# ── 7. Sign checksums for Hash/Check ──────────────────────────────────────────
echo "▶ Signing SHA256SUMS with minisign..."
command -v minisign >/dev/null || { echo "error: minisign not installed (brew install minisign)" >&2; exit 1; }
[ -f "$MINISIGN_SECRET_KEY" ] || { echo "error: minisign secret key not found: ${MINISIGN_SECRET_KEY}" >&2; exit 1; }
SUMS_PATH="build/SHA256SUMS"
(
  cd "$(dirname "$DMG_PATH")"
  shasum -a 256 "$(basename "$DMG_PATH")"
) > "$SUMS_PATH"
minisign -Sm "$SUMS_PATH" -s "$MINISIGN_SECRET_KEY" \
  -t "SHA256SUMS for $(basename "$DMG_PATH")"
SIG_PATH="${SUMS_PATH}.minisig"
echo "▶ ${SUMS_PATH} + ${SIG_PATH}"

# ── 8. Publish GitHub release ─────────────────────────────────────────────────
echo "▶ Publishing GitHub release ${TAG}..."
gh release create "$TAG" \
  --repo "$GITHUB_REPO" \
  "$DMG_PATH" \
  "$SUMS_PATH" \
  "$SIG_PATH" \
  --title "${APP_NAME} ${TAG}" \
  --notes "$(cat <<EOF
### Verify with Hash/Check

Download \`SHA256SUMS\` and \`SHA256SUMS.minisig\` alongside the DMG.
Public key: https://ciretose.com/ciretose.pub
EOF
)" \
  --generate-notes

# ── 9. Commit and push updated Info.plist ─────────────────────────────────────
echo "▶ Committing build number ${BUILD}..."
git add "$PLIST"
git commit -m "Release ${TAG} (build ${BUILD})" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
git push origin "$CURRENT_BRANCH"

echo ""
echo "✅ Released: ${TAG}"
echo "   DMG: ${DMG_PATH}"
echo "   Checksums: ${SUMS_PATH} (signed)"
