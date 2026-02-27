# Guide pas a pas - Deploiement VPS SIG GN

Ce guide est base sur les fichiers de prod du repo:
- `docker/docker-compose.prod.yml`
- `docker/docker-compose.prod.vps.yml`
- `docker/env.prod.local.example`
- `docker/nginx/default.conf`

## 1) Preconditions

- VPS Ubuntu 22.04/24.04
- Domaine pointe vers l'IP du VPS (A record)
- Acces SSH avec un utilisateur sudo (ex: `ubuntu`)
- Repo GitHub disponible (SSH ou HTTPS)

Variables a definir pour les commandes:

```bash
export DOMAIN="example.com"
export DOMAIN_WWW="www.example.com"
export REPO_URL="git@github.com:ORG/REPO.git"
export BRANCH="main"
export APP_DIR="/opt/sig_gn"
```

## 2) Premiere connexion VPS

```bash
ssh ubuntu@IP_DU_VPS
sudo apt-get update
sudo apt-get install -y git
sudo mkdir -p /opt
sudo chown -R "$USER":"$USER" /opt
git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
cd "$APP_DIR"
chmod +x scripts/vps/*.sh
```

## 3) Bootstrap serveur (Docker + Compose + firewall + nginx host)

```bash
cd "$APP_DIR"
sudo APP_USER="$USER" INSTALL_HOST_NGINX=1 bash scripts/vps/bootstrap_ubuntu.sh
```

Reconnecte ta session SSH pour appliquer le groupe docker:

```bash
exit
ssh ubuntu@IP_DU_VPS
```

Verification:

```bash
docker --version
docker compose version
```

## 4) Config prod (secrets + domaine)

```bash
cd "$APP_DIR/docker"
cp -n env.prod.local.example env.prod.local
cp -n .env.vps.example .env
```

Edite `docker/env.prod.local` et remplace tous les placeholders:
- `POSTGRES_PASSWORD`
- `DJANGO_SECRET_KEY`
- `DJANGO_ALLOWED_HOSTS`
- `DJANGO_CORS_ALLOWED_ORIGINS`
- `DJANGO_CSRF_TRUSTED_ORIGINS`
- `APP_URL`
- `KOBO_*` si tu actives Kobo

Exemple attendu (adapter ton domaine):
- `DJANGO_ALLOWED_HOSTS=backend,nginx,example.com,www.example.com`
- `DJANGO_CORS_ALLOWED_ORIGINS=https://example.com,https://www.example.com`
- `DJANGO_CSRF_TRUSTED_ORIGINS=https://example.com,https://www.example.com`
- `APP_URL=https://example.com`

## 5) Deployer les conteneurs

```bash
cd "$APP_DIR"
REPO_URL="$REPO_URL" BRANCH="$BRANCH" APP_DIR="$APP_DIR" SIGGN_HTTP_BIND="127.0.0.1:8080" \
  bash scripts/vps/deploy_prod.sh
```

Notes:
- Le script utilise `docker-compose.prod.yml` + `docker-compose.prod.vps.yml`.
- Le service app est expose seulement en local VPS (`127.0.0.1:8080`).

## 6) Configurer nginx host (TLS)

### 6.1 Vhost HTTP proxy local

```bash
sudo cp "$APP_DIR/scripts/vps/nginx.siggn.vhost.example" /etc/nginx/sites-available/siggn.conf
sudo sed -i "s/example.com/$DOMAIN/g" /etc/nginx/sites-available/siggn.conf
sudo sed -i "s/www.example.com/$DOMAIN_WWW/g" /etc/nginx/sites-available/siggn.conf
sudo ln -sfn /etc/nginx/sites-available/siggn.conf /etc/nginx/sites-enabled/siggn.conf
sudo nginx -t
sudo systemctl reload nginx
```

### 6.2 Certificat LetsEncrypt

```bash
sudo certbot --nginx -d "$DOMAIN" -d "$DOMAIN_WWW"
```

Puis:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## 7) Verifications post-deploiement

```bash
curl -I "https://$DOMAIN"
curl -I "https://$DOMAIN/api/docs/"
```

Verifier les conteneurs:

