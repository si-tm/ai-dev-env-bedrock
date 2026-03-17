# 🤖 ai-dev-env-bedrock

> **5分でAI開発環境を構築する** — EC2 (Amazon Linux 2023) + code-server + Claude Code + Amazon Bedrock

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
| Amazon Linux | 2023 (最新) | ベースOS |
| code-server | 4.23.1 | ブラウザ版VSCode |
| Claude Code CLI | latest | AI駆動コーディング |
| AWS CLI | v2 | AWSリソース操作 |
| Amazon Bedrock | - | Claude Sonnet APIバックエンド |
| Node.js | 20 LTS | ランタイム |
| Docker | latest | コンテナ実行環境 |
| CloudFormation | - | インフラ as Code |

### 対応デプロイ方式

| 方式 | コマンド | 用途 |
|---|---|---|
| **CloudFormation** | `aws cloudformation deploy` | 新規EC2フルセット |
| **Docker** | `docker compose up -d` | ローカル / 既存EC2 |

---

## 🏗️ アーキテクチャ

```
                        ┌─────────────────────────────────────┐
                        │           Your Browser               │
                        └────────────┬────────────────────────┘
                                     │ HTTP :8080 / HTTPS :443
                        ┌────────────▼────────────────────────┐
                        │    EC2 (Amazon Linux 2023)           │
                        │    t3.medium / EBS gp3 暗号化        │
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
                        │  │   AWS CLI v2 / SDK           │   │
                        │  │   IAM Role (credentials不要)  │   │
                        │  └──────────┬───────────────────┘   │
                        └────────────┼────────────────────────┘
                                     │ IMDSv2 → IAM Role
                        ┌────────────▼────────────────────────┐
                        │      Amazon Bedrock                  │
                        │  claude-sonnet-4-5 (ap-northeast-1)  │
                        └─────────────────────────────────────┘

  Security:
  ・IAM Role (最小権限: Bedrock InvokeModel のみ)
  ・IMDSv2 (HttpTokens=required)
  ・Security Group (SSH/8080 を自IP制限)
  ・EBS暗号化 (gp3)
  ・SSM Session Manager (SSH不要オプション)
  ・CloudFormation管理 (ドリフト検出対応)
```

---

## ⚡ 5分セットアップ

### 前提条件

```bash
aws --version   # AWS CLI v2
docker --version
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

このスクリプトが自動で行うこと:
- AWS認証情報の確認
- Bedrockモデルアクセスの確認
- `docker/.env` の生成（ランダムパスワード付き）
- `cfn/parameters.json` の生成（あなたのIPを自動検出）

### Step 3a — CloudFormation で新規EC2構築（推奨）

```bash
aws cloudformation deploy \
  --template-file cfn/template.yaml \
  --stack-name ai-dev-env \
  --parameter-overrides file://cfn/parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1
```

完了後、Outputsを確認：

```bash
aws cloudformation describe-stacks \
  --stack-name ai-dev-env \
  --region ap-northeast-1 \
  --query "Stacks[0].Outputs" \
  --output table
```

```
# 出力例
CodeServerUrl  → http://X.X.X.X:8080
SsmCommand     → aws ssm start-session --target i-xxxxxxxx --region ap-northeast-1
SshCommand     → ssh -i ~/.ssh/YOUR_KEY.pem ec2-user@X.X.X.X
```

### Step 3b — Docker で起動（既存EC2 / ローカル）

```bash
cd docker
docker compose up -d

# ログ確認
docker compose logs -f ai-dev
```

ブラウザで `http://localhost:8080` を開き、`.env` のパスワードでログイン。

### Step 4 — 動作確認

code-serverのターミナルで：

```bash
# AWS接続確認
aws sts get-caller-identity

# Bedrock確認
aws bedrock list-foundation-models \
  --region ap-northeast-1 \
  --query "summaryList[?contains(modelId,'claude')].modelId" \
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

> **Tip:** Cross-region inferenceを使うと `us.anthropic.claude-sonnet-4-5` でUS東西にフォールバックできます。

### IAM Roleの権限（CloudFormation自動作成）

```yaml
# cfn/template.yaml で定義済み
- bedrock:InvokeModel
- bedrock:InvokeModelWithResponseStream
- bedrock:ListFoundationModels
- bedrock:GetFoundationModel
```

### 環境変数（EC2起動時に自動設定済み）

```bash
export AWS_DEFAULT_REGION=ap-northeast-1
export CLAUDE_CODE_USE_BEDROCK=1
export ANTHROPIC_MODEL=us.anthropic.claude-sonnet-4-5
```

---

## 🤖 Claude Code 使い方

### 基本操作

```bash
cd ~/workspace/my-project
claude

# 一発コマンド
claude "このディレクトリのコードをレビューして"
claude "バグを修正して"
claude "テストを書いて"
```

### プロジェクト設定（`.claude/settings.json`）

起動時に自動生成されます：

```json
{
  "provider": "bedrock",
  "model": "us.anthropic.claude-sonnet-4-5",
  "region": "ap-northeast-1"
}
```

### CLAUDE.md（プロジェクト固有の指示）

```markdown
# Project: my-app

