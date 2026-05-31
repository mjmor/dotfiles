#!/bin/bash
set -euo pipefail

NVM_DIR="/home/agent/.nvm"
NVM_VERSION="v0.40.1"
AGENT_ENV_FILE="/home/agent/.agent-env"

# ── Write runtime secrets to a file so cron jobs (clean env) can source them ──
{
  echo "export ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}"
} > "$AGENT_ENV_FILE"
chmod 600 "$AGENT_ENV_FILE"
chown agent:agent "$AGENT_ENV_FILE"

# ── Bootstrap nvm + Node.js LTS + Claude Code on first start ──────────────────
# Everything lands in /home/agent (the bind mount) so it persists across
# container rebuilds. Subsequent starts skip this block.
if [ ! -d "$NVM_DIR" ]; then
  echo "==> First start: installing nvm ${NVM_VERSION}, Node.js LTS, and Claude Code..."

  su -s /bin/bash agent -c "
    set -euo pipefail
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh \
      | NVM_DIR=${NVM_DIR} bash
    source ${NVM_DIR}/nvm.sh
    nvm install --lts
    nvm alias default node
    curl -fsSL https://claude.ai/install.sh | bash
  "

  echo "==> Bootstrap complete."
fi

# ── Create stable /usr/local/bin symlinks so cron PATH finds node/claude ──────
NODE_BIN=$(su -s /bin/bash agent -c "
  source ${NVM_DIR}/nvm.sh 2>/dev/null
  nvm which default 2>/dev/null || true
")
if [ -n "$NODE_BIN" ] && [ -f "$NODE_BIN" ]; then
  NODE_BIN_DIR=$(dirname "$NODE_BIN")
  ln -sf "$NODE_BIN"                   /usr/local/bin/node
  ln -sf "${NODE_BIN_DIR}/npm"         /usr/local/bin/npm  2>/dev/null || true
  ln -sf "${NODE_BIN_DIR}/npx"         /usr/local/bin/npx  2>/dev/null || true
fi

# Anthropic installer places the binary in ~/.claude/local/
for CLAUDE_CANDIDATE in \
    "/home/agent/.claude/local/claude" \
    "/home/agent/.local/bin/claude"; do
  if [ -f "$CLAUDE_CANDIDATE" ]; then
    ln -sf "$CLAUDE_CANDIDATE" /usr/local/bin/claude
    break
  fi
done

# ── Start tailscaled (userspace networking — no TUN or NET_ADMIN needed) ──────
mkdir -p /var/run/tailscale /home/agent/.config/tailscale
chown agent:agent /home/agent/.config/tailscale

tailscaled \
  --tun=userspace-networking \
  --socket=/var/run/tailscale/tailscaled.sock \
  --statedir=/home/agent/.config/tailscale \
  &

# Wait for the socket to be ready (up to 15 seconds)
for i in $(seq 1 15); do
  [ -S /var/run/tailscale/tailscaled.sock ] && break
  echo "Waiting for tailscaled... (${i}/15)"
  sleep 1
done

if [ ! -S /var/run/tailscale/tailscaled.sock ]; then
  echo "ERROR: tailscaled socket not ready after 15 seconds" >&2
  exit 1
fi

# Bring up Tailscale. Uses saved state if present; auth key is a fallback.
tailscale \
  --socket=/var/run/tailscale/tailscaled.sock \
  up \
  --authkey="${TS_AUTHKEY}" \
  --ssh \
  --hostname=claude-code-agent

echo "==> Tailscale up — device: claude-code-agent"

# ── Hand off to cron as PID 1 ─────────────────────────────────────────────────
exec cron -f
