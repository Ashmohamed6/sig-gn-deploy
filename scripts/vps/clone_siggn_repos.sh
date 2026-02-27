#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash scripts/vps/clone_siggn_repos.sh
#
# Optional:
#   BASE_DIR=/opt/sig_gn
#   WEB_REPO=https://github.com/Ashmohamed6/sig-gn-web
#   API_REPO=https://github.com/Ashmohamed6/sig-gn-api
#   DEPLOY_REPO=https://github.com/Ashmohamed6/sig-gn-deploy
#   BRANCH=main

BASE_DIR="${BASE_DIR:-/opt/sig_gn}"
WEB_REPO="${WEB_REPO:-https://github.com/Ashmohamed6/sig-gn-web}"
API_REPO="${API_REPO:-https://github.com/Ashmohamed6/sig-gn-api}"
DEPLOY_REPO="${DEPLOY_REPO:-https://github.com/Ashmohamed6/sig-gn-deploy}"
BRANCH="${BRANCH:-main}"

mkdir -p "${BASE_DIR}"

sync_repo() {
  local url="$1"
  local dir="$2"
  if [[ ! -d "${dir}/.git" ]]; then
    git clone --branch "${BRANCH}" "${url}" "${dir}"
    return
  fi
  git -C "${dir}" fetch origin "${BRANCH}"
  git -C "${dir}" checkout "${BRANCH}"
  git -C "${dir}" pull --ff-only origin "${BRANCH}"
}

echo "[1/3] web repo"
sync_repo "${WEB_REPO}" "${BASE_DIR}/sig-gn-web"

echo "[2/3] api repo"
sync_repo "${API_REPO}" "${BASE_DIR}/sig-gn-api"

echo "[3/3] deploy repo"
sync_repo "${DEPLOY_REPO}" "${BASE_DIR}/sig-gn-deploy"

echo "Done."
echo "Repos synced under: ${BASE_DIR}"
