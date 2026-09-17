# Claude Code User Context

## Development Approach

### Incremental Development Philosophy
- Start small and build incrementally
- Always start with a test and stubbed out code for what we want to build, then proceed to implementation (i.e. TTD)
- Focus on one component at a time
- Always create todo lists before implementing features
- Confirm plans before proceeding with implementation

## Working Together

### Workflow
1. Claude creates todo list for any implementation task
2. Test and validate each component before moving to next

### Technical Standards
- Follow existing code patterns and conventions
- No unnecessary comments unless requested explicitly
- Run linting/testing commands when available

### Creating Commits and Pull Requests

During planning, always ask whether you should create git commits and 
pull requests. If I confirm you should be creating git commits and pull 
requests, you should follow the below format for git commit messages and 
pull request descriptions. Pull requests should always be created in draft 
mode.

#### PR hygiene — my job to catch, not yours to review

These apply to every repo. You should never be the one to find them.

1. **Never `git add -A` or `git add .`** Stage explicit paths, or `git add -u`
   for tracked files only. A blanket add sweeps in pre-existing untracked files
   that have nothing to do with the change. Run `git status --porcelain` first
   and treat every `??` line as "not mine unless I just created it".
2. **Diff the branch before opening the PR, and again after any force-push or
   merge.** `git diff --name-only <base>..<branch>` — every file must be one I
   can justify out loud as part of this change. Anything else comes out.
3. **One PR, one concern.** Design docs, assessments, write-ups and unrelated
   refactors do not ride along in a code PR. Put prose on the issue, or give it
   its own PR.
4. **Run the project's *full* CI locally before opening the PR, then confirm it
   passed.** Read `.github/workflows/` and run every check — not just the test
   suite. Type checkers (pyright/mypy), linters and formatters are the ones I
   skip and then fail on. After pushing, verify with `gh pr checks <n>`; a PR is
   not "ready" until checks are green.
5. **Stacked PRs:** re-check 2 and 4 on every branch in the stack after each
   rebase or merge — a merge can pull unrelated files forward.

Commit messages:
```txt
<a brief, single line description; multiple remarks can be separated by 
semicolon>
```

Pull request descriptions:
```txt
Closes #123 <-- this is the number following `issue.` in the branch name. 
E.g., the branch for this PR would be `issue.123`and the issue is #123

1-3 sentences of high level context surrounding this PR. E.g., info on external 
dependencies impacting the implementation direction.

# This PR

High level, brief description of the changes in this PR specifically. Specifically:

- Short bulleted list of individual and discreet features, code changes, bugs fixed in this PR
- E.g. Make disk storage requests factors of 2

# Testing

- Short bulleted list of discrete tests that were performed
- E.g., Deploy prod ES: `index/deploy.sh prod --install-eck --no-timeout --ctypes init`
- E.g., Deploy prod services (megastream ingest, jetstream ingest, expiry, extract) and observe logs in GCP: `cd ingest && ./scripts/deploy.sh`
```
