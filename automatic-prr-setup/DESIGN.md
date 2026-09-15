# automatic-prr-setup — out-of-the-box Windows runner

This spec is the contract for rewriting the skill so an agent that follows `SKILL.md` leaves **this Windows PC** ready to review same-repository pull requests. Canonical tree: this folder. After implementation, copy the skill (not this spec’s ClockWork counterpart) into OpenCode skill directories.

Do not treat “two YAML files written” as success.

## Goal

After `/automatic-prr-setup` (optional runner label; default `claude-review`), **READY** is allowed only when all of these are true:

1. `git`, `gh`, and `claude` are on PATH for the **current Windows user**.
2. `gh auth status` and `claude auth status` succeed for that same user.
3. A GitHub Actions self-hosted runner for the current repository is **online** and carries both `self-hosted` and the chosen label.
4. That runner executes as **this user** (scheduled logon task + `run.cmd`), not `NT AUTHORITY\NETWORK SERVICE`.
5. `.github/workflows/automatic-prr.yml` and `.github/claude/prompts/pr-review.md` exist on the repository **default branch**.

Human-only gates: browser `gh auth login` and `claude auth login`. The agent does everything else. The PC must stay powered on and this user logged in for jobs to run.

## Non-goals

- GitHub-hosted `ubuntu-latest` and `anthropics/claude-code-action`.
- Linux-only runners.
- Enabling fork pull requests on this persistent runner.
- Storing registration tokens, PATs, or Claude credentials in git.
- Changing branch protection or creating GitHub Apps.
- Silent install or upgrade of Claude Code.
- Deleting or replacing an existing runner without explicit confirmation.
- Merging unrelated feature branches (including `phase-4-voice-layer`) to land the workflow.
- Putting the runner application inside a git working tree.

## Runtime

- Job: `runs-on: [self-hosted, <label>]`.
- OS: Windows, current interactive user.
- Review binary: local `claude -p` (subscription/CLI login already on the machine).
- Shell in workflow steps: `pwsh`.
- Default model: `sonnet` (must match templates and tests).
- Checkout: `actions/checkout` pinned to SHA `3d3c42e5aac5ba805825da76410c181273ba90b1` (v7.0.1), `ref: github.event.pull_request.head.sha`, `fetch-depth: 0`, `persist-credentials: false`.
- Skip drafts and skip PRs where `head.repo.full_name != github.repository`.
- Concurrency group `automatic-prr-${{ github.event.pull_request.number }}` with `cancel-in-progress: true`.
- Runner files: `%USERPROFILE%\actions-runners\automatic-prr` (outside the repo).
- Skill distribution (this rewrite only, not a per-repo setup step): after implementation, overwrite `D:\Peter\S1\S1-SEVI\.opencode\skills\automatic-prr-setup` and, if the parent exists, `%USERPROFILE%\.config\opencode\skills\automatic-prr-setup`.

## Components

| Path | Responsibility |
| --- | --- |
| `SKILL.md` | Agent procedure and READY definition. No “remaining prerequisites” success path. |
| `README.md` | Human summary: Windows-first, logon-task runner, two browser logins, default-branch bootstrap. |
| `templates/workflows/automatic-prr.yml` | Managed workflow. Placeholder `__RUNNER_LABEL__`. `MODEL: "sonnet"`. All `run` steps `shell: pwsh`. |
| `templates/prompts/pr-review.md` | Prompt with `{{PR_NUMBER}}`, `{{PR_SHA}}`, `{{BASE_SHA}}`, `{{REPOSITORY}}`. |
| `scripts/setup.ps1` | Windows file installer. |
| `scripts/setup.sh` | POSIX file installer. Same behavior as `setup.ps1`. |
| `scripts/ensure-tools.ps1` | Tool presence; install GitHub CLI via winget when missing. |
| `scripts/register-runner.ps1` | Register or reuse runner; logon task; start now; never echo the registration token. |
| `tests/test-setup.ps1` | File-install tests on Windows. |
| `tests/test-setup.sh` | File-install tests on POSIX. Must not require `gh` on PATH. |

