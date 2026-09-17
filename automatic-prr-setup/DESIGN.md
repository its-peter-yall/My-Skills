# automatic-prr-setup design contract

The approved full design is `../docs/harness-independent-pr-review/goal.md` from the repository root.

## Runtime contract

- Windows self-hosted GitHub Actions runner running as the current interactive user.
- One selected harness per setup: `claude`, `opencode`, `cursor`, or `codex`.
- Optional model; blank omits the CLI model flag.
- Generic managed paths:
  - `.github/workflows/automatic-prr.yml`
  - `.github/automatic-prr/pr-review.md`
- Default runner label: `automatic-prr`. Older installs may use `claude-review` and `.github/claude/prompts/pr-review.md`; relabel/reuse the configured runner and migrate the prompt path instead of `--replace`.
- Harness authentication is not performed or checked. READY does not include it. Workflow prerequisite steps check harness `--version` only.
- Missing selected CLIs are installed from official vendor distributions.
- Base tools include `git`, `gh`, and PowerShell 7 `pwsh`. After `ensure-tools.ps1`, the current agent session must prepend the printed GitHub CLI and `pwsh` directories onto `$env:Path`.
- `gh auth login` must be visible when the agent TTY cannot show a device code (`Start-Process powershell` with `gh auth login --hostname github.com --git-protocol https --web`, then poll `gh auth status`).

## Security contract

- Same-repository, non-draft pull requests only.
- Exact head-SHA checkout and verification.
- Immutable checkout action pin `3d3c42e5aac5ba805825da76410c181273ba90b1`.
- `persist-credentials: false`.
- Permissions limited to `contents: read`, `issues: write`, and `pull-requests: write`.
- Registration tokens and harness credentials never enter git.
- Runner replacement requires explicit confirmation.
- Runner zip SHA256 must match GitHub `asset.digest`. Unverified proxy downloads are not kept.

## Component responsibilities

| Path | Responsibility |
| --- | --- |
| `SKILL.md` | Interactive setup procedure and READY definition |
| `scripts/ensure-tools.ps1` | Ensure `git`, `gh`, and real `pwsh`; install via winget when missing; print sources |
| `scripts/ensure-harness.ps1` | Install or verify only the selected harness CLI |
| `scripts/setup.ps1`, `scripts/setup.sh` | Offline deterministic workflow/prompt rendering |
| `scripts/register-runner.ps1` | Hash-checked `curl.exe` download, PATH prefix with real `pwsh`, unlimited logon task, finish config when `.runner` is missing, graceful start, reuse/relabel |
| `scripts/runner-helpers.ps1` | Offline-testable digest, curl args, proxy URL, and `pwsh` path helpers |
| `templates/workflows/automatic-prr.yml` | Harness dispatcher and GitHub security controls |
| `templates/prompts/pr-review.md` | Shared `/code-review --comment` request |
| `tests/` | Offline rendering, tool-selection, helper, and docs coverage |

## Runner download and start

- Set `[Net.ServicePointManager]::SecurityProtocol` to include Tls12 before downloads.
- Download with `curl.exe`, not `Invoke-WebRequest`. Official `browser_download_url` first.
- Verify SHA256 against `asset.digest` from `gh api repos/actions/runner/releases/latest` (strip `sha256:`). Delete the zip on mismatch.
- On TLS reset / connection reset / handshake timeout: retry `curl.exe --ipv4`, then hash-checked `https://gh-proxy.com/https://github.com/actions/runner/releases/download/<tag>/<name>`.
- `start-runner.cmd` PATH prefix includes the real `pwsh` directory. `%LOCALAPPDATA%\Microsoft\WindowsApps` is last-resort only if it contains a working `pwsh`.
- Scheduled task `ExecutionTimeLimit` is unlimited (`TimeSpan.Zero`). Keep interactive logon for `%USERNAME%`, not `NETWORK SERVICE`. Keep `AllowStartIfOnBatteries` / `DontStopIfGoingOnBatteries` / `StartWhenAvailable`.
- If `config.cmd` exists but `.runner` is missing, finish registration. Do not skip config.
- Do not `Stop-Process -Force` `Runner.Listener`. Wait for API online and `Listening for Jobs`, or online without a session-conflict retry. Do not declare `READY_STATUS=online` from a stale API row while the local listener is conflict-looping.

## CLI contract

```text
claude -p <prompt> [--model <model>] --permission-mode dontAsk --setting-sources user --no-session-persistence
opencode run --standalone --auto [--model <model>] <prompt>
cursor-agent -p --force --trust [--model <model>] <prompt>
codex exec --ephemeral --sandbox workspace-write -c sandbox_workspace_write.network_access=true [--model <model>] <prompt>
```

The `/code-review` command is assumed to exist in each harness and must not pin its own model.
