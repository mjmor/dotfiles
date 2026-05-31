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
RUN curl -fsSL https://astral.sh/uv/install.sh | sh && \
    mv /root/.local/bin/uv /usr/local/bin/uv && \
    mv /root/.local/bin/uvx /usr/local/bin/uvx 2>/dev/null || true

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

# ── nvm + Node.js LTS ─────────────────────────────────────────────────────────
# Installed system-wide to /opt/nvm (not in the bind mount) to avoid virtiofs
# permission issues. Symlinks in /usr/local/bin make node/npm/npx available
# to all users including cron.
ARG NVM_VERSION=v0.40.1
ENV NVM_DIR=/opt/nvm
RUN mkdir -p "${NVM_DIR}" && \
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" \
      | NVM_DIR="${NVM_DIR}" bash
RUN bash -c " \
    source ${NVM_DIR}/nvm.sh && \
    nvm install --lts && \
    nvm alias default node && \
    NODE_BIN=\$(nvm which default) && \
    ln -sf \${NODE_BIN}              /usr/local/bin/node && \
    ln -sf \$(dirname \${NODE_BIN})/npm  /usr/local/bin/npm && \
    ln -sf \$(dirname \${NODE_BIN})/npx  /usr/local/bin/npx"

# ── Claude Code ───────────────────────────────────────────────────────────────
# Installed as root; binary symlinked to /usr/local/bin/claude.
# Auth state (~/.claude/) is written at runtime to /home/agent (bind mount)
# by the agent user, keeping credentials out of the image.
RUN curl -fsSL https://claude.ai/install.sh | bash
RUN CLAUDE_BIN=$(find /root/.claude /root/.local -name "claude" -type f 2>/dev/null | head -1) && \
    [ -n "${CLAUDE_BIN}" ] && ln -sf "${CLAUDE_BIN}" /usr/local/bin/claude || \
    (echo "ERROR: claude binary not found after install" && exit 1)

# ── Agent user ────────────────────────────────────────────────────────────────
# GID is not specified — groupadd picks a free one automatically. We do NOT
# pass the Mac GID because macOS GIDs overlap with Ubuntu system GIDs, and
# installed packages can claim common GIDs like 1000. Only the UID is passed
# so files written by the container appear owned by the Mac user on the host.
RUN groupadd agent && \
    useradd --non-unique -m -u "${UID}" -g agent -s /bin/bash agent && \
    echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent && \
    chmod 0440 /etc/sudoers.d/agent

# ── Crontab ───────────────────────────────────────────────────────────────────
COPY cron/agent-cron /etc/cron.d/agent-cron
RUN chmod 0644 /etc/cron.d/agent-cron

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
