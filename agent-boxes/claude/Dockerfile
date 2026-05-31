ARG UID=1000
ARG GID=1000

FROM ubuntu:24.04

ARG UID
ARG GID

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

# ── Agent user ────────────────────────────────────────────────────────────────
# GIDs like 20 (macOS staff) may already exist in Ubuntu (e.g. as dialout).
# Skip groupadd if the GID is taken; useradd -g accepts a numeric GID directly.
# --non-unique allows the UID if it happens to already exist in the base image.
RUN getent group "${GID}" >/dev/null 2>&1 || groupadd -g "${GID}" agent && \
    useradd --non-unique -m -u "${UID}" -g "${GID}" -s /bin/bash agent && \
    echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent && \
    chmod 0440 /etc/sudoers.d/agent

# ── Crontab ───────────────────────────────────────────────────────────────────
COPY cron/agent-cron /etc/cron.d/agent-cron
RUN chmod 0644 /etc/cron.d/agent-cron

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
