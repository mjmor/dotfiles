---
name: gh-issue-impl
description: Use when asked to implement a GitHub issue or automate picking up ai-dev-ready issues assigned to mjmor from a GitHub repository — handles fork/upstream detection and delivers a reviewed draft PR with no user input required.
---

# gh-issue-impl

## Overview

Fully automated workflow: discover an `ai-dev-ready` issue assigned to `mjmor`, implement it, run quality checks, open a draft PR against the correct upstream, monitor CI/CD, and assign a reviewer — zero user input at any step.

## Repo Detection (Always Run First)

```bash
gh repo view --json isFork,parent --jq '{isFork: .isFork, parent: .parent.nameWithOwner}'
```

| Result | `<target-repo>` |
|--------|-----------------|
| `isFork: true` | `parent.nameWithOwner` (e.g. `greenearth-social/api`) |
| `isFork: false` | current repo (`gh repo view --json nameWithOwner --jq .nameWithOwner`) |

`<target-repo>` is used for **both** issue search and PR base repo.

## Workflow

### Step 0 — Find and Select Issue

First, collect the issue numbers that already have an open PR (identified by the `issue.<number>` branch convention):

```bash
OPEN_PR_ISSUES=$(gh pr list \
  --repo <target-repo> \
  --state open \
  --json headRefName \
  --jq '[.[].headRefName | select(startswith("issue.")) | ltrimstr("issue.") | tonumber]')
```

Then fetch candidate issues and exclude any whose number appears in that list:

```bash
gh issue list \
  --repo <target-repo> \
  --assignee mjmor \
  --label ai-dev-ready \
  --state open \
  --json number,title,body \
  | jq --argjson skip "$OPEN_PR_ISSUES" \
    'sort_by(.number) | map(select(.number as $n | ($skip | index($n)) == null)) | first'
```

Select the **lowest-numbered** open issue that has no open PR. If no eligible issues remain, stop and report to the user.

### Step 0.5 — Multi-PR Gate (run only if issue requires multiple PRs)

If the issue body describes requiring multiple sequential PRs, check whether a prior PR already exists before proceeding:

```bash
gh pr list \
  --repo <target-repo> \
  --state all \
  --json number,title,state,headRefName,url \
  --jq '[.[] | select(.headRefName | startswith("issue.<number>"))]'
```

| Situation | Action |
|-----------|--------|
| No previous PRs found | Proceed normally |
| One or more **open** PRs exist | Stop — a prior PR is still in progress. Report to user. |
| All previous PRs are **closed**, issue still open | Proceed — implement the next portion described in the issue |

If the issue does not mention multiple PRs, skip this step entirely.

### Step 1 — Create Feature Branch

```bash
git checkout main && git pull
git checkout -b issue.<number>
```

Branch name format is exactly `issue.<number>` (e.g. `issue.42`).

### Step 2 — Implement and Commit

Read the full issue title and body. Implement all changes described. When done, commit using this format:

```
<a brief, single line description; multiple remarks can be separated by semicolon>
```

```bash
git add -A
git commit -m "<brief description>"
```

### Steps 3–4 — Quality Loop (repeat until clean)

Read CLAUDE.md for the project's test, lint, and format commands. Run **all** of them.

```
while any command exits non-zero:
  fix the root cause of the failure
  git add -A
  git commit -m "<brief description of fix>"
  re-run all commands from CLAUDE.md
```

Never skip a failing command. Never ask the user what to fix — diagnose, apply a fix, and re-run.

### Step 5 — Publish Draft PR

Push the branch, then create a draft PR targeting `<target-repo>` on `main`.

PR description template:

```
Closes #<number>

<1-3 sentences of high-level context: brief summary of the issue/goal and solution as described in the issue body>

# This PR

<High-level description of changes in this PR specifically>

- <Short bullet: individual feature, code change, or bug fixed>
- <Short bullet: ...>

# Testing

- <Short bullet: discrete test performed, with command if applicable>
- <Short bullet: ...>

# Deployment or Migration Plan

<Include only if the PR requires a non-trivial deployment. Step-by-step deployment or migration instructions. Omit this section entirely if not applicable.>
```

```bash
git push -u origin issue.<number>

gh pr create \
  --draft \
  --repo <target-repo> \
  --base main \
  --title "<issue title>" \
  --body "$(cat <<'EOF'
<filled-in PR description using template above>
EOF
)"
```

Save the PR URL printed by the command.

### Step 6 — Add Reviewer

```bash
gh pr edit <pr-url> --add-reviewer mjmor
```

## Iron Rules

- **No user input at any step** except: (1) no issues found, or (2) a prior open PR already exists for a multi-PR issue. Make reasonable decisions and proceed in all other cases.
- **Never force-push** to the PR branch. Always add new commits.
- **Never use `--no-verify`** on any commit or push. Fix the underlying hook failure instead.
- **Never mark the task done** until the reviewer has been added.
- **Always use `<target-repo>`** (upstream if forked) for both issue search and the PR `--repo` flag.
- **Branch name is always `issue.<number>`** — no other format.