`setup.ps1` / `setup.sh` flags: `--runner-label LABEL` (default `claude-review`), `--force`. Label must match `^[A-Za-z0-9_.-]+$`. They write files only. They must **not** require `gh` or `claude` on PATH. They must **not** commit.

If a target exists and differs from the rendered source, exit 3 unless `--force`. Identical content is a successful no-op.

## Agent procedure

The agent executes these steps in order. `$ARGUMENTS` is a single optional runner label.

1. Confirm a Git working tree. Report branch. Stop on detached HEAD. Inspect `git status --short` and preserve unrelated user changes.
2. Resolve label: `$ARGUMENTS` or `claude-review`. Reject invalid characters.
3. Run `ensure-tools.ps1` from the skill directory (Windows). On POSIX, require `git`, `gh`, and `claude` already on PATH; do not invent a Linux runner in this revision.
4. If `claude` is missing: stop with the official Claude Code install command. Do not winget-install Claude Code.
5. Read-only `gh auth status` and `claude auth status`. If `gh` is unauthenticated, run `gh auth login` (HTTPS, git protocol https, scopes sufficient for repo admin Actions: `repo`, `workflow`, `read:org` as GitHub CLI offers). If `claude` is unauthenticated, run `claude auth login`. If either still fails: **stop, not READY**.
6. Inspect `.github/workflows/automatic-prr.yml` and `.github/claude/prompts/pr-review.md`. Run `setup.ps1` (or `setup.sh`) **without** `--force`. On exit 3, show a concise diff of both managed files, ask to replace, and rerun with `--force` only after explicit yes.
7. `git diff --check` on those two paths (intent-to-add if untracked so check applies).
8. Run `register-runner.ps1`. If `gh api repos/<owner>/<repo>/actions/runners` already lists an **online** runner whose labels include both `self-hosted` and the chosen label, skip registration. If a runner directory is configured but offline, start `run.cmd` as this user; do not `--replace` without confirmation. Afterward the API must show the runner online or **stop, not READY**. Registration token: `POST /repos/{owner}/{repo}/actions/runners/registration-token` via `gh api`; keep in memory; never write into the repo or skill folder.
9. Land managed files on the **default branch** without merging feature work:
   - `git fetch origin`.
   - Default branch = `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`.
   - Add a temporary git worktree at `%LOCALAPPDATA%\Temp\opencode\automatic-prr-setup-land` (create parent if needed) checked out from `origin/<default>` on a new branch `chore/automatic-prr-setup`.
   - Copy the two managed files into that worktree (or re-run setup with that worktree as cwd).
   - Commit **only** those two files. Push. `gh pr create` targeting the default branch.
   - Merge that PR if it contains only those files and `gh` permits (`gh pr merge --merge` or `--squash`). If merge is denied, leave the PR open and **not READY**.
   - Remove the worktree. Do not switch the user’s original branch away if it is dirty; the worktree exists so the original checkout stays put.
10. Report READY with: branch used for landing, PR URL, runner name, API status (`online`), label, and the logged-in-user constraint. Recommend a local `claude -p` smoke test only if the user wants to spend an invocation. Smoke-test model is `sonnet`, same placeholders as the workflow.

Invoking the skill on an application repository must not copy this skill tree. OpenCode copies happen only when implementing this rewrite (see Implementation order).

## File installer behavior

Render `__RUNNER_LABEL__` in the workflow template. Copy the prompt unchanged. Create parent directories. POSIX `install -m 0644`; PowerShell equivalent `Copy-Item` after render.

`setup.sh` today fails if `gh` is missing. That is a bug. After the rewrite, missing `gh`/`claude` during **file install** is allowed. Auth checks belong in the agent procedure and `register-runner.ps1`, not in `setup.sh`.

## Runner registration behavior

