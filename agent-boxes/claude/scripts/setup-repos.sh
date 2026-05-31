#!/bin/bash
# setup-repos.sh — runs INSIDE the container as the agent user.
# Forks each configured repo into the agent GitHub account, then clones it.
# Idempotent: safe to re-run after adding repos to config/env.
set -euo pipefail

CONFIG_ENV="/home/agent/config/env"
WORKSPACE="/home/agent/workspace"

source "$CONFIG_ENV"

# Ensure nvm-managed tools are available
export NVM_DIR="/home/agent/.nvm"
[ -s "${NVM_DIR}/nvm.sh" ] && source "${NVM_DIR}/nvm.sh"
export PATH="/home/agent/.local/bin:/home/agent/.claude/local:${PATH}"

if ! gh auth status &>/dev/null; then
  echo "ERROR: gh CLI is not authenticated." >&2
  echo "  Run: gh auth login" >&2
  exit 1
fi

echo "==> Setting up repos as ${AGENT_GH_HANDLE}..."

for REPO in "${REPOS[@]}"; do
  REPO_NAME=$(basename "$REPO")
  FORK_SLUG="${AGENT_GH_HANDLE}/${REPO_NAME}"
  CLONE_DIR="${WORKSPACE}/${REPO_NAME}"

  # Fork if needed
  if gh repo view "${FORK_SLUG}" &>/dev/null; then
    echo "  [${REPO_NAME}] fork ${FORK_SLUG} already exists."
  else
    echo "  [${REPO_NAME}] forking ${REPO} → ${FORK_SLUG}..."
    gh repo fork "${REPO}" --clone=false
  fi

  # Clone or pull
  if [ -d "${CLONE_DIR}/.git" ]; then
    echo "  [${REPO_NAME}] already cloned — pulling latest..."
    git -C "${CLONE_DIR}" pull --ff-only 2>/dev/null \
      || echo "  [${REPO_NAME}] WARN: pull failed (dirty state?) — skipping."
  else
    echo "  [${REPO_NAME}] cloning git@github.com:${FORK_SLUG}.git..."
    git clone "git@github.com:${FORK_SLUG}.git" "${CLONE_DIR}"
    git -C "${CLONE_DIR}" remote add upstream "git@github.com:${REPO}.git" 2>/dev/null || true
    echo "  [${REPO_NAME}] upstream remote → git@github.com:${REPO}.git"
  fi
done

echo ""
echo "==> Repos ready in ${WORKSPACE}/"
