# AWS Architecture Diagram
**Account:** 573576813930 | **Region:** ap-northeast-1 (Tokyo)

## Mermaid Diagram

```mermaid
graph TB
    subgraph Internet["Internet"]
        USER["User / Browser"]
    end

    IGW["Internet Gateway"]

    subgraph AWS["AWS Account: 573576813930"]
        subgraph REGION["Region: ap-northeast-1 (Tokyo)"]

            subgraph VPC["VPC (10.0.0.0/16)"]
                subgraph SUBNET["Public Subnet: 10.0.0.0/20 (ap-northeast-1a)"]
                    SG["Security Group: ai-dev-env-sg\n:22 SSH\n:8080 code-server"]

                    subgraph EC2["EC2: i-0905a9a2593c30516\ntype: t3.medium\nAMI: Amazon Linux 2023\nPrivate IP: 10.0.0.33"]
                        CODESERVER["code-server :8080\n(VS Code in Browser)"]
                        SSH["SSH :22"]
                        DOCKER["Docker"]
                        CLAUDE["Claude Code CLI\n(@anthropic-ai/claude-code)"]
                        SSM_AGENT["Amazon SSM Agent"]

                        subgraph MCP["MCP Servers (stdio)"]
                            MCP1["awslabs.core-mcp-server"]
                            MCP2["awslabs.cdk-mcp-server"]
                            MCP3["awslabs.cfn-mcp-server"]
                            MCP4["awslabs.aws-pricing-mcp-server"]
                        end
                    end
                end
            end

            EIP["Elastic IP: 54.64.5.84"]

            subgraph IAM["IAM"]
                PROFILE["Instance Profile\nai-dev-env-instance-profile"]
                ROLE["IAM Role\nai-dev-env-ec2-role"]
                POLICY["Permissions:\nbedrock:ListFoundationModels\nbedrock:ListInferenceProfiles\nbedrock:InvokeModel*"]
            end

            subgraph BEDROCK["Amazon Bedrock"]
                subgraph MODELS["Foundation Models (Claude)"]
                    M1["claude-sonnet-4-6 (ACTIVE)"]
                    M2["claude-sonnet-4-5 (ACTIVE)"]
                    M3["claude-haiku-4-5 (ACTIVE)"]
                    M4["claude-opus-4-6 (ACTIVE)"]
                    M5["claude-3-5-sonnet (ACTIVE)"]
                end
                XREGION["Cross-region Inference\nAPAC Profile\n(ap-northeast-1/2,\nap-southeast-1/2,\nap-south-1)"]
            end
        end
    end

    USER -->|"HTTPS :8080"| IGW
    USER -->|"SSH :22"| IGW
    IGW --> EIP
    EIP --> SG
    SG --> EC2

    PROFILE --> ROLE
    ROLE --> POLICY
    EC2 -.->|"Instance Profile"| PROFILE

    CLAUDE -->|"bedrock:InvokeModel\n(CLAUDE_CODE_USE_BEDROCK=1)"| BEDROCK
    CLAUDE --- MCP

    MCP3 -->|"CloudFormation API"| AWS
    MCP4 -->|"Pricing API"| AWS
    MCP2 -->|"CDK guidance"| AWS

    style AWS fill:#FF9900,stroke:#FF6600,color:#000
    style REGION fill:#FFE4B5,stroke:#FF9900,color:#000
    style VPC fill:#E8F4FD,stroke:#007BFF,color:#000
    style SUBNET fill:#D4EDDA,stroke:#28A745,color:#000
    style EC2 fill:#fff3cd,stroke:#ffc107,color:#000
    style BEDROCK fill:#E8D5F5,stroke:#9B59B6,color:#000
    style IAM fill:#FDEBD0,stroke:#E67E22,color:#000
    style MCP fill:#D5EAF5,stroke:#2980B9,color:#000
    style Internet fill:#F0F0F0,stroke:#999,color:#000
```

## Architecture Summary

| Component | Detail |
|-----------|--------|
| **Account ID** | 573576813930 |
| **Region** | ap-northeast-1 (Tokyo) |
| **AZ** | ap-northeast-1a |
| **VPC Subnet** | 10.0.0.0/20 |
| **EC2 Instance** | i-0905a9a2593c30516 (t3.medium) |
| **OS** | Amazon Linux 2023 |
| **Private IP** | 10.0.0.33 |
| **Public IP (EIP)** | 54.64.5.84 |
| **Security Group** | ai-dev-env-sg (TCP:22, TCP:8080) |
| **IAM Role** | ai-dev-env-ec2-role |
| **Instance Profile** | ai-dev-env-instance-profile |

### EC2 Software Stack
| Software | Version/Detail |
|----------|---------------|
| Amazon Linux 2023 | OS |
| code-server | VS Code in browser (:8080) |
| Claude Code CLI | @anthropic-ai/claude-code |
| Node.js 20 | Runtime |
| Python 3 | Runtime |
| Docker | Container runtime |
| AWS CLI v2 | AWS operations |
| Amazon SSM Agent | Systems Manager |

### MCP Servers (Model Context Protocol)
| Server | Purpose |
|--------|---------|
| awslabs.core-mcp-server | AWS core guidance |
| awslabs.cdk-mcp-server | CDK construct guidance |
| awslabs.cfn-mcp-server | CloudFormation resource CRUD |
| awslabs.aws-pricing-mcp-server | AWS pricing analysis |

### Bedrock Models Available
| Model | Status |
|-------|--------|
| anthropic.claude-sonnet-4-6 | ACTIVE |
| anthropic.claude-sonnet-4-5 | ACTIVE |
| anthropic.claude-haiku-4-5 | ACTIVE |
| anthropic.claude-opus-4-6 | ACTIVE |
| anthropic.claude-3-5-sonnet-20241022-v2:0 | ACTIVE |

### Environment Variables (code-server / Claude Code)
```
CLAUDE_CODE_USE_BEDROCK=1
ANTHROPIC_MODEL=us.anthropic.claude-sonnet-4-5
AWS_DEFAULT_REGION=ap-northeast-1
AWS_REGION=ap-northeast-1
```
