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
