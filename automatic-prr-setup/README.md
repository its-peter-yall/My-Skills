# automatic-prr-setup

Set up this Windows PC as a self-hosted GitHub Actions runner for automatic pull-request review with one selected CLI:

- Claude Code
- OpenCode V2
- Cursor Agent
- OpenAI Codex

The workflow is harness-neutral. Setup asks which harness to use and optionally which model; blank uses that CLI's default model.

## Install the skill

Place this directory at one of these locations:

- `~/.config/opencode/skills/automatic-prr-setup`
- `~/.claude/skills/automatic-prr-setup`
- `<project>/.opencode/skills/automatic-prr-setup`
- `<project>/.claude/skills/automatic-prr-setup`

Do not copy this skill tree into an application repository as a setup step.

## Invoke

From the application repository:

```text
/automatic-prr-setup
```

The default runner label is `automatic-prr`. Supply one optional custom label:

```text
/automatic-prr-setup my-runner-label
```

The skill then asks for:

1. `claude`, `opencode`, `cursor`, or `codex`
2. An optional model ID; leave blank for the CLI default

One repository setup runs one selected reviewer, not all four.

## What setup does

1. Checks the repository and preserves unrelated work.
2. Ensures `git`, GitHub CLI, and PowerShell 7 (`pwsh`) are available; installs `gh` and `Microsoft.PowerShell` with winget when needed. Prefers a real `pwsh.exe` path, not the 0-byte WindowsApps alias.
3. After `ensure-tools.ps1`, the current agent session must prepend the printed `gh:` and `pwsh:` directories onto `$env:Path` (winget does not update parent shells).
4. Requires GitHub CLI login because runner registration and the landing PR use GitHub APIs. If the agent TTY cannot show the device code, launch a visible PowerShell window with `Start-Process powershell` and `gh auth login --hostname github.com --git-protocol https --web`, then poll `gh auth status`. Do not treat a hidden hung login as success. Then run `scripts/assert-repo-auth.ps1`. `gh auth status` only proves some account is logged in. The active github.com account must have `permissions.admin` on the `owner/repo` named by `origin`. Do not use `gh repo view` for that identity. An organization repository is administered by a member account, not by signing in as the organization. If the script fails, `gh auth switch --hostname github.com` to an account with admin on that repository. If the agent TTY cannot complete the switch, launch `Start-Process powershell` for `gh auth switch --hostname github.com` and poll the script. Do not continue on `gh auth status` alone.
5. Asks for the review harness and optional model.
6. Installs the selected CLI from its official distribution when missing:
   - Claude: Anthropic native installer
   - OpenCode: official `@opencode/cli` npm package
   - Cursor: Cursor native Windows installer
   - Codex: OpenAI standalone Windows installer
