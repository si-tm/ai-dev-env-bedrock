# ============================================================
# terraform/main.tf
# EC2 AI Development Environment
# IMDSv2 enabled, IAM Role for Bedrock
# ============================================================

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: remote state (uncomment to use)
  # backend "s3" {
  #   bucket = "your-tfstate-bucket"
  #   key    = "ai-dev-env/terraform.tfstate"
  #   region = "ap-northeast-1"
  # }
}

provider "aws" {
  region = var.aws_region
}

# ── Data sources ─────────────────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ── VPC & Networking ─────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(var.common_tags, { Name = "${var.project_name}-vpc" })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = merge(var.common_tags, { Name = "${var.project_name}-subnet-public" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.common_tags, { Name = "${var.project_name}-igw" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(var.common_tags, { Name = "${var.project_name}-rt-public" })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ── Security Group ───────────────────────────────────────────
resource "aws_security_group" "ai_dev" {
  name        = "${var.project_name}-sg"
  description = "AI Dev Env: SSH + code-server"
  vpc_id      = aws_vpc.main.id

  # SSH — restrict to your IP
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # code-server — restrict to your IP
  ingress {
    description = "code-server"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # HTTPS (optional, when nginx profile enabled)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-sg" })
}

# ── IAM Role for EC2 (Bedrock access) ────────────────────────
resource "aws_iam_role" "ec2_bedrock" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_policy" "bedrock_access" {
  name        = "${var.project_name}-bedrock-policy"
  description = "Minimum Bedrock permissions for Claude Sonnet"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-sonnet-4-5*",
          "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-5*",
          "arn:aws:bedrock:us-west-2::foundation-model/anthropic.claude-sonnet-4-5*"
        ]
      },
      {
        Sid    = "SSMSessionManager"
        Effect = "Allow"
        Action = [
          "ssm:StartSession",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ec2messages:GetMessages"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bedrock" {
  role       = aws_iam_role.ec2_bedrock.name
  policy_arn = aws_iam_policy.bedrock_access.arn
}

# SSM managed instance core (for Session Manager)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_bedrock.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2_bedrock.name
}

# ── Key Pair ─────────────────────────────────────────────────
resource "aws_key_pair" "dev" {
  count      = var.public_key_path != "" ? 1 : 0
  key_name   = "${var.project_name}-key"
  public_key = file(var.public_key_path)
  tags       = var.common_tags
}

# ── EBS root volume (encrypted) ──────────────────────────────
# ── EC2 Instance ─────────────────────────────────────────────
resource "aws_instance" "ai_dev" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ai_dev.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.public_key_path != "" ? aws_key_pair.dev[0].key_name : null

  # IMDSv2 (required)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"   # IMDSv2 — token required
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
    tags                  = merge(var.common_tags, { Name = "${var.project_name}-root" })
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    project_name         = var.project_name
    aws_region           = var.aws_region
    code_server_password = var.code_server_password
  }))

  tags = merge(var.common_tags, { Name = var.project_name })

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# ── Elastic IP ───────────────────────────────────────────────
resource "aws_eip" "ai_dev" {
  instance = aws_instance.ai_dev.id
  domain   = "vpc"
  tags     = merge(var.common_tags, { Name = "${var.project_name}-eip" })
}
