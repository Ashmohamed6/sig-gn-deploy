#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   REPO_URL=git@github.com:ORG/REPO.git BRANCH=main APP_DIR=/opt/sig_gn bash scripts/vps/deploy_prod.sh
#
# Optional:
#   SIGGN_HTTP_BIND=127.0.0.1:8080

REPO_URL="${REPO_URL:-}"
BRANCH="${BRANCH:-main}"
APP_DIR="${APP_DIR:-/opt/sig_gn}"
SIGGN_HTTP_BIND_VALUE="${SIGGN_HTTP_BIND:-127.0.0.1:8080}"

if [[ -z "${REPO_URL}" ]]; then
  echo "Missing REPO_URL. Example: REPO_URL=git@github.com:ORG/REPO.git"
  exit 1
fi

echo "[1/7] Clone or update repo"
if [[ ! -d "${APP_DIR}/.git" ]]; then
  git clone --branch "${BRANCH}" "${REPO_URL}" "${APP_DIR}"
else
  git -C "${APP_DIR}" fetch origin "${BRANCH}"
  git -C "${APP_DIR}" checkout "${BRANCH}"
  git -C "${APP_DIR}" pull --ff-only origin "${BRANCH}"
fi

echo "[2/7] Go to docker folder"
cd "${APP_DIR}/docker"

echo "[3/7] Ensure env files"
if [[ ! -f "env.prod.local" ]]; then
  cp env.prod.local.example env.prod.local
  echo "Created docker/env.prod.local from example."
  echo "Fill secrets/domain values in docker/env.prod.local, then re-run."
  exit 2
fi

if [[ ! -f ".env" ]]; then
  cp .env.vps.example .env
fi

echo "[4/7] Export compose vars"
export SIGGN_ENV_PROD_FILE=./env.prod.local
export SIGGN_HTTP_BIND="${SIGGN_HTTP_BIND_VALUE}"

echo "[5/7] Validate compose"
docker compose -f docker-compose.prod.yml -f docker-compose.prod.vps.yml config >/dev/null

echo "[6/7] Build and start containers"
docker compose -f docker-compose.prod.yml -f docker-compose.prod.vps.yml up -d --build --remove-orphans

echo "[7/7] Runtime status"
docker compose -f docker-compose.prod.yml -f docker-compose.prod.vps.yml ps
echo ""
echo "Deployment done."
echo "Useful checks:"
echo "  docker compose -f docker-compose.prod.yml -f docker-compose.prod.vps.yml logs backend --tail=100"
echo "  docker compose -f docker-compose.prod.yml -f docker-compose.prod.vps.yml logs frontend --tail=100"
echo "  docker compose -f docker-compose.prod.yml -f docker-compose.prod.vps.yml logs nginx --tail=100"
