#!/bin/bash
# ============================================================
# manual-setup.sh
# 新規EC2 (Amazon Linux 2023) 手動セットアップスクリプト
# これまでの試行錯誤を踏まえた確実版
#
# 実行方法:
#   sudo bash manual-setup.sh
# ============================================================
set -euo pipefail
exec > >(tee /var/log/manual-setup.log | logger -t manual-setup) 2>&1

echo "===== Setup Start: $(date) ====="

# ── 1. curl競合を解消してからアップデート ──────────────────
echo "[1/9] System update..."
dnf install -y --allowerasing curl
dnf update -y

# ── 2. 基本パッケージ ──────────────────────────────────────
echo "[2/9] Installing core packages..."
dnf install -y \
  wget git unzip jq vim htop tmux \
  gcc gcc-c++ make \
  python3 python3-pip

# ── 3. Docker ──────────────────────────────────────────────
echo "[3/9] Installing Docker..."
dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# ── 4. Node.js 20 ──────────────────────────────────────────
echo "[4/9] Installing Node.js 20..."
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs
npm install -g npm@latest

# ── 5. AWS CLI v2 ──────────────────────────────────────────
echo "[5/9] Installing AWS CLI v2..."
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
  -o /tmp/awscli.zip
unzip -q /tmp/awscli.zip -d /tmp
/tmp/aws/install --update
rm -rf /tmp/awscli.zip /tmp/aws

# ── 6. code-server ─────────────────────────────────────────
echo "[6/9] Installing code-server..."
curl -fsSL https://code-server.dev/install.sh | sh

# ── 7. Claude Code CLI ─────────────────────────────────────
echo "[7/9] Installing Claude Code CLI..."
npm install -g @anthropic-ai/claude-code

# ── 8. code-server設定 ─────────────────────────────────────
echo "[8/9] Configuring code-server..."

# ワークスペースとconfigディレクトリ作成
mkdir -p /home/ec2-user/workspace
mkdir -p /home/ec2-user/.config/code-server

# パスワード生成
CS_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)

cat > /home/ec2-user/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: ${CS_PASSWORD}
cert: false
EOF

chown -R ec2-user:ec2-user /home/ec2-user/.config
chown -R ec2-user:ec2-user /home/ec2-user/workspace

# code-serverのパスを取得
CODE_SERVER_PATH=$(which code-server)
echo "code-server path: ${CODE_SERVER_PATH}"

# systemdサービス作成
cat > /etc/systemd/system/code-server.service <<EOF
[Unit]
Description=code-server (Browser VSCode)
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/workspace
Environment=AWS_DEFAULT_REGION=ap-northeast-1
Environment=AWS_REGION=ap-northeast-1
Environment=CLAUDE_CODE_USE_BEDROCK=1
Environment=ANTHROPIC_MODEL=jp.anthropic.claude-sonnet-4-6
ExecStart=${CODE_SERVER_PATH} --config /home/ec2-user/.config/code-server/config.yaml /home/ec2-user/workspace
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable code-server
systemctl start code-server

# ── 9. 環境変数とClaude Code設定 ───────────────────────────
echo "[9/9] Configuring environment..."

# ec2-userの.bashrcに追記
cat >> /home/ec2-user/.bashrc <<'BASHEOF'

# ── AI Dev Env ──────────────────────────────────────────
export AWS_DEFAULT_REGION=ap-northeast-1
export AWS_REGION=ap-northeast-1
export CLAUDE_CODE_USE_BEDROCK=1
export ANTHROPIC_MODEL=jp.anthropic.claude-sonnet-4-6

alias ll='ls -alF'
alias workspace='cd ~/workspace'
alias claude-check='aws bedrock list-inference-profiles \
  --region ap-northeast-1 \
  --query "inferenceProfileSummaries[?contains(inferenceProfileId,\`sonnet\`)].inferenceProfileId" \
  --output text'
BASHEOF

# Claude Code設定ファイル
cat > /home/ec2-user/.claude.json <<'EOF'
{
  "provider": "bedrock",
  "model": "jp.anthropic.claude-sonnet-4-6",
  "region": "ap-northeast-1"
}
EOF

# Claudeプロジェクト設定
mkdir -p /home/ec2-user/workspace/.claude
cat > /home/ec2-user/workspace/.claude/settings.json <<'EOF'
{
  "provider": "bedrock",
  "model": "jp.anthropic.claude-sonnet-4-6",
  "region": "ap-northeast-1"
}
EOF

chown -R ec2-user:ec2-user /home/ec2-user/.claude.json
chown -R ec2-user:ec2-user /home/ec2-user/workspace

# ── 完了確認 ───────────────────────────────────────────────
echo ""
echo "===== Setup Complete: $(date) ====="
echo ""
echo "【インストール済みツール】"
echo -n "  Node.js:      "; node --version
echo -n "  npm:          "; npm --version
echo -n "  AWS CLI:      "; aws --version
echo -n "  code-server:  "; code-server --version | head -1
echo -n "  Claude Code:  "; claude --version
echo -n "  Docker:       "; docker --version
echo ""
echo "【code-server】"
echo "  status: $(systemctl is-active code-server)"
echo "  port:   $(ss -tlnp | grep 8080 || echo 'not listening')"
echo ""
echo "【code-serverパスワード】"
echo "  password: ${CS_PASSWORD}"
echo "  ※ このパスワードを控えてください"
echo ""
echo "【次のステップ】"

# IMDSv2でパブリックIPを取得
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null || echo "")
if [ -n "$TOKEN" ]; then
  PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "取得失敗")
  echo "  ブラウザで http://${PUBLIC_IP}:8080 を開く"
fi

echo ""
echo "【動作確認コマンド (ec2-userで実行)】"
echo "  source ~/.bashrc"
echo "  claude \"Bedrockに接続できていますか？\""