```bash
cd "$APP_DIR/docker"
export SIGGN_ENV_PROD_FILE=./env.prod.local
export SIGGN_HTTP_BIND=127.0.0.1:8080
docker compose -f docker-compose.prod.yml -f docker-compose.prod.vps.yml ps
docker compose -f docker-compose.prod.yml -f docker-compose.prod.vps.yml logs backend --tail=100
docker compose -f docker-compose.prod.yml -f docker-compose.prod.vps.yml logs frontend --tail=100
docker compose -f docker-compose.prod.yml -f docker-compose.prod.vps.yml logs nginx --tail=100
```

## 8) Mise a jour applicative (routine)

```bash
cd "$APP_DIR"
REPO_URL="$REPO_URL" BRANCH="$BRANCH" APP_DIR="$APP_DIR" SIGGN_HTTP_BIND="127.0.0.1:8080" \
  bash scripts/vps/deploy_prod.sh
```

## 9) Backup / restore base

Backup:

```bash
cd "$APP_DIR/docker"
export SIGGN_ENV_PROD_FILE=./env.prod.local
export SIGGN_HTTP_BIND=127.0.0.1:8080
docker compose -f docker-compose.prod.yml -f docker-compose.prod.vps.yml exec -T db \
  pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "/opt/backup_siggn_$(date +%F_%H%M).sql"
```

Restore:

```bash
cd "$APP_DIR/docker"
export SIGGN_ENV_PROD_FILE=./env.prod.local
export SIGGN_HTTP_BIND=127.0.0.1:8080
cat /opt/backup_siggn_YYYY-MM-DD_HHMM.sql | docker compose -f docker-compose.prod.yml -f docker-compose.prod.vps.yml exec -T db \
  psql -U "$POSTGRES_USER" "$POSTGRES_DB"
```

## 10) Rollback rapide

```bash
cd "$APP_DIR"
git fetch --all --tags
git checkout <commit_ou_tag_stable>
REPO_URL="$REPO_URL" BRANCH="$BRANCH" APP_DIR="$APP_DIR" SIGGN_HTTP_BIND="127.0.0.1:8080" \
  bash scripts/vps/deploy_prod.sh
```

## 11) Points critiques

- Ne jamais deployer avec des valeurs `CHANGE_ME_*`.
- Garder `DJANGO_DEBUG=0` en prod.
- `DJANGO_CORS_ALLOWED_ORIGINS` et `DJANGO_CSRF_TRUSTED_ORIGINS` doivent etre en `https://`.
- Le header `X-Forwarded-Proto` doit rester `https` depuis nginx host vers l'app.

## 12) Cas 3 repos (ton cas actuel)

Repos:
- web: `https://github.com/Ashmohamed6/sig-gn-web`
- api: `https://github.com/Ashmohamed6/sig-gn-api`
- deploy: `https://github.com/Ashmohamed6/sig-gn-deploy`

IP VPS:
- `31.207.39.95`

Structure conseillee:
- `/opt/sig_gn/sig-gn-web`
- `/opt/sig_gn/sig-gn-api`
- `/opt/sig_gn/sig-gn-deploy`

Commandes:

```bash
ssh ubuntu@31.207.39.95
sudo apt-get update && sudo apt-get install -y git
sudo mkdir -p /opt/sig_gn && sudo chown -R "$USER":"$USER" /opt/sig_gn

# depuis ce repo local, copie d'abord scripts/vps/*.sh vers le VPS,
# puis sur le VPS:
bash /opt/sig_gn/sig-gn-deploy/scripts/vps/clone_siggn_repos.sh
```

Si le `docker-compose.prod.yml` est dans `sig-gn-deploy/docker`:

```bash
cd /opt/sig_gn/sig-gn-deploy/docker
cp -n env.prod.local.example env.prod.local
cp -n .env.vps.example .env
# editer env.prod.local (secrets + domaine)

export SIGGN_ENV_PROD_FILE=./env.prod.local
export SIGGN_HTTP_BIND=127.0.0.1:8080
docker compose -f docker-compose.prod.yml -f docker-compose.prod.vps.yml up -d --build --remove-orphans
```

Important:
- pour un vrai mode prod (`DJANGO_DEBUG=0`), il faut un domaine + certificat TLS valide.
- un deploiement en IP seule (`31.207.39.95`) ne permet pas un LetsEncrypt standard.
