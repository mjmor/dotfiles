#!/usr/bin/env bash
# bootstrap.sh — idempotent host setup for the Mac Mini M4 agent platform.
# Re-runs are safe; each section no-ops if already satisfied.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"

echo "══════════════════════════════════════════════════════"
echo "  Host bootstrap"
echo "══════════════════════════════════════════════════════"
echo ""

# ── A: Prerequisites ─────────────────────────────────────────────────────────
echo "==> [A] Checking prerequisites"

[[ "$(uname)" == "Darwin" ]] || { echo "ERROR: macOS required"; exit 1; }
[[ "$(uname -m)" == "arm64" ]] || { echo "ERROR: Apple Silicon (arm64) required"; exit 1; }
command -v brew &>/dev/null || { echo "ERROR: Homebrew not found — install from https://brew.sh"; exit 1; }

if ! tailscale status &>/dev/null; then
    echo "ERROR: Tailscale is not authenticated. Run: tailscale up"
    exit 1
fi
echo "  ✓ Prerequisites satisfied (macOS arm64, Homebrew, Tailscale authenticated)"
echo ""

# ── B: Homebrew packages ──────────────────────────────────────────────────────
echo "==> [B] Installing Homebrew packages"
BREW_PACKAGES=(colima docker docker-compose kubectl minikube ollama)
for pkg in "${BREW_PACKAGES[@]}"; do
    if brew list --formula "${pkg}" &>/dev/null; then
        # Upgrade only if a newer version is available; ignore non-zero exit (already current)
        brew upgrade "${pkg}" 2>/dev/null || true
        echo "  ✓ ${pkg} (already installed)"
    else
        echo "  • Installing ${pkg}..."
        brew install "${pkg}"
    fi
done
echo ""

# ── C: Colima ────────────────────────────────────────────────────────────────
echo "==> [C] Colima"
mkdir -p "${HOME}/.colima/default"
cp "${SCRIPT_DIR}/config/colima.yaml" "${HOME}/.colima/default/colima.yaml"
echo "  • Installed colima.yaml"

if colima status 2>/dev/null | grep -q "Running"; then
    echo "  ✓ Colima already running"
else
    echo "  • Starting Colima (this may take a minute)..."
    colima start
fi

# Resolve docker socket; prefer colima's socket so DOCKER_HOST is unambiguous
COLIMA_SOCK="${HOME}/.colima/default/docker.sock"
if [[ -S "${COLIMA_SOCK}" ]]; then
    export DOCKER_HOST="unix://${COLIMA_SOCK}"
fi
docker info &>/dev/null || { echo "ERROR: Docker socket not reachable after colima start"; exit 1; }
echo "  ✓ Docker socket verified"
echo ""

# ── D: agents-net bridge ─────────────────────────────────────────────────────
echo "==> [D] agents-net Docker bridge"
"${SCRIPT_DIR}/config/create-agents-net.sh"
echo ""

# ── E: Minikube ──────────────────────────────────────────────────────────────
echo "==> [E] Minikube"
mkdir -p "${SCRIPT_DIR}/artifacts"

if minikube status --profile=minikube 2>/dev/null | grep -q "Running"; then
    echo "  ✓ Minikube already running"
else
    echo "  • Starting minikube (driver=docker, network=agents-net)..."
    minikube start \
        --driver=docker \
        --network=agents-net \
        --static-ip=172.18.0.10 \
        --memory="${MINIKUBE_MEMORY}" \
        --cpus="${MINIKUBE_CPUS}" \
        --disk-size=10g
fi

# Enable addons (idempotent — enable is a no-op if already enabled)
echo "  • Enabling addons: ${MINIKUBE_ADDONS}"
for addon in ${MINIKUBE_ADDONS}; do
    minikube addons enable "${addon}" 2>/dev/null || true
done
echo "  ✓ Addons enabled"

# Discover minikube container's IP on agents-net
MINIKUBE_NET_IP="$(docker inspect minikube \
    --format '{{(index .NetworkSettings.Networks "agents-net").IPAddress}}' 2>/dev/null || true)"

if [[ -z "${MINIKUBE_NET_IP}" ]]; then
    echo "ERROR: Could not resolve minikube container IP on agents-net."
    echo "  Verify: docker inspect minikube | grep agents-net"
    exit 1
fi
echo "  • Minikube agents-net IP: ${MINIKUBE_NET_IP}"

