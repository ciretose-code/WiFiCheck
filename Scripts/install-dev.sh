#!/bin/sh
# install-dev.sh — copy the Debug build to /Applications for testing.
#
# SMAppService.daemon requires the app to reside in /Applications
# (not ~/Applications, not DerivedData). Run this after building to
# install there so Option 1 (privileged helper) can be tested.
#
# Usage (from repo root):
#   ./Scripts/install-dev.sh
#
# Or wire it as an Xcode scheme Post-build Action:
#   "${SRCROOT}/Scripts/install-dev.sh"

set -e

# When invoked from Xcode the env vars are set; when run manually, derive them.
if [ -z "${WRAPPER_NAME}" ]; then
  WRAPPER_NAME="WiFiCheck.app"
fi

if [ -z "${BUILT_PRODUCTS_DIR}" ]; then
  # Find the most recent Debug build in DerivedData
  BUILT_PRODUCTS_DIR=$(find "${HOME}/Library/Developer/Xcode/DerivedData" \
    -path "*/Build/Products/Debug/${WRAPPER_NAME}" -maxdepth 6 2>/dev/null \
    | sort -t/ -k1,1 | tail -1 | xargs dirname 2>/dev/null)
  if [ -z "${BUILT_PRODUCTS_DIR}" ]; then
    echo "install-dev.sh: could not locate built ${WRAPPER_NAME} in DerivedData" >&2
    exit 1
  fi
fi

SRC="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}"
DEST="/Applications/${WRAPPER_NAME}"

if [ ! -d "${SRC}" ]; then
  echo "install-dev.sh: source not found: ${SRC}" >&2
  exit 1
fi

echo "install-dev.sh: copying ${WRAPPER_NAME} → ${DEST}"
# ditto preserves code signatures; sudo needed to write to /Applications
sudo ditto "${SRC}" "${DEST}"
echo "install-dev.sh: done — run /Applications/${WRAPPER_NAME} to test Option 1 (helper daemon)"
