#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

"${SCRIPT_DIR}/build_app.sh"

DEST_DIR="${HOME}/Applications"
mkdir -p "${DEST_DIR}"

echo "==> A instalar SeeUsage.app em ${DEST_DIR}..."
rm -rf "${DEST_DIR}/SeeUsage.app"
cp -R "${ROOT_DIR}/dist/SeeUsage.app" "${DEST_DIR}/"

echo "==> Instalado com sucesso em ${DEST_DIR}/SeeUsage.app"
