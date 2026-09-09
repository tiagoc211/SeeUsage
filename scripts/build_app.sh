#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

echo "==> Compilando SeeUsage em release..."
if command -v conda >/dev/null 2>&1 && conda env list | grep -q "seeu"; then
    conda run -n seeu swift build -c release
else
    swift build -c release
fi

BIN_PATH="${ROOT_DIR}/.build/release/SeeUsage"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/SeeUsage.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Empacotando ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BIN_PATH}" "${MACOS_DIR}/SeeUsage"
chmod +x "${MACOS_DIR}/SeeUsage"

cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SeeUsage</string>
    <key>CFBundleIdentifier</key>
    <string>app.seeusage.SeeUsage</string>
    <key>CFBundleName</key>
    <string>SeeUsage</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

if command -v codesign >/dev/null 2>&1; then
    echo "==> Assinando ad-hoc..."
    codesign --force --deep --sign - "${APP_DIR}" 2>/dev/null || true
fi

echo "==> Concluído: ${APP_DIR}"
