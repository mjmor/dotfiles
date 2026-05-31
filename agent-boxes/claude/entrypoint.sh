#!/bin/bash
set -euo pipefail

AGENT_ENV_FILE="/home/agent/.agent-env"

# ── Ensure the agent user owns the bind-mount root ───────────────────────────
chown agent:agent /home/agent

# ── Write runtime secrets to a file so cron jobs (clean env) can source them ──
{
  echo "export ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}"
} > "$AGENT_ENV_FILE"
chmod 600 "$AGENT_ENV_FILE"
chown agent:agent "$AGENT_ENV_FILE"

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