## Stack
- Runtime: Node.js 20 / TypeScript
- Framework: Express 5
- DB: PostgreSQL 16 (via Prisma)

## Rules
- コミットはConventional Commits形式
- すべての関数にJSDocコメントを付ける
```

---

## 🛠️ 開発者体験の改善

### VSCode拡張のインストール

```bash
code-server --install-extension dbaeumer.vscode-eslint
code-server --install-extension esbenp.prettier-vscode
code-server --install-extension eamodio.gitlens
code-server --install-extension ms-azuretools.vscode-docker
code-server --install-extension hashicorp.terraform
code-server --install-extension amazonwebservices.aws-toolkit-vscode
```

### tmux セッション管理

```bash
tmux new -s dev    # 新規セッション
tmux attach -t dev # 再接続（SSH切断後も維持）
```

---

## 🔒 セキュリティ設定

### IMDSv2（トークン必須）

```bash
# EC2内からIMDSv2でトークン取得
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id
```

### Security Group

`AllowedCidr` パラメータで自動的にIPを制限。`setup.sh` が自IPを自動検出します。

変更が必要な場合：

```bash
aws cloudformation deploy \
  --template-file cfn/template.yaml \
  --stack-name ai-dev-env \
  --parameter-overrides AllowedCidr=NEW_IP/32 \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1
```

### SSM Session Manager（SSH不要）

```bash
# SSHポート(22)を開けずに接続可能
aws ssm start-session \
  --target $(aws cloudformation describe-stacks \
    --stack-name ai-dev-env \
    --query "Stacks[0].Outputs[?OutputKey=='InstanceId'].OutputValue" \
    --output text) \
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

### EC2の停止・起動

```bash
# インスタンスID取得
INSTANCE_ID=$(aws cloudformation describe-stacks \
  --stack-name ai-dev-env \
  --query "Stacks[0].Outputs[?OutputKey=='InstanceId'].OutputValue" \
  --output text)

# 停止（EIPは保持）
aws ec2 stop-instances --instance-ids $INSTANCE_ID --region ap-northeast-1

# 起動
aws ec2 start-instances --instance-ids $INSTANCE_ID --region ap-northeast-1
```

### スタック削除（全リソース削除）

```bash
aws cloudformation delete-stack \
  --stack-name ai-dev-env \
  --region ap-northeast-1
```

---

## 🚀 将来拡張 (RAG / Agents)

### RAG構成（Amazon Bedrock Knowledge Bases）

```python
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

### その他拡張アイデア

| 機能 | 実装方法 |
|---|---|
| 夜間自動停止 | EventBridge + Lambda (CFnで追加) |
| 複数ユーザー | ECS Fargate on ALB |
| 監視 | CloudWatch Dashboard + アラーム |
| CI/CD | GitHub Actions OIDC + CFn deploy |

---

## 🔧 トラブルシュート

### CloudFormationスタックのステータス確認

```bash
aws cloudformation describe-stacks \
  --stack-name ai-dev-env \
  --region ap-northeast-1 \
  --query "Stacks[0].StackStatus"

# イベント確認（エラー原因の特定）
aws cloudformation describe-stack-events \
  --stack-name ai-dev-env \
  --region ap-northeast-1 \
  --query "StackEvents[?ResourceStatus=='CREATE_FAILED']"
```

### code-serverに接続できない

```bash
# SSMでEC2に接続してから確認
aws ssm start-session --target INSTANCE_ID --region ap-northeast-1

# サービス状態確認
sudo systemctl status code-server

# ログ確認
sudo journalctl -u code-server -n 50 --no-pager

# 再起動
sudo systemctl restart code-server
```

### UserDataのログ確認

```bash
# EC2内で実行
sudo cat /var/log/user-data.log
```

### Bedrock接続エラー

```bash
# IAM Role確認 (IMDSv2)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/info

# Bedrockテスト
aws bedrock list-foundation-models --region ap-northeast-1
```

---

## 📁 リポジトリ構成

```
ai-dev-env-bedrock/
├── .github/
│   └── workflows/
│       └── ci.yml              # GitHub Actions CI (cfn-lint / docker-build / security)
├── cfn/
│   ├── template.yaml           # CloudFormation テンプレート
│   └── parameters.json.example # パラメータファイルのサンプル
├── docker/
│   ├── config/
│   │   └── code-server-config.yaml
│   ├── nginx/
│   │   └── nginx.conf          # HTTPS reverse proxy
│   ├── Dockerfile              # Ubuntu 22.04 ベース
│   ├── docker-compose.yml
│   └── .env.example
├── scripts/
│   ├── setup.sh                # 初期セットアップ（.env / parameters.json生成）
│   └── start.sh                # Dockerエントリポイント
├── .gitignore
└── README.md
```

---

## 📄 ライセンス

MIT License

---

<p align="center">Built with ❤️ using Amazon Bedrock + Claude Code</p>

https://nmpmsg-my.sharepoint.com/:f:/g/personal/azuma01_nmpmsg_onmicrosoft_com/IgBqCfs58Zm8To_wAo_DveXlAfUX4PGBnjx2RaW08EW_iKw?e=cFFbr8
