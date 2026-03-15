# ============================================================
# terraform/variables.tf
# ============================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name (used as resource name prefix)"
  type        = string
  default     = "ai-dev-env"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"   # 2vCPU / 4GB — sufficient for code-server + Claude Code
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "Public subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach SSH / code-server. IMPORTANT: restrict to your IP."
  type        = list(string)
  default     = ["0.0.0.0/0"]  # ← 本番では必ず自IPに絞ること
}

variable "public_key_path" {
  description = "Path to SSH public key file. Leave empty to skip key pair creation."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "code_server_password" {
  description = "Password for code-server UI"
  type        = string
  sensitive   = true
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "ai-dev-env"
    ManagedBy   = "terraform"
    Environment = "dev"
  }
}
