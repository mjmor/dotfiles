#!/usr/bin/env bash
# teardown.sh — reverse of bootstrap.sh.
# Idempotent: checks existence before acting.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "══════════════════════════════════════════════════════"
echo "  Teardown"
echo "══════════════════════════════════════════════════════"
echo ""

# ── Resolve docker socket (Colima may still be up) ────────────────────────────
COLIMA_SOCK="${HOME}/.colima/default/docker.sock"
if [[ -S "${COLIMA_SOCK}" ]]; then
    export DOCKER_HOST="unix://${COLIMA_SOCK}"
fi

# ── Ollama launchd service ────────────────────────────────────────────────────
echo "==> Ollama launchd service"
PLIST_DEST="${HOME}/Library/LaunchAgents/com.ollama.ollama.plist"
if [[ -f "${PLIST_DEST}" ]]; then
    launchctl unload "${PLIST_DEST}" 2>/dev/null || true
    rm -f "${PLIST_DEST}"
    echo "  ✓ Ollama launchd service stopped and plist removed"
else
    echo "  • Ollama plist not found, skipping"
fi
echo ""

# ── Minikube ──────────────────────────────────────────────────────────────────
echo "==> Minikube"
if command -v minikube &>/dev/null; then
    if minikube status &>/dev/null 2>&1; then
        echo "  • Deleting minikube cluster..."
        minikube delete
        echo "  ✓ Minikube deleted"
    else
        echo "  • Minikube not running"
    fi
else
    echo "  • minikube not installed, skipping"
fi
echo ""

# ── agents-net Docker bridge ──────────────────────────────────────────────────
echo "==> agents-net Docker bridge"
if docker network inspect agents-net &>/dev/null 2>&1; then
    echo "  • Removing agents-net..."
    docker network rm agents-net || echo "  (could not remove — may have active endpoints)"
    echo "  ✓ agents-net removed"
else
    echo "  • agents-net not present"
fi
echo ""

# ── Colima ────────────────────────────────────────────────────────────────────
echo "==> Colima"
if command -v colima &>/dev/null; then
    if colima status 2>/dev/null | grep -q "Running"; then
        echo "  • Stopping Colima..."
        colima stop
        echo "  ✓ Colima stopped"
    else
        echo "  • Colima not running"
    fi
else
    echo "  • colima not installed, skipping"
fi
echo ""

# ── Artifacts ─────────────────────────────────────────────────────────────────
echo "==> Artifacts"
KUBECONFIG="${SCRIPT_DIR}/artifacts/kubeconfig-for-containers"
if [[ -f "${KUBECONFIG}" ]]; then
    rm -f "${KUBECONFIG}"
    echo "  ✓ Removed artifacts/kubeconfig-for-containers"
else
    echo "  • No artifacts to clean"
fi
echo ""

echo "══════════════════════════════════════════════════════"
echo "  Teardown complete"
echo "══════════════════════════════════════════════════════"
