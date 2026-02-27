#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   sudo APP_USER=ubuntu INSTALL_HOST_NGINX=1 bash scripts/vps/bootstrap_ubuntu.sh

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root (use sudo)."
  exit 1
fi

APP_USER="${APP_USER:-${SUDO_USER:-ubuntu}}"
INSTALL_HOST_NGINX="${INSTALL_HOST_NGINX:-1}"

echo "[1/6] Base packages"
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl gnupg lsb-release git ufw

echo "[2/6] Docker apt repo"
install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

echo "[3/6] Docker Engine + Compose plugin"
apt-get update
apt-get install -y --no-install-recommends docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

echo "[4/6] Docker group for app user: ${APP_USER}"
if id "${APP_USER}" >/dev/null 2>&1; then
  usermod -aG docker "${APP_USER}" || true
else
  echo "WARN: user ${APP_USER} not found. Add it to docker group manually later."
fi

echo "[5/6] Optional host nginx + certbot"
if [[ "${INSTALL_HOST_NGINX}" == "1" ]]; then
  apt-get install -y --no-install-recommends nginx certbot python3-certbot-nginx
  systemctl enable --now nginx
fi

echo "[6/6] Firewall"
ufw allow OpenSSH || true
ufw allow 80/tcp || true
ufw allow 443/tcp || true
ufw --force enable || true

echo "Bootstrap complete."
echo "IMPORTANT: reconnect SSH session so docker group is applied to ${APP_USER}."
