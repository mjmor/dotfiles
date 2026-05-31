# claude-code-agent

Always-running Docker container that autonomously picks up GitHub issues, implements them, and opens draft PRs. Cron runs inside the container; you can also `tailscale ssh` in for interactive Claude Code sessions.

---

## Architecture overview

| Concern | Detail |
|---|---|
| Base image | `ubuntu:24.04` (ARM64) |
| State | Single bind mount: `~/agent-homes/claude` → `/home/agent` |
| Tailscale | Runs in-container, userspace networking (no TUN / NET_ADMIN) |
| Scheduling | `cron` inside container, weekday 08:00 UTC (≈ 03:00 ET) |
| Auth state | Lives in the bind mount — survives container rebuilds |

---

## Prerequisites

- Docker Desktop for Mac (or Docker Engine) with Compose V2
- Tailscale account — generate a **reusable** auth key at `admin.tailscale.com → Settings → Keys`
- `gh` CLI installed on your Mac (`brew install gh`)
- SSH key in `~/.ssh/` with access to `github.com` (used for git clone/push)

---

## One-time setup

### 1. Configure environment

```bash
cd agent-boxes/claude
cp .env.example .env
# Edit .env — fill in TS_AUTHKEY, GITHUB_TOKEN, UID, GID
```

Get your UID/GID:
```bash
id -u   # UID
id -g   # GID
```

### 2. Create the external Docker network (once per host)

```bash
docker network create agents-net
```

### 3. Authenticate gh CLI as the agent account

The setup script forks and clones repos using `gh`. Log in as `max-ai-ast` before running it:

```bash
gh auth login
# Choose GitHub.com → HTTPS → browser flow → log in as max-ai-ast
```

### 4. Run setup.sh

```bash
bash agent-boxes/claude/scripts/setup.sh
```

This script is **idempotent** — safe to re-run at any time. It:
- Creates `~/agent-homes/claude/` directory skeleton
- Deploys config files, scripts, and the `gh-issue-impl` skill
- Copies the kubeconfig from `host-setup/artifacts/kubeconfig` (if present)
- Forks each configured repo into `max-ai-ast` (skips existing forks)
- Clones each fork to `~/agent-homes/claude/workspace/<repo>/` (pulls if already cloned)

### 5. Build and start the container

```bash
cd agent-boxes/claude
docker compose up -d --build
```

The **first start** takes a few extra minutes — the entrypoint bootstraps nvm, Node.js LTS, and Claude Code into the bind mount. Subsequent starts are fast.

### 6. Authenticate Claude Code (one-time browser flow)

```bash
docker compose exec claude su -s /bin/bash -c 'claude login' agent
# Open the printed URL in your browser on this Mac
```

Auth state is saved to `~/agent-homes/claude/.claude/` and persists across rebuilds.

### 7. Verify everything works

```bash
# Tailscale — device should appear in admin.tailscale.com
tailscale status   # from your Mac

# Claude
docker compose exec claude su -s /bin/bash -c 'claude --version' agent

# gh CLI
docker compose exec claude su -s /bin/bash -c 'gh auth status' agent

# kubectl → minikube
docker compose exec claude su -s /bin/bash -c 'kubectl get nodes' agent
```

---

## Normal operation

### Cron schedule

`impl-issues.sh` runs at **08:00 UTC (≈ 03:00 ET) Monday–Friday**. For each configured repo it:

1. Sources `/home/agent/config/env` for the repo list
2. `cd`s to `/home/agent/workspace/<repo>/`
3. Invokes `claude --permission-mode bypassPermissions -p "<gh-issue-impl prompt>"`
4. Streams JSONL output to `/home/agent/logs/runs/<repo>/<timestamp>.jsonl`

The `gh-issue-impl` workflow picks the lowest-numbered open issue assigned to `mjmor` with label `ai-dev-ready` that doesn't already have an open PR, implements it, and opens a draft PR with `mjmor` as reviewer.

### Checking logs

