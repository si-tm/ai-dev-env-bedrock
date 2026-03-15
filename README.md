# 🤖 ai-dev-env-bedrock

> **5分でAI開発環境を構築する** — EC2 + code-server + Claude Code + Amazon Bedrock

[![CI](https://github.com/YOUR_ORG/ai-dev-env-bedrock/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_ORG/ai-dev-env-bedrock/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 📋 目次

1. [環境概要](#-環境概要)
2. [アーキテクチャ](#-アーキテクチャ)
3. [5分セットアップ](#-5分セットアップ)
4. [Bedrock設定](#-bedrock設定)
5. [Claude Code使い方](#-claude-code-使い方)
6. [開発者体験の改善](#-開発者体験の改善)
7. [セキュリティ設定](#-セキュリティ設定)
8. [コスト最適化](#-コスト最適化)
9. [将来拡張](#-将来拡張-rag--agents)
10. [トラブルシュート](#-トラブルシュート)

---

## 🌟 環境概要

| コンポーネント | バージョン | 用途 |
|---|---|---|
| Ubuntu | 22.04 LTS | ベースOS |
| code-server | 4.23.1 | ブラウザ版VSCode |
| Claude Code CLI | latest | AI駆動コーディング |
| AWS CLI | v2 | AWSリソース操作 |
| Amazon Bedrock | - | Claude Sonnet APIバックエンド |
| Node.js | 20 LTS | ランタイム |
| Docker | latest | コンテナ実行環境 |
| Terraform | ≥1.6 | インフラ as Code |

### 対応デプロイ方式

| 方式 | コマンド | 用途 |
|---|---|---|
| **Docker** | `docker compose up -d` | ローカル / 既存EC2 |
| **Terraform** | `terraform apply` | 新規EC2フルセット |

---

## 🏗️ アーキテクチャ

```
                        ┌─────────────────────────────────────┐
                        │           Your Browser               │
                        └────────────┬────────────────────────┘
                                     │ HTTPS :443 / HTTP :8080
                        ┌────────────▼────────────────────────┐
                        │         EC2 (t3.medium)              │
                        │         Ubuntu 22.04                 │
                        │                                      │
                        │  ┌──────────────────────────────┐   │
                        │  │   code-server :8080          │   │
                        │  │   (Browser VSCode)           │   │
                        │  └──────────┬───────────────────┘   │
                        │             │                        │
                        │  ┌──────────▼───────────────────┐   │
                        │  │   Claude Code CLI            │   │
                        │  │   CLAUDE_CODE_USE_BEDROCK=1  │   │
                        │  └──────────┬───────────────────┘   │
                        │             │                        │
                        │  ┌──────────▼───────────────────┐   │
                        │  │   AWS CLI / SDK              │   │
                        │  │   IAM Role (no credentials)  │   │
                        │  └──────────┬───────────────────┘   │
                        └────────────┼────────────────────────┘
                                     │ IMDSv2 → IAM Role
                                     │ VPC → Internet
                        ┌────────────▼────────────────────────┐
                        │      Amazon Bedrock                  │
                        │  claude-sonnet-4-5 (ap-northeast-1)  │
                        └─────────────────────────────────────┘

  Security:
  ・IAM Role (最小権限: Bedrock InvokeModel のみ)
  ・IMDSv2 (HTTPトークン必須)
  ・Security Group (SSH/8080 を自IP制限)
  ・EBS暗号化
  ・SSM Session Manager (SSH不要オプション)
```

---

## ⚡ 5分セットアップ

### 前提条件

```bash
# 必要なツール
aws --version        # AWS CLI v2
terraform --version  # >= 1.6
docker --version     # >= 24.0
```

### Step 1 — リポジトリ取得

```bash
git clone https://github.com/YOUR_ORG/ai-dev-env-bedrock.git
cd ai-dev-env-bedrock
```

### Step 2 — 初期セットアップ（自動）

```bash
bash scripts/setup.sh
```

このスクリプトが自動で行うこと：
- AWS認証情報の確認
- Bedrockモデルアクセスの確認
- `docker/.env` の生成（ランダムパスワード付き）
- `terraform/terraform.tfvars` の生成（あなたのIPを自動検出）

### Step 3a — Docker で起動（既存EC2 / ローカル）

```bash
cd docker
docker compose up -d

# ログ確認
docker compose logs -f ai-dev
```

ブラウザで `http://localhost:8080` を開き、`.env` のパスワードでログイン。

### Step 3b — Terraform で新規EC2構築

```bash
cd terraform

# 初期化
terraform init

# 確認
terraform plan

# 構築（約3〜5分）
terraform apply
```

完了後、outputに表示されるURLでアクセス：

```
Outputs:
  code_server_url = "http://X.X.X.X:8080"
  ssh_command     = "ssh -i ~/.ssh/id_rsa ubuntu@X.X.X.X"
  ssm_command     = "aws ssm start-session --target i-xxxxxxxx --region ap-northeast-1"
```

### Step 4 — 動作確認

code-serverのターミナルで：

```bash
# AWS接続確認
aws sts get-caller-identity

# Bedrock確認
aws bedrock list-foundation-models \
  --region ap-northeast-1 \
  --query "summaryList[?contains(modelId,\`claude\`)].modelId" \
  --output table

# Claude Code起動
claude
```

---

## 🔑 Bedrock設定

### モデルアクセスの有効化（初回のみ・コンソール操作）

1. AWSコンソール → **Amazon Bedrock** → **モデルアクセス**
2. リージョン: `ap-northeast-1` (東京)
3. **「Anthropic Claude Sonnet」** にチェック → アクセスをリクエスト
4. 承認は即時〜数分

> **Tip:** Cross-region inferenceを使うと `us.anthropic.claude-sonnet-4-5` でUS東西リージョンにフォールバックできます。

### IAM Roleの権限（Terraform自動作成）

```json
{
  "Effect": "Allow",
  "Action": [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream",
    "bedrock:ListFoundationModels"
  ],
  "Resource": [
    "arn:aws:bedrock:ap-northeast-1::foundation-model/anthropic.claude-sonnet-4-5*"
  ]
}
```

### 環境変数（自動設定済み）

```bash
export AWS_DEFAULT_REGION=ap-northeast-1
export CLAUDE_CODE_USE_BEDROCK=1
export ANTHROPIC_MODEL=us.anthropic.claude-sonnet-4-5
```

### SDK からBedrockを呼ぶサンプル

```python
import boto3, json

bedrock = boto3.client("bedrock-runtime", region_name="ap-northeast-1")

response = bedrock.invoke_model(
    modelId="anthropic.claude-sonnet-4-5-20251101",
    body=json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1024,
        "messages": [{"role": "user", "content": "Hello, Claude!"}]
    })
)
print(json.loads(response["body"].read())["content"][0]["text"])
```

---

## 🤖 Claude Code 使い方

### 基本操作

```bash
# プロジェクトディレクトリで起動
cd ~/workspace/my-project
claude

# 一発コマンド
claude "このディレクトリのコードをレビューして"
claude "バグを修正して: TypeError: Cannot read properties of undefined"
claude "テストを書いて"
```

### プロジェクト設定（`.claude/settings.json`）

初期構築時に自動生成されます：

```json
{
  "provider": "bedrock",
  "model": "us.anthropic.claude-sonnet-4-5",
  "region": "ap-northeast-1"
}
```

### 推奨ワークフロー

```bash
# 1. 新機能開発
claude "ユーザー認証機能をJWT + Expressで実装して"

# 2. コードレビュー
claude "このPRの差分をレビューして改善点を指摘して"
git diff HEAD~1 | claude "このdiffをレビューして"

# 3. テスト生成
claude "src/auth.ts のユニットテストをJestで書いて"

# 4. ドキュメント生成
claude "このAPIのOpenAPI仕様書を生成して"

# 5. リファクタリング
claude "このファイルをSOLID原則に従ってリファクタリングして"
```

### CLAUDE.md (プロジェクト固有の指示)

プロジェクトルートに `CLAUDE.md` を置くと、Claude Codeが常に参照します：

```markdown
# Project: my-app

## Stack
- Runtime: Node.js 20 / TypeScript
- Framework: Express 5
- DB: PostgreSQL 16 (via Prisma)
- Test: Vitest

## Rules
- コミットメッセージはConventional Commits形式
- すべての関数にJSDocコメントを付ける
- エラーハンドリングは Result型 パターンを使う
```

---

## 🛠️ 開発者体験の改善

### VSCode拡張（code-server で自動インストール推奨）

code-serverのターミナルで：

```bash
# 推奨拡張一括インストール
code-server --install-extension ms-python.python
code-server --install-extension dbaeumer.vscode-eslint
code-server --install-extension esbenp.prettier-vscode
code-server --install-extension eamodio.gitlens
code-server --install-extension ms-azuretools.vscode-docker
code-server --install-extension hashicorp.terraform
code-server --install-extension amazonwebservices.aws-toolkit-vscode
```

### ターミナルエイリアス（自動設定済み）

```bash
alias ll='ls -alF'
alias workspace='cd ~/workspace'
alias claude-check='aws bedrock list-foundation-models ...'  # Bedrock疎通確認
```

### Git設定

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global core.editor "code-server --wait"
git config --global init.defaultBranch main
```

### tmux セッション管理

```bash
# 永続セッション（SSH切断後も維持）
tmux new -s dev

# 再接続
tmux attach -t dev
```

---

## 🔒 セキュリティ設定

### IAM Role（最小権限）

- Terraform が自動作成
- EC2インスタンスプロファイルとして紐付け
- **アクセスキー不要**（IMDSv2経由で自動取得）

### IMDSv2（トークン必須）

```bash
# IMDSv2でトークン取得（EC2内から）
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# メタデータ取得
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id
```

### Security Group

デフォルトで `allowed_cidr_blocks` をあなたのIPに制限：

```hcl
# terraform.tfvars
allowed_cidr_blocks = ["YOUR_IP/32"]  # setup.sh が自動設定
```

### HTTPS（nginxプロファイル）

自己署名証明書の生成：

```bash
mkdir -p docker/nginx/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout docker/nginx/certs/server.key \
  -out docker/nginx/certs/server.crt \
  -subj "/CN=ai-dev-env"

# HTTPS付きで起動
docker compose --profile https up -d
```

本番環境ではLet's Encrypt（Certbot）の使用を推奨。

### SSM Session Manager（SSH不要）

```bash
# SSHポート(22)を開けずに接続可能
aws ssm start-session \
  --target $(terraform output -raw instance_id) \
  --region ap-northeast-1
```

---

## 💰 コスト最適化

### インスタンスタイプ別コスト目安（東京リージョン）

| インスタンス | vCPU | RAM | 月額目安 | 推奨用途 |
|---|---|---|---|---|
| t3.small | 2 | 2GB | ~$17 | 軽作業・検証 |
| **t3.medium** | 2 | 4GB | ~$34 | **デフォルト推奨** |
| t3.large | 2 | 8GB | ~$67 | 重い開発作業 |
| m6i.xlarge | 4 | 16GB | ~$180 | 本格AI開発 |

### 停止スクリプト（夜間自動停止）

```bash
# EC2を停止（EIPは保持される）
aws ec2 stop-instances \
  --instance-ids $(terraform output -raw instance_id) \
  --region ap-northeast-1

# 再起動
aws ec2 start-instances \
  --instance-ids $(terraform output -raw instance_id) \
  --region ap-northeast-1
```

EventBridgeルールで夜間自動停止も可能（Terraform拡張例は[将来拡張](#-将来拡張-rag--agents)参照）。

### Bedrock料金（Claude Sonnet 4.5 参考）

- Input: $3.00 / 1M tokens
- Output: $15.00 / 1M tokens
- Claude Code 1日の目安: $1〜$5（使用量により大きく変動）

**コスト削減のヒント:**
- `ANTHROPIC_MODEL=us.anthropic.claude-haiku-4-5` に切り替えると約20分の1
- `max_tokens` を必要最小限に設定

---

## 🚀 将来拡張 (RAG / Agents)

### RAG構成（Amazon Bedrock Knowledge Bases）

```python
# Knowledge BaseをBedrockで作成後
import boto3

bedrock_agent = boto3.client("bedrock-agent-runtime", region_name="ap-northeast-1")

response = bedrock_agent.retrieve_and_generate(
    input={"text": "社内ドキュメントから〇〇について教えて"},
    retrieveAndGenerateConfiguration={
        "type": "KNOWLEDGE_BASE",
        "knowledgeBaseConfiguration": {
            "knowledgeBaseId": "YOUR_KB_ID",
            "modelArn": "arn:aws:bedrock:ap-northeast-1::foundation-model/anthropic.claude-sonnet-4-5-20251101"
        }
    }
)
```

Terraform拡張例: `terraform/modules/rag/` ディレクトリを追加してKnowledge Base / S3 / OpenSearch Serverlessを構築。

### Bedrock Agents（自律エージェント）

```python
# Action Groupを定義してエージェントを自律実行
bedrock_agent.invoke_agent(
    agentId="YOUR_AGENT_ID",
    agentAliasId="TSTALIASID",
    sessionId="session-001",
    inputText="GitHubのIssueを確認してPRを作成して"
)
```

### その他拡張アイデア

| 機能 | 実装方法 |
|---|---|
| 夜間自動停止 | EventBridge + Lambda |
| 複数ユーザー | ECS Fargate on ALB |
| GPU対応 | g4dn.xlarge + CUDA Docker image |
| CI/CD連携 | GitHub Actions self-hosted runner |
| 監視 | CloudWatch + Grafana |

---

## 🔧 トラブルシュート

### code-serverに接続できない

```bash
# EC2上でサービス状態確認
sudo systemctl status code-server

# ログ確認
sudo journalctl -u code-server -n 50 --no-pager

# ポート確認
ss -tlnp | grep 8080

# 再起動
sudo systemctl restart code-server
```

### Bedrock接続エラー

```bash
# IAM Roleの確認 (IMDSv2)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/info

# 認証確認
aws sts get-caller-identity

# Bedrockテスト
aws bedrock list-foundation-models --region ap-northeast-1
```

よくあるエラーと対処：

| エラー | 原因 | 対処 |
|---|---|---|
| `AccessDeniedException` | IAM権限不足 | BedrockポリシーをRoleにアタッチ |
| `ValidationException: model not found` | モデルアクセス未申請 | コンソールでモデルアクセスを有効化 |
| `Could not connect to IMDS` | IMDSv2トークン未取得 | `http_tokens = "required"` を確認 |

### Claude Codeが起動しない

```bash
# バージョン確認
claude --version

# 再インストール
npm install -g @anthropic-ai/claude-code

# 環境変数確認
echo $CLAUDE_CODE_USE_BEDROCK
echo $ANTHROPIC_MODEL
echo $AWS_DEFAULT_REGION
```

### Dockerビルドエラー

```bash
# キャッシュクリア
docker compose build --no-cache

# 詳細ログ
DOCKER_BUILDKIT=1 docker compose build --progress=plain
```

### Terraform destroyでEIPが残る

```bash
# 手動でEIPを解放
aws ec2 describe-addresses --query 'Addresses[*].[AllocationId,PublicIp]' --output table
aws ec2 release-address --allocation-id eipalloc-xxxxxxxxx
```

---

## 📁 リポジトリ構成

```
ai-dev-env-bedrock/
├── .github/
│   └── workflows/
│       └── ci.yml              # GitHub Actions CI
├── docker/
│   ├── config/
│   │   └── code-server-config.yaml
│   ├── nginx/
│   │   └── nginx.conf          # HTTPS reverse proxy
│   ├── Dockerfile              # Ubuntu 22.04 ベース
│   ├── docker-compose.yml
│   └── .env.example
├── scripts/
│   ├── setup.sh                # 初期セットアップ（.env / tfvars生成）
│   └── start.sh                # Dockerエントリポイント
├── terraform/
│   ├── main.tf                 # VPC / EC2 / IAM / SG / EIP
│   ├── variables.tf
│   ├── outputs.tf
│   ├── user_data.sh.tpl        # EC2初期設定（IMDSv2対応）
│   └── terraform.tfvars.example
├── .gitignore
└── README.md
```

---

## 📄 ライセンス

MIT License — see [LICENSE](LICENSE)

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'feat: add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

---

<p align="center">Built with ❤️ using Amazon Bedrock + Claude Code</p>