7. **Skill Initialization:** downloads a snapshot of `master` from [My-Skills / Code-Review Skills](https://github.com/its-peter-yall/My-Skills/tree/master/Code-Review%20Skills) and installs the complete, unchanged `pr-code-review/` and `code-review/` folders into the repository. Claude uses `.claude/skills/`; OpenCode, Cursor, and Codex use `.agents/skills/`. Antigravity can use the shared layout but is not a selectable setup harness.
8. Writes the generic workflow and prompt without committing unrelated files.
9. Registers or reuses a current-user self-hosted runner outside the repository.
10. Lands only the managed files, including source-backed skill files, through an isolated PR from the default branch using the same source snapshot.

Setup does **not** authenticate or check authentication for the selected harness. Authenticate it yourself before expecting PR reviews to succeed. READY does not include harness login.

## Managed repository files

- `.github/workflows/automatic-prr.yml`
- `.github/automatic-prr/pr-review.md`
- `.claude/skills/pr-code-review/` and `.claude/skills/code-review/` for Claude, or `.agents/skills/pr-code-review/` and `.agents/skills/code-review/` for the other supported harnesses (only files present in the source snapshot)

### Skill Initialization

From the target repository, download once to a new directory outside the repository and retain it for the landing PR:

```powershell
powershell -NoProfile -File "<skill>/scripts/initialize-skills.ps1" -Harness opencode -SnapshotDirectory "<new-external-snapshot-path>"
```

Reuse that snapshot in the isolated landing worktree without another download:

```powershell
powershell -NoProfile -File "<skill>/scripts/initialize-skills.ps1" -Harness opencode -SourceDirectory "<existing-snapshot-path>"
```

The initializer prints `SOURCE_DIRECTORY`, `SOURCE_SHA`, and individual `MANAGED_PATH` entries. It validates both skill trees before copying, preserves nested assets and file bytes, and preserves extra destination files and other skills. Differing files produce a diff and exit code 3; rerun with `-Force` only after explicit approval. Review new conflicts in the landing worktree separately. Missing skills, unsafe paths, or download failures stop setup as not READY. Remove the retained snapshot after landing or aborting setup.

Stage only the reported managed paths, not entire skill directories. Verify staged skill content against the snapshot; stop if repository attributes would change its bytes. The existing `setup.ps1` and `setup.sh` remain offline workflow/prompt installers; initialization is a separate Windows PowerShell step.

Older installations may also have `.github/claude/prompts/pr-review.md` and runner label `claude-review`. Setup removes that legacy prompt path only when its content exactly matches the managed prompt. Modified legacy files are preserved. Relabel and reuse a configured runner; do not `--replace` without confirmation; force-overwrite managed files only after a diff and an explicit yes.

## Harness commands

The workflow invokes the selected CLI non-interactively:

```text
claude -p <prompt> [--model <model>] --permission-mode dontAsk --setting-sources user --no-session-persistence
opencode run --standalone --auto [--model <provider/model#variant>] <prompt>
cursor-agent -p --force --trust [--model <model>] <prompt>
codex exec --ephemeral --sandbox workspace-write -c sandbox_workspace_write.network_access=true [--model <model>] <prompt>
```

On Windows, setup prefers `cursor-agent` because another product may already own the generic `agent` command. It uses `agent` only after identifying it as Cursor Agent.

The managed prompt explicitly asks the agent to load `pr-code-review`, which uses the installed `code-review` companion. No preinstalled `/code-review` command is required. The harness writes Markdown only under `reviews/<PR_NUMBER>/`, including `slack-report.md`. It must not commit, push, comment, edit product code, or send Slack messages. The workflow then commits that folder onto the PR source branch and posts `slack-report.md` as a pull-request comment.

The workflow prerequisite step checks harness `--version` only, never harness login. It must not check the runner user's GitHub account. Checkout and comment posting use this repository's workflow token (`GITHUB_TOKEN`), not stored `gh` credentials. If that token fails, the job fails; it does not fall back to an interactive account.

## READY meaning

READY means:

1. `git`, `gh`, `pwsh`, and the selected CLI are on the current user's PATH.
2. GitHub CLI is authenticated as an account that can administer the repository named by `origin` (`scripts/assert-repo-auth.ps1`). Login to some other account is not enough.
3. A matching self-hosted runner is online **and** the local listener is accepting work (`Listening for Jobs`), not a stale GitHub `online` row during a `TaskAgentSessionConflictException` loop.
4. The runner runs as the current interactive Windows user, not `NETWORK SERVICE`, with an unlimited scheduled-task execution time limit.
5. The workflow, prompt, and both complete initialized skill folders are on the repository default branch in the selected harness's location.

Harness authentication is intentionally not included. The final setup report reminds you to authenticate it.

After READY, a tiny same-repo non-draft PR is optional only if you want to prove job pickup. Do not merge feature branches for that proof.

## Runner behavior

- Runner directory: `%USERPROFILE%\actions-runners\automatic-prr`
- Scheduled task: `GitHubActions-automatic-prr`
- Trigger: logon of the current Windows user
- ExecutionTimeLimit: unlimited (`TimeSpan.Zero`), so the logon task can keep `run.cmd` alive
- Default label: `automatic-prr`
- Existing configured runners can receive the new label without replacement
- If `config.cmd` exists but `.runner` is missing, registration is finished; config is not skipped
- Download uses `curl.exe` with TLS 1.2 against the official GitHub asset URL, then verifies SHA256 from `asset.digest`. On CDN TLS reset, retry `--ipv4`, then a hash-checked `https://gh-proxy.com/https://github.com/actions/runner/releases/download/<tag>/<name>` fallback. Never keep a zip that fails the hash.
- `start-runner.cmd` prefixes PATH with the real `pwsh` directory, GitHub CLI, Git, and the harness. `%LOCALAPPDATA%\Microsoft\WindowsApps` is last-resort only if it contains a working `pwsh`.
- Restart is graceful. Do not `Stop-Process -Force` `Runner.Listener`.
- The user must remain logged in for reviews to run

## Security

The workflow rejects draft and fork pull requests before assigning work to the persistent runner. It checks out and verifies the exact PR SHA, pins checkout to an immutable commit, disables persisted checkout credentials, and gives GitHub `contents: write` plus `pull-requests: write`. The harness step does not receive `GITHUB_TOKEN`. Only the land+comment step uses the token, and it stages solely `reviews/<PR_NUMBER>/`.

Registration tokens and harness credentials are never stored in the repository. Do not enable fork reviews on this runner. Never keep an unverified runner zip.

## Tests

PowerShell:

```powershell
powershell -NoProfile -File tests\test-setup.ps1
powershell -NoProfile -File tests\test-tools.ps1
powershell -NoProfile -File tests\test-runner-helpers.ps1
powershell -NoProfile -File tests\test-initialize-skills.ps1
powershell -NoProfile -File tests\test-repo-auth.ps1
```

Git Bash or POSIX:

```bash
bash tests/test-setup.sh
```

Tests are offline. They do not register a runner, call GitHub APIs, download CLIs, authenticate providers, or invoke a model.
