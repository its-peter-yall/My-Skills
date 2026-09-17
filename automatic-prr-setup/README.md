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
4. Requires GitHub CLI login because runner registration and the landing PR use GitHub APIs. If the agent TTY cannot show the device code, launch a visible PowerShell window with `Start-Process powershell` and `gh auth login --hostname github.com --git-protocol https --web`, then poll `gh auth status`. Do not treat a hidden hung login as success.
5. Asks for the review harness and optional model.
6. Installs the selected CLI from its official distribution when missing:
   - Claude: Anthropic native installer
   - OpenCode: official `@opencode/cli` npm package
   - Cursor: Cursor native Windows installer
   - Codex: OpenAI standalone Windows installer
7. Writes the generic workflow and prompt without committing unrelated files.
8. Registers or reuses a current-user self-hosted runner outside the repository.
9. Lands only the managed files through an isolated PR from the default branch.

Setup does **not** authenticate or check authentication for the selected harness. Authenticate it yourself before expecting PR reviews to succeed. READY does not include harness login.

## Managed repository files

- `.github/workflows/automatic-prr.yml`
- `.github/automatic-prr/pr-review.md`

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

The existing `/code-review` command must already be installed for the chosen harness and must not pin its own model. The managed prompt begins with `/code-review --comment`.

The workflow prerequisite step checks harness `--version` only, never harness login.

## READY meaning

READY means:

1. `git`, `gh`, `pwsh`, and the selected CLI are on the current user's PATH.
2. GitHub CLI is authenticated.
3. A matching self-hosted runner is online **and** the local listener is accepting work (`Listening for Jobs`), not a stale GitHub `online` row during a `TaskAgentSessionConflictException` loop.
4. The runner runs as the current interactive Windows user, not `NETWORK SERVICE`, with an unlimited scheduled-task execution time limit.
5. The workflow and prompt are on the repository default branch.

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

The workflow rejects draft and fork pull requests before assigning work to the persistent runner. It checks out and verifies the exact PR SHA, pins checkout to an immutable commit, disables persisted checkout credentials, and gives GitHub only read-content and write-review permissions.

Registration tokens and harness credentials are never stored in the repository. Do not enable fork reviews on this runner. Never keep an unverified runner zip.

## Tests

PowerShell:

```powershell
powershell -NoProfile -File tests\test-setup.ps1
powershell -NoProfile -File tests\test-tools.ps1
powershell -NoProfile -File tests\test-runner-helpers.ps1
```

Git Bash or POSIX:

```bash
bash tests/test-setup.sh
```

Tests are offline. They do not register a runner, call GitHub APIs, download CLIs, authenticate providers, or invoke a model.