# Rewrite kubeconfig server URL: 127.0.0.1:<host-port> → <agents-net-ip>:8443
# The host-mapped port only works via 127.0.0.1; inside the network the API
# server always listens on 8443 directly on the container.
KUBECONFIG_DEST="${SCRIPT_DIR}/artifacts/kubeconfig-for-containers"
sed "s|https://127\.0\.0\.1:[0-9]*|https://${MINIKUBE_NET_IP}:8443|g" \
    "${HOME}/.kube/config" > "${KUBECONFIG_DEST}"
chmod 600 "${KUBECONFIG_DEST}"
echo "  ✓ Kubeconfig written → artifacts/kubeconfig-for-containers (server: ${MINIKUBE_NET_IP}:8443)"

# Deploy into agent homes so containers can use it
AGENT_KUBE="${HOME}/agent-homes/claude/.kube/config"
if [[ -d "${HOME}/agent-homes/claude/.kube" ]]; then
    cp "${KUBECONFIG_DEST}" "${AGENT_KUBE}"
    chmod 600 "${AGENT_KUBE}"
    echo "  ✓ Kubeconfig deployed → ~/agent-homes/claude/.kube/config"
fi
echo ""

# ── F: Ollama launchd service ─────────────────────────────────────────────────
echo "==> [F] Ollama launchd service"
PLIST_SRC="${SCRIPT_DIR}/config/ollama.plist"
PLIST_DEST="${HOME}/Library/LaunchAgents/com.ollama.ollama.plist"

cp "${PLIST_SRC}" "${PLIST_DEST}"

# Unload any existing instance, then (re)load with -w so it persists across reboots
launchctl unload "${PLIST_DEST}" 2>/dev/null || true
launchctl load -w "${PLIST_DEST}"
echo "  • Waiting for Ollama on 127.0.0.1:11434 (up to 20s)..."
for i in $(seq 1 20); do
    if curl -sf http://127.0.0.1:11434/ &>/dev/null; then
        echo "  ✓ Ollama is listening on 11434"
        break
    fi
    sleep 1
    if [[ $i -eq 20 ]]; then
        echo "ERROR: Ollama did not become ready within 20s."
        echo "  Check logs: cat /tmp/ollama.stderr.log"
        exit 1
    fi
done
echo ""

# ── G: Pull Ollama models ─────────────────────────────────────────────────────
echo "==> [G] Pulling Ollama models"
ALL_MODELS="${OLLAMA_MODELS_LOCAL} ${OLLAMA_MODELS_CLOUD}"

for model in ${ALL_MODELS}; do
    if ollama show "${model}" &>/dev/null 2>&1; then
        echo "  ✓ Already present: ${model}"
    else
        echo "  • Pulling: ${model}"
        if ! ollama pull "${model}"; then
            echo ""
            echo "ERROR: Failed to pull '${model}'."
            echo "  The tag may be incorrect. Browse https://ollama.com/library to verify."
            echo "  Update OLLAMA_MODELS_LOCAL / OLLAMA_MODELS_CLOUD in config.env and re-run."
            echo "  DO NOT substitute a different model — update config.env and confirm first."
            exit 1
        fi
    fi
done
echo "  ✓ All models present"
echo ""

# ── H: Verification summary ───────────────────────────────────────────────────
echo "══════════════════════════════════════════════════════"
echo "  Bootstrap complete — verification"
echo "══════════════════════════════════════════════════════"
echo ""

echo "── Colima ──"
colima status
echo ""

echo "── agents-net ──"
docker network inspect agents-net \
    --format 'Name: {{.Name}}  Driver: {{.Driver}}  Subnet: {{(index .IPAM.Config 0).Subnet}}'
echo ""

echo "── Minikube ──"
minikube status
echo ""

echo "── Kubernetes nodes (via host kubeconfig — 127.0.0.1) ──"
kubectl get nodes
echo ""
echo "── Container kubeconfig server URL ──"
grep "server:" "${SCRIPT_DIR}/artifacts/kubeconfig-for-containers"
echo "  (reachable from containers on agents-net, not from the host)"
echo ""

echo "── Ollama models ──"
ollama list
echo ""

echo "── Container → host Ollama reachability (run manually from a container) ──"
echo "  docker run --rm --network=agents-net curlimages/curl:latest \\"
echo "    curl -s http://host.docker.internal:11434/"
echo ""