- Download the current GitHub Actions **win-x64** runner into `%USERPROFILE%\actions-runners\automatic-prr` if `config.cmd` is not already present.
- `config.cmd --unattended --url <repo-https-url> --token <token> --name <COMPUTERNAME>-<label> --labels self-hosted,<label> --work _work`. Use `--replace` only after confirmation when a config already exists.
- Do **not** `svc.cmd install` as NETWORK SERVICE.
- Register a current-user scheduled task:
  - Name: `GitHubActions-automatic-prr`
  - Trigger: at logon for `%USERNAME%`
  - Action: `run.cmd` in the runner directory
  - Run whether the user is logged on is **false** if a password would be required; interactive logon task is correct.
- Start `run.cmd` now in the background so the runner is online without a reboot.
- `gh` and `claude` must be on the **user** PATH that the task inherits (typical user install locations). If `claude` is only in an interactive session PATH, the skill must persist a user-level PATH or task environment so the runner finds `git`, `gh`, and `claude`.

## Workflow `pwsh` steps (normative)

Verify HEAD equals `$env:PR_SHA`, then `git switch -C $env:PR_BRANCH $env:PR_SHA`.

Prerequisite step: `git --version`, `gh --version`, `gh auth status`, `claude --version`, `claude auth status`.

Review step: read `.github/claude/prompts/pr-review.md` as raw text, replace the four `{{...}}` placeholders from process environment, invoke:

```text
claude -p <prompt> --model $env:MODEL --permission-mode dontAsk --setting-sources user --no-session-persistence
```

Permissions remain `contents: read`, `issues: write`, `pull-requests: write`. `GH_TOKEN` stays `${{ github.token }}` for `gh` inside the job; Claude posting uses the same permissions. Do not persist checkout credentials.

## Error table

| Case | Result |
| --- | --- |
| Not a git repo or detached HEAD | Stop |
| Invalid runner label | Stop |
| `git` missing | Stop |
| `claude` missing | Stop with install command |
| `gh` missing | Install via `winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements`; if winget fails, stop with the GitHub CLI install URL |
| Auth fails after login attempt | Stop, not READY |
| Registration token 403 | Stop: need repository admin for Actions self-hosted runners |
| Managed files differ | Diff + wait; `--force` only after yes |
| Isolated PR merge denied | PR left open; not READY |
| Matching runner already online | Skip register; continue landing files |
| Configured runner offline | Start `run.cmd`; if still offline, not READY |
| Unrelated dirty files in the original worktree | Leave them; land via worktree |

## Testing

Default tests are offline.

Must assert:

- File install succeeds with `gh` and `claude` absent from PATH (fake or empty PATH except `git` and `bash`/`pwsh`).
- `runs-on: [self-hosted, <label>]` after substitution.
- `MODEL: "sonnet"`.
- Checkout pin SHA `3d3c42e5aac5ba805825da76410c181273ba90b1`.
- Prompt contains `/code-review --comment`.
- Second identical install succeeds.
- Local edit without `--force` fails (exit 3).
- `--force` replaces the edit.

Do not call `config.cmd`, `gh api`, or the network in default tests. `register-runner.ps1` is not required to have a live integration test in this revision.

## Implementation order

1. Fix templates (`pwsh`, `sonnet`, keep security guards).
2. Rewrite `setup.sh` / add `setup.ps1` (no `gh` requirement).
3. Add `ensure-tools.ps1` and `register-runner.ps1`.
4. Rewrite tests to match templates and the no-`gh` installer.
5. Rewrite `SKILL.md` and `README.md` to this contract.
6. Copy the skill tree to the OpenCode destinations. Do not put that copy step in `SKILL.md` as something every invoke performs.

## Copy destinations (skill rewrite, not the target app repo)

Source of truth: `D:\Peter\Personal Stuffs\My-Skills\automatic-prr-setup`.

After implementation, overwrite:

- `D:\Peter\S1\S1-SEVI\.opencode\skills\automatic-prr-setup`
- `%USERPROFILE%\.config\opencode\skills\automatic-prr-setup` if `%USERPROFILE%\.config\opencode\skills` exists

Do not copy into ClockWork `docs/`. Do not commit `.opencode/` in S1-SEVI (it is gitignored).
