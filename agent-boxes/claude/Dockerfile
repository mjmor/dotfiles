ARG UID=1000

FROM ubuntu:24.04

ARG UID

ENV DEBIAN_FRONTEND=noninteractive

# ── System packages ───────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    cron \
    curl \
    git \
    gnupg \
    jq \
    openssh-client \
    python3 \
    python3-pip \
    ripgrep \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# ── yq (ARM64 binary) ─────────────────────────────────────────────────────────
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm64" \
    -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

# ── Go ────────────────────────────────────────────────────────────────────────
ARG GO_VERSION=1.23.4
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-arm64.tar.gz" \
    | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

# ── uv ────────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://astral.sh/uv/install.sh \
    | UV_INSTALL_DIR=/usr/local/bin sh

# ── gh CLI ────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=arm64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# ── kubectl (ARM64) ───────────────────────────────────────────────────────────
RUN curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl" \
    -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

# ── Tailscale ─────────────────────────────────────────────────────────────────
RUN curl -fsSL https://tailscale.com/install.sh | sh

# ── Agent user ────────────────────────────────────────────────────────────────
# Created before nvm so the install runs as this user, not root.
# GID is not specified — groupadd picks a free one. Only UID is passed from the
# Mac host so bind-mounted files are owned by the Mac user.
RUN groupadd agent && \
    useradd --non-unique -m -u "${UID}" -g agent -s /bin/bash agent && \
    echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent && \
    chmod 0440 /etc/sudoers.d/agent

# ── nvm + Node.js LTS + Claude Code ──────────────────────────────────────────
# Installed as the agent user into /opt/nvm so the agent owns the toolchain
# and it's accessible to all users. /etc/profile.d/nvm.sh sources nvm for
# every login shell (tailscale ssh, su -, etc.).
ARG NVM_VERSION=v0.40.1
ENV NVM_DIR=/opt/nvm
RUN mkdir -p "${NVM_DIR}" && chown agent:agent "${NVM_DIR}"

RUN su -s /bin/bash agent -c " \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh \
      | NVM_DIR=${NVM_DIR} bash && \
    source ${NVM_DIR}/nvm.sh && \
    nvm install --lts && \
    nvm alias default node && \
    npm install -g @anthropic-ai/claude-code"

# Stable symlinks in /usr/local/bin so all users and cron find the binaries
# without needing to source nvm first.
RUN bash -c " \
    source ${NVM_DIR}/nvm.sh && \
    NODE_BIN=\$(su -s /bin/bash agent -c 'source ${NVM_DIR}/nvm.sh && nvm which default') && \
    NODE_BIN_DIR=\$(dirname \${NODE_BIN}) && \
    ln -sf \${NODE_BIN}               /usr/local/bin/node && \
    ln -sf \${NODE_BIN_DIR}/npm       /usr/local/bin/npm && \
    ln -sf \${NODE_BIN_DIR}/npx       /usr/local/bin/npx && \
    ln -sf \${NODE_BIN_DIR}/claude    /usr/local/bin/claude"

# Source nvm for all login shells (tailscale ssh, su -, docker exec -it)
RUN printf 'export NVM_DIR=%s\n[ -s "${NVM_DIR}/nvm.sh" ] && source "${NVM_DIR}/nvm.sh"\n' \
    "${NVM_DIR}" > /etc/profile.d/nvm.sh && \
    chmod 644 /etc/profile.d/nvm.sh

# ── Crontab ───────────────────────────────────────────────────────────────────
COPY cron/agent-cron /etc/cron.d/agent-cron
RUN chmod 0644 /etc/cron.d/agent-cron

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