```bash
# Live cron log
tail -f ~/agent-homes/claude/logs/cron.log

# Most recent run for a specific repo
ls -lt ~/agent-homes/claude/logs/runs/api/ | head -5

# Stream JSONL output of a run (pretty-print assistant turns)
cat ~/agent-homes/claude/logs/runs/api/<timestamp>.jsonl \
  | jq -r 'select(.type=="assistant") | .message.content[] | select(.type=="text") | .text'
```

### SSH into the container for interactive work

Once Tailscale is up:
```bash
tailscale ssh claude-code-agent
# You land as root. Switch to the agent user:
su - agent
claude   # interactive session, full skill/plugin support
```

Or exec directly from the host:
```bash
docker compose -f agent-boxes/claude/docker-compose.yml exec claude su -s /bin/bash agent
```

---

## Maintenance

### Adding a repo

1. Append an entry to `agent-boxes/claude/config/env`:
   ```bash
   REPOS=(
     ...
     "some-org/new-repo"
   )
   ```
2. Re-run `setup.sh` — it forks and clones the new entry, leaves existing ones untouched:
   ```bash
   bash agent-boxes/claude/scripts/setup.sh
   ```
3. Restart the container to pick up the updated config:
   ```bash
   cd agent-boxes/claude && docker compose restart
   ```

### Updating the container (packages, Go version, etc.)

Edit `Dockerfile` or `docker-compose.yml` as needed, then:
```bash
cd agent-boxes/claude
docker compose up -d --build
```

nvm, Node.js, and Claude Code live in the bind mount and are **not** rebuilt by Docker — they persist as-is. To force-reinstall them:
```bash
rm -rf ~/agent-homes/claude/.nvm ~/agent-homes/claude/.claude/local
docker compose restart   # entrypoint re-runs the bootstrap
```

### Updating the gh-issue-impl skill

Edit `agent-boxes/claude/skills/gh-issue-impl.md`, then re-run:
```bash
bash agent-boxes/claude/scripts/setup.sh
```
The skill file at `~/agent-homes/claude/.claude/skills/gh-issue-impl/SKILL.md` is always overwritten by `setup.sh`.

### Rotating the Tailscale auth key

1. Generate a new reusable key at `admin.tailscale.com → Settings → Keys`
2. Update `TS_AUTHKEY` in `agent-boxes/claude/.env`
3. `docker compose restart`

---

## Teardown

### Stop without destroying state

```bash
cd agent-boxes/claude
docker compose down
```

Restart later with `docker compose up -d` — all state is preserved in the bind mount.

### Full teardown (destroys all agent state)

```bash
cd agent-boxes/claude
docker compose down --rmi all
rm -rf ~/agent-homes/claude
```

This removes the container image, all workspace clones, logs, and auth credentials. You will need to redo the one-time setup steps.

---

## Troubleshooting

**Container exits immediately**
```bash
docker compose logs claude
```
Usually a missing or invalid `TS_AUTHKEY`. Check `.env`.

**tailscaled not ready / Tailscale node not showing up**
- Ensure `TS_AUTHKEY` is a *reusable* key (not one-time-use)
- The state dir is `~/agent-homes/claude/.config/tailscale/` — delete it and restart if the node is stuck in a bad state

**`kubectl get nodes` fails**
- Kubeconfig at `~/agent-homes/claude/.kube/config` may be missing or point to `127.0.0.1` (the Mac loopback, unreachable from inside the container). Ensure minikube's kubeconfig uses the `agents-net` gateway IP or the Mac's Tailscale IP, then re-run `setup.sh`.

**claude or node not found in cron**
- The entrypoint creates symlinks in `/usr/local/bin/` on each start. If missing, exec into the container and check `/home/agent/.nvm/` and `/home/agent/.claude/local/`.

**impl-issues.sh: no eligible issues**
- Normal — means all open `ai-dev-ready` issues assigned to `mjmor` already have open PRs, or there are none. Check the JSONL log for the run output.
