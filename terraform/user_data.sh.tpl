#!/bin/bash
# ============================================================
# terraform/user_data.sh.tpl
# EC2 initial setup — runs once on first boot (IMDSv2)
# ============================================================
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "===== AI Dev Env Setup Start: $(date) ====="

# ── IMDSv2 token helper ──────────────────────────────────────
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)
echo "Instance ID: $INSTANCE_ID"

# ── System update ────────────────────────────────────────────
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# ── Core packages ────────────────────────────────────────────
apt-get install -y \
  curl wget git unzip jq vim htop tmux \
  build-essential ca-certificates gnupg lsb-release \
  python3 python3-pip \
  awscli

# ── Docker ───────────────────────────────────────────────────
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# ── Node.js 20 ───────────────────────────────────────────────
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
npm install -g npm@latest

# ── AWS CLI v2 (replace v1 from apt) ─────────────────────────
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscli.zip
unzip -q /tmp/awscli.zip -d /tmp
/tmp/aws/install --update
rm -rf /tmp/awscli.zip /tmp/aws

# ── code-server ──────────────────────────────────────────────
CODE_SERVER_VERSION="4.23.1"
curl -fsSL "https://github.com/coder/code-server/releases/download/v$CODE_SERVER_VERSION/code-server_$${CODE_SERVER_VERSION}_amd64.deb" \
  -o /tmp/code-server.deb
dpkg -i /tmp/code-server.deb
rm /tmp/code-server.deb

# ── Claude Code CLI ──────────────────────────────────────────
npm install -g @anthropic-ai/claude-code

# ── code-server config ───────────────────────────────────────
sudo -u ubuntu mkdir -p /home/ubuntu/.config/code-server
cat > /home/ubuntu/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: ${code_server_password}
cert: false
EOF
chown ubuntu:ubuntu /home/ubuntu/.config/code-server/config.yaml

# ── code-server systemd service ──────────────────────────────
cat > /etc/systemd/system/code-server.service <<EOF
[Unit]
Description=code-server (browser VSCode)
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/workspace
Environment=AWS_DEFAULT_REGION=${aws_region}
Environment=AWS_REGION=${aws_region}
Environment=CLAUDE_CODE_USE_BEDROCK=1
Environment=ANTHROPIC_MODEL=us.anthropic.claude-sonnet-4-5
ExecStart=/usr/bin/code-server --config /home/ubuntu/.config/code-server/config.yaml /home/ubuntu/workspace
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable code-server
systemctl start code-server

# ── SSM Agent (ensure latest) ────────────────────────────────
snap install amazon-ssm-agent --classic || true
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service || true

# ── Workspace & shell config ─────────────────────────────────
sudo -u ubuntu mkdir -p /home/ubuntu/workspace

cat >> /home/ubuntu/.bashrc <<'BASHEOF'

# ── AI Dev Env ──────────────────────────────────────────────
export AWS_DEFAULT_REGION=ap-northeast-1
export AWS_REGION=ap-northeast-1
export CLAUDE_CODE_USE_BEDROCK=1
export ANTHROPIC_MODEL=us.anthropic.claude-sonnet-4-5

alias ll='ls -alF'
alias workspace='cd ~/workspace'
alias claude-check='aws bedrock list-foundation-models \
  --region ap-northeast-1 \
  --query "summaryList[?contains(modelId,\`claude\`)].modelId" \
  --output table'
BASHEOF

# ── Claude Code project config ───────────────────────────────
sudo -u ubuntu mkdir -p /home/ubuntu/workspace/.claude
cat > /home/ubuntu/workspace/.claude/settings.json <<EOF
{
  "provider": "bedrock",
  "model": "us.anthropic.claude-sonnet-4-5",
  "region": "${aws_region}"
}
EOF
chown -R ubuntu:ubuntu /home/ubuntu/workspace

echo "===== Setup Complete: $(date) ====="
echo "code-server: http://$(curl -s -H 'X-aws-ec2-metadata-token: '$IMDS_TOKEN http://169.254.169.254/latest/meta-data/public-ipv4):8080"
