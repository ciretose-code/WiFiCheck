#!/bin/sh
# install-dev.sh — called by Xcode scheme post-build action
# Copies the built Debug app to ~/Applications so Full Disk Access
# can be granted to a stable path (avoids navigating DerivedData).
# Grant FDA once in: System Settings → Privacy & Security → Full Disk Access

set -e

if [ "${CONFIGURATION}" != "Debug" ]; then
  exit 0
fi

DEST="${HOME}/Applications/${WRAPPER_NAME}"

mkdir -p "${HOME}/Applications"
ditto "${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}" "${DEST}"
echo "wifi-check: installed ${WRAPPER_NAME} → ${DEST}"
