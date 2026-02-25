#!/usr/bin/env bash
set -euo pipefail

SERVER_HOST="${SERVER_HOST:?Set SERVER_HOST (e.g. 1.2.3.4)}"
SERVER_USER="${SERVER_USER:-ubuntu}"
APP_DIR="${APP_DIR:-/opt/ross-llm}"
REPO_URL="${REPO_URL:-https://github.com/RStaff/ross-llm.git}"

HF_MODEL="${HF_MODEL:-sentence-transformers/all-MiniLM-L6-v2}"
HF_DIM="${HF_DIM:-384}"

ssh -o StrictHostKeyChecking=accept-new "${SERVER_USER}@${SERVER_HOST}" bash -s <<EOF
set -euo pipefail

echo "==> Install docker"
if ! command -v docker >/dev/null; then
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(. /etc/os-release && echo "\$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker ${SERVER_USER} || true
fi

echo "==> Clone/update repo"
sudo mkdir -p "${APP_DIR}"
sudo chown -R ${SERVER_USER}:${SERVER_USER} "${APP_DIR}"
if [ ! -d "${APP_DIR}/.git" ]; then
  git clone "${REPO_URL}" "${APP_DIR}"
else
  cd "${APP_DIR}"
  git pull --ff-only
fi

cd "${APP_DIR}"

echo "==> Write HF override"
cat > docker-compose.hf.override.yml <<EOT
services:
  orchestrator:
    environment:
      EMBEDDING_PROVIDER: hf
      HF_EMBED_MODEL: ${HF_MODEL}
      EMBEDDING_DIM: "${HF_DIM}"
EOT

echo "==> Start stack"
docker compose -f docker-compose.yml -f docker-compose.hf.override.yml up -d --build

echo "==> Create systemd unit (auto-restart)"
sudo tee /etc/systemd/system/ross-llm.service >/dev/null <<EOT
[Unit]
Description=Ross-LLM stack
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/docker compose -f docker-compose.yml -f docker-compose.hf.override.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.yml -f docker-compose.hf.override.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOT

sudo systemctl daemon-reload
sudo systemctl enable ross-llm.service
sudo systemctl restart ross-llm.service

echo "==> Done. Check health:"
curl -sf http://localhost:8000/health && echo
EOF

echo "✅ Server deployment complete. Try: curl -sS http://${SERVER_HOST}:8000/health"
