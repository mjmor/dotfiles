#!/usr/bin/env bash
# pre-cleanup.sh — remove prior-experiment environment components.
# Idempotent: presence-checks every item before acting.
set -euo pipefail

echo "══════════════════════════════════════════════════════"
echo "  Pre-cleanup: removing prior agent environment"
echo "══════════════════════════════════════════════════════"
echo ""

# ── 1. Lume VMs ─────────────────────────────────────────────────────────────
echo "==> [1] Lume VMs"
if command -v lume &>/dev/null; then
    LUME_FOUND=0
    while IFS= read -r vm; do
        [[ -z "$vm" ]] && continue
        LUME_FOUND=1
        echo "  • Deleting Lume VM: ${vm}"
        lume delete "${vm}" --force 2>/dev/null || lume delete "${vm}" 2>/dev/null || true
    done < <(lume list 2>/dev/null | awk 'NR>1 && $1 != "" {print $1}' || true)
    if [[ $LUME_FOUND -eq 0 ]]; then
        echo "  • No Lume VMs found"
    fi
    echo "  ✓ Lume VMs cleaned"
else
    echo "  • lume not installed, skipping"
fi
echo ""

# ── 2. launchd agents (claude-*, goose-*, agentgateway-*) ───────────────────
echo "==> [2] launchd agents"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
FOUND_AGENTS=0
if [[ -d "$LAUNCH_AGENTS_DIR" ]]; then
    for plist in \
        "${LAUNCH_AGENTS_DIR}"/claude-*.plist \
        "${LAUNCH_AGENTS_DIR}"/goose-*.plist \
        "${LAUNCH_AGENTS_DIR}"/agentgateway-*.plist \
        "${LAUNCH_AGENTS_DIR}"/*claude*.plist \
        "${LAUNCH_AGENTS_DIR}"/*goose*.plist \
        "${LAUNCH_AGENTS_DIR}"/*agentgateway*.plist; do
        # glob may not expand if no files match
        [[ -f "$plist" ]] || continue
        FOUND_AGENTS=1
        echo "  • Unloading: ${plist}"
        launchctl unload "${plist}" 2>/dev/null || true
        rm -f "${plist}"
        echo "    Removed: ${plist}"
    done
fi
if [[ $FOUND_AGENTS -eq 0 ]]; then
    echo "  • No matching launchd agents found"
fi
echo "  ✓ launchd agents cleaned"
echo ""

# ── 3. Standalone agentgateway binary ───────────────────────────────────────
echo "==> [3] agentgateway binary"
GATEWAY_FOUND=0
for bin_path in /usr/local/bin/agentgateway "${HOME}/.local/bin/agentgateway"; do
    if [[ -f "$bin_path" ]]; then
        GATEWAY_FOUND=1
        echo "  • Removing: ${bin_path}"
        rm -f "${bin_path}"
    fi
done
if [[ $GATEWAY_FOUND -eq 0 ]]; then
    echo "  • agentgateway binary not found"
fi
echo "  ✓ agentgateway checked"
echo ""

# ── 4. Goose CLI ─────────────────────────────────────────────────────────────
echo "==> [4] Goose CLI"
GOOSE_FOUND=0
for bin_path in "${HOME}/.local/bin/goose" /usr/local/bin/goose; do
    if [[ -f "$bin_path" ]]; then
        GOOSE_FOUND=1
        echo "  • Removing: ${bin_path}"
        rm -f "${bin_path}"
    fi
done
# Also check PATH-discovered goose (but don't remove system binaries in /usr/bin)
GOOSE_IN_PATH="$(command -v goose 2>/dev/null || true)"
if [[ -n "$GOOSE_IN_PATH" && "$GOOSE_IN_PATH" != /usr/bin/* ]]; then
    if [[ -f "$GOOSE_IN_PATH" ]]; then
        GOOSE_FOUND=1
        echo "  • Removing PATH goose: ${GOOSE_IN_PATH}"
        rm -f "${GOOSE_IN_PATH}"
    fi
fi
if [[ $GOOSE_FOUND -eq 0 ]]; then
    echo "  • Goose CLI not found"
fi
echo "  ✓ Goose CLI checked"
echo ""

# ── 5. Docker Desktop ────────────────────────────────────────────────────────
echo "==> [5] Docker Desktop"
if [[ -d "/Applications/Docker.app" ]]; then
    echo "  • Quitting Docker Desktop if running..."
    osascript -e 'tell application "Docker" to quit' 2>/dev/null || true
    sleep 2
    echo "  • Removing /Applications/Docker.app..."
    rm -rf "/Applications/Docker.app"
    rm -rf "${HOME}/Library/Group Containers/group.com.docker" 2>/dev/null || true
    rm -rf "${HOME}/Library/Containers/com.docker.docker" 2>/dev/null || true
    rm -rf "${HOME}/.docker" 2>/dev/null || true
    echo "  ✓ Docker Desktop removed"
    echo "  NOTE: If /var/run/docker.sock still references Docker Desktop, reboot to clear it."
else
    echo "  • Docker Desktop not installed, skipping"
fi
echo ""

# ── 6. Old minikube profiles ─────────────────────────────────────────────────
echo "==> [6] Old minikube profiles"
if command -v minikube &>/dev/null; then
    echo "  • Running: minikube delete --all"
    minikube delete --all 2>/dev/null || true
    echo "  ✓ All minikube profiles deleted"
else
    echo "  • minikube not installed, skipping"
fi
echo ""

# ── 7. Old Docker networks ───────────────────────────────────────────────────
echo "==> [7] Old Docker networks"
for net in agents-net minikube; do
    if docker network inspect "${net}" &>/dev/null 2>&1; then
        echo "  • Removing network: ${net}"
        docker network rm "${net}" 2>/dev/null || echo "    (could not remove ${net} — may have active endpoints)"
    else
        echo "  • Network '${net}' not present"
    fi
done
echo "  ✓ Docker networks checked"
echo ""

echo "══════════════════════════════════════════════════════"
echo "  Pre-cleanup complete"
echo "══════════════════════════════════════════════════════"
