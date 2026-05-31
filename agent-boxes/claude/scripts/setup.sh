#!/usr/bin/env bash
# setup.sh — idempotent host-side setup for the claude-code-agent container.
# Safe to re-run after adding repos or updating config files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_BOXES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOTFILES_DIR="$(cd "${AGENT_BOXES_DIR}/../.." && pwd)"
AGENT_HOME="${HOME}/agent-homes/claude"
HOST_SETUP_ARTIFACTS="${DOTFILES_DIR}/host-setup/artifacts"

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

# ── Deploy config and scripts from repo (always overwrite) ───────────────────
echo "==> Deploying config files and scripts..."
cp -f "${AGENT_BOXES_DIR}/config/env"               "${AGENT_HOME}/config/env"
cp -f "${AGENT_BOXES_DIR}/scripts/impl-issues.sh"   "${AGENT_HOME}/scripts/impl-issues.sh"
chmod +x "${AGENT_HOME}/scripts/impl-issues.sh"

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

# ── Kubeconfig ────────────────────────────────────────────────────────────────
KUBECONFIG_SRC="${HOST_SETUP_ARTIFACTS}/kubeconfig"
if [ -f "$KUBECONFIG_SRC" ]; then
  echo "==> Copying kubeconfig..."
  cp -f "$KUBECONFIG_SRC" "${AGENT_HOME}/.kube/config"
  chmod 600 "${AGENT_HOME}/.kube/config"
else
  echo "==> WARN: kubeconfig not found at ${KUBECONFIG_SRC} — skipping."
  echo "    Place the minikube kubeconfig there and re-run setup.sh to deploy it."
fi

# Create per-repo log directories
for REPO in "${REPOS[@]}"; do
  mkdir -p "${AGENT_HOME}/logs/runs/$(basename "$REPO")"
done

# ── Repos: fork + clone ───────────────────────────────────────────────────────
echo ""
echo "==> Setting up repos (fork + clone as ${AGENT_GH_HANDLE})..."

if ! gh auth status &>/dev/null; then
  echo ""
  echo "    WARN: gh CLI is not authenticated — skipping fork/clone."
  echo "    Authenticate gh as the agent account, then re-run setup.sh:"
  echo "      gh auth login   # log in as ${AGENT_GH_HANDLE}"
  echo "      ./scripts/setup.sh"
else
  for REPO in "${REPOS[@]}"; do
    REPO_NAME=$(basename "$REPO")
    FORK_SLUG="${AGENT_GH_HANDLE}/${REPO_NAME}"
    CLONE_DIR="${AGENT_HOME}/workspace/${REPO_NAME}"

    # Fork if the fork does not already exist
    if gh repo view "${FORK_SLUG}" &>/dev/null; then
      echo "    [${REPO_NAME}] fork ${FORK_SLUG} already exists."
    else
      echo "    [${REPO_NAME}] forking ${REPO} → ${FORK_SLUG}..."
      gh repo fork "${REPO}" --clone=false
    fi

    # Clone if the workspace does not already exist; pull if it does
    if [ -d "${CLONE_DIR}/.git" ]; then
      echo "    [${REPO_NAME}] already cloned — pulling latest..."
      git -C "${CLONE_DIR}" pull --ff-only 2>/dev/null \
        || echo "    [${REPO_NAME}] WARN: pull failed (dirty state?) — skipping."
    else
      echo "    [${REPO_NAME}] cloning git@github.com:${FORK_SLUG}.git..."
      git clone "git@github.com:${FORK_SLUG}.git" "${CLONE_DIR}"
      git -C "${CLONE_DIR}" remote add upstream "git@github.com:${REPO}.git" 2>/dev/null || true
      echo "    [${REPO_NAME}] upstream remote → git@github.com:${REPO}.git"
    fi
  done
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Setup complete. Next steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Copy .env.example → .env and fill in values:"
echo "     cp agent-boxes/claude/.env.example agent-boxes/claude/.env"
echo ""
echo "  2. Create the external Docker network (once per host):"
echo "     docker network create agents-net"
echo ""
echo "  3. Build and start the container:"
echo "     cd agent-boxes/claude && docker compose up -d --build"
echo ""
echo "  4. Authenticate Claude Code (one-time, opens browser):"
echo "     docker compose exec claude su -s /bin/bash -c 'claude login' agent"
echo "     Open the URL printed above in your browser on this Mac."
echo ""
echo "  5. Authenticate gh CLI as ${AGENT_GH_HANDLE} (one-time):"
echo "     docker compose exec claude su -s /bin/bash -c 'gh auth login' agent"
echo "     Choose HTTPS + browser flow and log in as ${AGENT_GH_HANDLE}."
echo ""
echo "  6. If you skipped fork/clone above, re-run setup.sh after step 5."
echo ""
echo "  7. Verify kubectl access:"
echo "     docker compose exec claude su -s /bin/bash -c 'kubectl get nodes' agent"
echo ""
