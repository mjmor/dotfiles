#!/bin/bash
set -euo pipefail

# Source runtime secrets (ANTHROPIC_API_KEY, GITHUB_TOKEN) written by entrypoint
source /home/agent/.agent-env

# Source agent config (REPOS, AGENT_GH_HANDLE)
source /home/agent/config/env

# Ensure nvm-managed binaries are in PATH (cron provides a minimal environment)
export NVM_DIR="/home/agent/.nvm"
# shellcheck source=/dev/null
[ -s "${NVM_DIR}/nvm.sh" ] && source "${NVM_DIR}/nvm.sh"
export PATH="/home/agent/.local/bin:/home/agent/.claude/local:${PATH}"

WORKSPACE="/home/agent/workspace"
LOGS_DIR="/home/agent/logs/runs"
SKILL_FILE="/home/agent/.claude/skills/gh-issue-impl/SKILL.md"

TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")

log() { echo "[$(date -u +%FT%TZ)] $*"; }

if [ ! -f "$SKILL_FILE" ]; then
  log "ERROR: skill file not found at ${SKILL_FILE}" >&2
  exit 1
fi

SKILL_CONTENT=$(cat "$SKILL_FILE")

PROMPT="You are an autonomous coding agent. Follow the workflow below exactly — do not skip any steps, do not ask for input at any point.

${SKILL_CONTENT}

Execute the workflow now."

for REPO in "${REPOS[@]}"; do
  REPO_NAME=$(basename "$REPO")
  REPO_DIR="${WORKSPACE}/${REPO_NAME}"
  LOG_FILE="${LOGS_DIR}/${REPO_NAME}/${TIMESTAMP}.jsonl"

  log "Starting run for ${REPO}"

  if [ ! -d "${REPO_DIR}/.git" ]; then
    log "WARN: workspace not found at ${REPO_DIR}, skipping"
    continue
  fi

  mkdir -p "$(dirname "$LOG_FILE")"

  # Land on a clean default branch, then sync upstream → fork before handing off to claude
  cd "$REPO_DIR"

  # Resolve default branch from origin (fork); fall back to main
  DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}')
  DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

  # Force-checkout the default branch, discarding any local changes
  git checkout -f "$DEFAULT_BRANCH" 2>/dev/null \
    || { log "ERROR: could not checkout ${DEFAULT_BRANCH} for ${REPO}, skipping"; continue; }
  git reset --hard "origin/${DEFAULT_BRANCH}" 2>/dev/null \
    || { log "ERROR: could not reset to origin/${DEFAULT_BRANCH} for ${REPO}, skipping"; continue; }

  # Fetch latest from upstream and merge into the fork's default branch
  if git remote get-url upstream &>/dev/null; then
    UPSTREAM_BRANCH=$(git remote show upstream 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}')
    UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
    if ! git fetch upstream "$UPSTREAM_BRANCH" 2>/dev/null; then
      log "ERROR: fetch from upstream failed for ${REPO}, skipping"
      continue
    fi
    if ! git merge --ff-only "upstream/${UPSTREAM_BRANCH}" 2>/dev/null \
        && ! git merge --no-edit "upstream/${UPSTREAM_BRANCH}" 2>/dev/null; then
      git merge --abort 2>/dev/null || true
      log "ERROR: merge from upstream/${UPSTREAM_BRANCH} failed for ${REPO}, skipping"
      continue
    fi
    if ! git push origin "$DEFAULT_BRANCH" 2>/dev/null; then
      log "ERROR: push of synced ${DEFAULT_BRANCH} to origin failed for ${REPO}, skipping"
      continue
    fi
  else
    log "WARN: no upstream remote found for ${REPO}, skipping upstream sync"
  fi

  log "Invoking claude for ${REPO} → ${LOG_FILE}"

  claude \
    --permission-mode bypassPermissions \
    --output-format stream-json \
    --verbose \
    -p "$PROMPT" \
    >> "$LOG_FILE" 2>&1 \
    || log "WARN: claude exited non-zero for ${REPO} (see ${LOG_FILE})"

  log "Finished run for ${REPO}"
done
