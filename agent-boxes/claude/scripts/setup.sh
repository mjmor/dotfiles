#!/usr/bin/env bash
# setup.sh — idempotent host-side setup for the claude-code-agent container.
# Safe to re-run after adding repos or updating config files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_BOXES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
AGENT_HOME="${HOME}/agent-homes/claude"

# Load REPOS and AGENT_GH_HANDLE from the canonical config
source "${AGENT_BOXES_DIR}/config/env"

echo "==> Agent home: ${AGENT_HOME}"

# ── Directory skeleton ────────────────────────────────────────────────────────
echo "==> Creating directory skeleton..."
mkdir -p \
  "${AGENT_HOME}/.claude/skills/gh-issue-impl" \
  "${AGENT_HOME}/.config/tailscale" \
  "${AGENT_HOME}/.kube" \
  "${AGENT_HOME}/.ssh" \
  "${AGENT_HOME}/config" \
  "${AGENT_HOME}/logs/runs" \
  "${AGENT_HOME}/scripts" \
  "${AGENT_HOME}/workspace"
chmod 700 "${AGENT_HOME}/.ssh"

# ── Deploy config and scripts from repo ──────────────────────────────────────
# Note: these files must be copied (not symlinked) because symlink targets
# outside ~/agent-homes/claude/ are unreachable from inside the container —
# the bind mount only exposes that single directory tree. Re-run setup.sh to
# sync changes from the repo.
echo "==> Deploying config files and scripts..."
cp -f "${AGENT_BOXES_DIR}/config/env"               "${AGENT_HOME}/config/env"
cp -f "${AGENT_BOXES_DIR}/scripts/impl-issues.sh"   "${AGENT_HOME}/scripts/impl-issues.sh"
cp -f "${AGENT_BOXES_DIR}/scripts/setup-repos.sh"   "${AGENT_HOME}/scripts/setup-repos.sh"
chmod +x "${AGENT_HOME}/scripts/impl-issues.sh"
chmod +x "${AGENT_HOME}/scripts/setup-repos.sh"

# Deploy skill file
cp -f "${AGENT_BOXES_DIR}/skills/gh-issue-impl.md" \
    "${AGENT_HOME}/.claude/skills/gh-issue-impl/SKILL.md"

# Deploy settings.json only on first run to preserve claude auth state
if [ ! -f "${AGENT_HOME}/.claude/settings.json" ]; then
  echo "==> Writing initial .claude/settings.json..."
  cp -f "${AGENT_BOXES_DIR}/config/settings.json" "${AGENT_HOME}/.claude/settings.json"
else
  echo "==> .claude/settings.json already exists — skipping (auth state preserved)."
  echo "    To reset: rm ${AGENT_HOME}/.claude/settings.json && ./setup.sh"
fi

# Create per-repo log directories
for REPO in "${REPOS[@]}"; do
  mkdir -p "${AGENT_HOME}/logs/runs/$(basename "$REPO")"
done

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Setup complete. Next steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Run host-setup/bootstrap.sh first (sets up minikube, kubeconfig, agents-net)."
echo ""
echo "  2. Copy .env.example → .env and fill in values:"
echo "     cp agent-boxes/claude/.env.example agent-boxes/claude/.env"
echo ""
echo "  3. Build and start the container:"
echo "     cd agent-boxes/claude && docker compose up -d --build"
echo ""
echo "  4. Authenticate Claude Code (one-time, opens browser):"
echo "     docker compose exec claude su -s /bin/bash -c 'claude login' agent"
echo "     Open the URL printed above in your browser on this Mac."
echo ""
echo "  5. Authenticate gh CLI as ${AGENT_GH_HANDLE} inside the container:"
echo "     docker compose exec claude su -s /bin/bash -c 'gh auth login' agent"
echo "     Choose HTTPS + browser flow and log in as ${AGENT_GH_HANDLE}."
echo ""
echo "  6. Fork and clone repos (runs inside the container):"
echo "     docker compose exec claude su -s /bin/bash -c '/home/agent/scripts/setup-repos.sh' agent"
echo ""
echo "  7. Verify kubectl access:"
echo "     docker compose exec claude su -s /bin/bash -c 'kubectl get nodes' agent"
echo ""
