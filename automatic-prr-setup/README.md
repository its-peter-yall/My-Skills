# automatic-prr-setup

A skill that makes **this Windows PC** a self-hosted GitHub Actions runner for automatic Claude Code pull-request review.

An agent that follows `SKILL.md` is not done when two files exist. READY means tools and auth work for this user, a matching runner is **online**, and the workflow is on the **default branch**.

## Install

Place this directory at either:

- `~/.config/opencode/skills/automatic-prr-setup` (OpenCode)
- `~/.claude/skills/automatic-prr-setup` (Claude Code)
- `<project>/.opencode/skills/automatic-prr-setup` or `<project>/.claude/skills/automatic-prr-setup`

## Use

From the application repository:

```text
/automatic-prr-setup
```

Default runner label: `claude-review`. Custom label:

```text
/automatic-prr-setup my-runner-label
```

## What happens the moment you invoke it

The agent loads this skill and must drive the current GitHub repository to **READY**. It does not stop after writing YAML. Nothing reviews a PR until the last step has merged the workflow onto the default branch **and** this PC’s runner is online.

Assume you type `/automatic-prr-setup` (or `/automatic-prr-setup my-label`) from a repo such as `S1-SEVI` while you are on some feature branch.

### 1. Check the repo, leave your work alone

- Confirms you are in a Git repo and not in detached HEAD.
- Prints the current branch.
- Looks at `git status`. Unrelated dirty files stay untouched. Your feature branch is **not** merged.

### 2. Pick the runner label

- No argument → label `claude-review`.
- One argument → that label (letters, digits, `_`, `-`, `.` only).
- GitHub jobs will target runners with **both** `self-hosted` and this label.

### 3. Make sure `git`, `gh`, and `claude` exist

Runs `scripts/ensure-tools.ps1`:

- `git` missing → stop. Install Git for Windows yourself.
- `claude` missing → stop. Install Claude Code yourself (the skill will not silent-install it).
- `gh` missing → install GitHub CLI with winget. If winget fails → stop and open https://cli.github.com/

### 4. Log in (you, in a browser, if needed)

- Runs `gh auth status` and `claude auth status`.
- If GitHub CLI is logged out → `gh auth login` (HTTPS). You complete the browser flow.
- If Claude Code is logged out → `claude auth login`. You complete the browser flow.
- If either login still fails → **not READY**, stop. No runner, no merge.

### 5. Look at the two managed files

In the application repo:

- `.github/workflows/automatic-prr.yml`
- `.github/claude/prompts/pr-review.md`

If they already exist and differ from the skill templates, the agent shows a diff and **waits**. It overwrites only if you say yes (`-Force`).

### 6. Write the workflow into your working tree

Runs `scripts/setup.ps1` (Windows) or `scripts/setup.sh`. This does **not** need `gh`.

- Renders the workflow with your runner label, `shell: pwsh`, `MODEL: "sonnet"`.
- Copies the review prompt.
- Does **not** commit, push, or merge.
- Skips draft PRs and fork PRs in the workflow `if`.

These copies on your current feature branch are incidental. The live GitHub workflow is the copy landed on the default branch in step 10.

### 7. Syntax-check the two files

`git diff --check` on those paths. Fail → stop.

### 8. Turn this Windows PC into the runner

Runs `scripts/register-runner.ps1`:

- Asks GitHub: is there already an **online** runner for this repo with `self-hosted` + your label? If yes, skip download/register.
- If not: download the GitHub Actions **win-x64** runner into `%USERPROFILE%\actions-runners\automatic-prr` (outside the git repo).
- Mint a one-hour registration token in memory (`gh api`); never commit it.
- `config.cmd --unattended` with name `<COMPUTERNAME>-<label>` and labels `self-hosted,<label>`.
- Create scheduled task `GitHubActions-automatic-prr`: **at logon for this Windows user**, interactive, not `NETWORK SERVICE`.
- Start `run.cmd` now so the runner is online without a reboot.
- Poll GitHub until the runner is **online**. If it never comes up → **not READY**.

`--replace` / deleting an existing runner only happens if you explicitly confirm.

### 9. Put the workflow on the default branch (isolated PR)

Your feature branch (and any other local work) is left where it is.

- `git fetch origin`
- Default branch name from `gh repo view` (usually `main`)
- Temporary worktree: `%LOCALAPPDATA%\Temp\opencode\automatic-prr-setup-land` on new branch `chore/automatic-prr-setup` from `origin/<default>`
- Write **only** the two managed files there and commit **only** those files
- Push and `gh pr create` into the default branch
- Merge that PR if `gh` allows and the PR contains only those two files
- Remove the worktree

If GitHub refuses the merge → PR stays open, **not READY**. Later PRs will not auto-review until that workflow exists on the default branch.

This step never merges `phase-4-voice-layer` or any other feature branch.

### 10. READY report

The agent may say **READY** only when all of these are true:

1. `git`, `gh`, and `claude` on PATH for this Windows user  
2. Both `gh` and `claude` authenticated  
3. A matching self-hosted runner is **online**  
4. That runner is this user (logon task), not `NETWORK SERVICE`  
5. The two files exist on the **default branch**

You get: landing PR URL, runner name, `online`, label, and the reminder that this user must be logged in for jobs to run.

A local `claude -p` smoke test runs **only if you ask** (it spends a Claude turn).

### What does *not* happen on invoke

- No review of the bootstrap PR itself (GitHub will not use a brand-new `pull_request` workflow until it is on the default branch).
- No GitHub-hosted `ubuntu-latest` job and no `anthropics/claude-code-action`.
- No fork-PR reviews, no draft-PR reviews.
- No copy of this skill into the application repo.
- No commit of your unrelated files.
- No Windows password prompt; the runner dies if this user is logged off.

### After invoke succeeds (next day, next PR)

Sign into Windows as the same user → the logon task starts the runner → open a same-repo non-draft PR into the default branch → GitHub assigns `Automatic Claude PR Review` to this PC → `claude -p` posts the review.

## What the agent must finish

1. `scripts/ensure-tools.ps1` — require `git` and `claude`; install `gh` via winget if missing. Does not silent-install Claude Code.
2. `gh auth login` / `claude auth login` when needed (browser; human).
3. `scripts/setup.ps1` or `scripts/setup.sh` — write:
   - `.github/workflows/automatic-prr.yml`
   - `.github/claude/prompts/pr-review.md`  
   File install does **not** require `gh`.
4. `scripts/register-runner.ps1` — download the GitHub Actions win-x64 runner to `%USERPROFILE%\actions-runners\automatic-prr`, register labels `self-hosted` + the chosen label, create logon scheduled task `GitHubActions-automatic-prr` for this user, start `run.cmd` now. Not `NETWORK SERVICE`.
5. Isolated worktree from `origin/<default>` → commit **only** those two files → PR → merge. Never merge a feature branch that has other work.

## Human gates

- `gh auth login`
- `claude auth login`
- This Windows user must stay logged in (interactive logon task; reviews do not run while the PC is locked out / other user)

## Security

The job ignores draft PRs and PRs from forks. Do not relax the fork restriction on this persistent runner. Registration tokens are not written to the repository.

## Tests

```powershell
powershell -NoProfile -File tests\test-setup.ps1
```

```bash
bash tests/test-setup.sh
```

Default tests are offline. They do not register a runner or call `gh api`.
