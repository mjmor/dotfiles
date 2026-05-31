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

- `host-setup/bootstrap.sh` completed (sets up Colima, minikube, `agents-net`, kubeconfig)
- Docker Desktop for Mac (or Docker Engine) with Compose V2
- Tailscale account — generate a **reusable** auth key at `admin.tailscale.com → Settings → Keys`
- SSH key in `~/.ssh/` with access to `github.com` (used for git clone/push inside the container)

---

## One-time setup

### 1. Configure environment

```bash
cd agent-boxes/claude
cp .env.example .env
# Edit .env — fill in TS_AUTHKEY and UID
```

Get your UID:
```bash
id -u   # UID
```

> **Note on GID:** The container always uses GID 1000 for the `agent` group — macOS GIDs (e.g. 20 = `staff`) overlap with Ubuntu system GIDs and cause build errors. Only the UID is passed from the host so that files written by the container are owned by your Mac user on the bind-mounted path.

### 2. Run setup.sh

```bash
bash agent-boxes/claude/scripts/setup.sh
```

This script is **idempotent** — safe to re-run at any time. It:
- Creates `~/agent-homes/claude/` directory skeleton
- Deploys config files, scripts, and the `gh-issue-impl` skill from this repo

> **Note on config syncing:** config files are copied (not symlinked) because symlink
> targets outside `~/agent-homes/claude/` are unreachable from inside the container —
> the bind mount only exposes that single directory tree. Re-run `setup.sh` to sync
> changes from the repo to the deployed copies.

### 3. Build and start the container

```bash
cd agent-boxes/claude
docker compose up -d --build
```

### 4. Authenticate Claude Code (one-time browser flow)

```bash
docker compose exec claude su -s /bin/bash -c 'claude login' agent
# Open the printed URL in your browser on this Mac
```

Auth state is saved to `~/agent-homes/claude/.claude/` and persists across rebuilds.

### 5. Authenticate gh CLI inside the container

```bash
docker compose exec claude su -s /bin/bash -c 'gh auth login' agent
# Choose HTTPS + browser flow and log in as max-ai-ast
```

### 6. Fork and clone repos

```bash
docker compose exec claude su -s /bin/bash -c '/home/agent/scripts/setup-repos.sh' agent
```

This forks each repo in `config/env` into the `max-ai-ast` GitHub account (skips existing forks) and clones each fork to `/home/agent/workspace/<repo>/`. Safe to re-run after adding new repos.

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
2. Re-run `setup.sh` to sync the updated config to the bind mount:
   ```bash
   bash agent-boxes/claude/scripts/setup.sh
   ```
3. Run `setup-repos.sh` inside the container to fork and clone the new repo:
   ```bash
   docker compose exec claude su -s /bin/bash -c '/home/agent/scripts/setup-repos.sh' agent
   ```
4. Restart the container to pick up the updated config:
   ```bash
   cd agent-boxes/claude && docker compose restart
   ```

### Updating the container (packages, Go version, etc.)

Edit `Dockerfile` or `docker-compose.yml` as needed, then:
```bash
cd agent-boxes/claude
docker compose up -d --build
```

nvm, Node.js, and Claude Code are baked into the image. To upgrade them, rebuild:
```bash
docker compose up -d --build
```

### Updating the gh-issue-impl skill

Edit `agent-boxes/claude/skills/gh-issue-impl.md`, then re-run `setup.sh`:
```bash
bash agent-boxes/claude/scripts/setup.sh
```
The skill file at `~/agent-homes/claude/.claude/skills/gh-issue-impl/SKILL.md` is always overwritten on each run.

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
- Check entrypoint logs: `docker compose logs claude` — look for `Tailscale up` or socket timeout errors
- The state dir is `~/agent-homes/claude/.config/tailscale/` — delete it and restart if the node is stuck in a bad auth state: `rm -rf ~/agent-homes/claude/.config/tailscale && docker compose restart`
- If the container build previously failed (e.g. the GID collision), Tailscale never ran — rebuild first: `docker compose up -d --build`

**`kubectl get nodes` fails**
- Kubeconfig is generated by `host-setup/bootstrap.sh` and written into `~/agent-homes/claude/.kube/config`. If missing, re-run `bootstrap.sh`.
- If the kubeconfig points to `127.0.0.1` (Mac loopback), it won't be reachable from inside the container. `bootstrap.sh` rewrites the address to the `agents-net` gateway automatically.

**claude or node not found in cron**
- The entrypoint creates symlinks in `/usr/local/bin/` on each start. If missing, exec into the container and check `/home/agent/.nvm/` and `/home/agent/.claude/local/`.

**impl-issues.sh: no eligible issues**
- Normal — means all open `ai-dev-ready` issues assigned to `mjmor` already have open PRs, or there are none. Check the JSONL log for the run output.
