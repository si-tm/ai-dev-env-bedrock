# ============================================================
# AI Development Environment — Dockerfile
# Base: Ubuntu 22.04
# Includes: code-server, Claude Code CLI, AWS CLI, Node.js 20,
#           Git, Docker CLI, Bedrock connection settings
# ============================================================

FROM ubuntu:22.04

ARG NODE_VERSION=20
ARG CODE_SERVER_VERSION=4.23.1
ARG DEBIAN_FRONTEND=noninteractive

# ── System packages ─────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo \
    jq \
    vim \
    htop \
    tmux \
    openssh-client \
    build-essential \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# ── Docker CLI (daemon runs on host) ────────────────────────
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) \
    signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends docker-ce-cli \
  && rm -rf /var/lib/apt/lists/*

# ── Node.js 20 (via NodeSource) ──────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
  && apt-get install -y nodejs \
  && npm install -g npm@latest \
  && rm -rf /var/lib/apt/lists/*

# ── AWS CLI v2 ───────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
  && if [ "$ARCH" = "amd64" ]; then AWS_ARCH="x86_64"; else AWS_ARCH="aarch64"; fi \
  && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" \
    -o /tmp/awscliv2.zip \
  && unzip -q /tmp/awscliv2.zip -d /tmp \
  && /tmp/aws/install \
  && rm -rf /tmp/awscliv2.zip /tmp/aws

# ── code-server (browser VSCode) ────────────────────────────
RUN curl -fsSL "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server_${CODE_SERVER_VERSION}_amd64.deb" \
    -o /tmp/code-server.deb \
  && dpkg -i /tmp/code-server.deb \
  && rm /tmp/code-server.deb

# ── Claude Code CLI ──────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code

# ── Developer user ───────────────────────────────────────────
RUN useradd -m -s /bin/bash -G sudo developer \
  && echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER developer
WORKDIR /home/developer

# ── code-server config ───────────────────────────────────────
RUN mkdir -p /home/developer/.config/code-server
# context=リポジトリルート(..) なので docker/ プレフィックスが必要
COPY --chown=developer:developer docker/config/code-server-config.yaml \
    /home/developer/.config/code-server/config.yaml

# ── Shell helpers ────────────────────────────────────────────
RUN echo '\n# ── AI Dev Env aliases ──────────────────────────\n\
alias ll="ls -alF"\n\
alias claude-status="aws bedrock list-foundation-models --region ap-northeast-1 --query '\''summaryList[?contains(modelId,`claude`)].modelId'\'' --output table"\n\
alias workspace="cd /home/developer/workspace"\n\
\n\
# AWS region default\n\
export AWS_DEFAULT_REGION=ap-northeast-1\n\
export AWS_REGION=ap-northeast-1\n' >> /home/developer/.bashrc

# ── Workspace dir ────────────────────────────────────────────
RUN mkdir -p /home/developer/workspace

EXPOSE 8080

# ── Entrypoint ───────────────────────────────────────────────
# context=リポジトリルート(..) なので scripts/ をそのまま参照できる
COPY --chown=developer:developer scripts/start.sh /usr/local/bin/start.sh
RUN sudo chmod +x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]
