# automatic-prr-setup design contract

The approved full design is `../docs/harness-independent-pr-review/goal.md` from the repository root. Report path, source-branch landing, and workflow-owned commenting are `../docs/pr-review-report-landing/goal.md`.

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
- After login, `scripts/assert-repo-auth.ps1` must pass. It reads `owner/repo` from `origin` and requires `permissions.admin` for the active github.com account. `gh auth status` and `gh repo view` are not that check: status ignores which account is active, and `gh repo view` follows that account. Organization repositories are administered by a member, not by signing in as the organization. If the check fails, `Start-Process powershell` may show `gh auth switch --hostname github.com`; do not continue until the script exits 0.
- Skill Initialization after harness selection: retain one shallow `master` snapshot of `https://github.com/its-peter-yall/My-Skills` outside the repository (record `SOURCE_SHA`), install unchanged `pr-code-review` and `code-review` from `Code-Review Skills` into `.claude/skills/` for Claude or `.agents/skills/` for OpenCode, Cursor, and Codex, reuse the same snapshot in the isolated landing worktree, stage only source-backed `MANAGED_PATH` files, and remove the snapshot after landing or aborting setup. Preflight both trees; differing existing files require a shown diff and explicit approval (exit 3 otherwise). Preserve unrelated extras; reject link/collision paths. The shared `.agents/skills/` layout also suits Antigravity, which is not a selectable setup harness.

## Security contract

- Same-repository, non-draft pull requests only.
- Exact head-SHA checkout and verification.
- Immutable checkout action pin `3d3c42e5aac5ba805825da76410c181273ba90b1`.
- `persist-credentials: false`.
- Permissions limited to `contents: write` and `pull-requests: write`. `GITHUB_TOKEN` is given only to the land+comment step, never to the harness.
- Workflow checkout and comment posting use that workflow token for `github.repository`, not the runner user's GitHub CLI account. The prerequisite step must not call `gh`, compare accounts, or switch accounts. Token failure does not fall back to stored `gh` credentials.
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
| `scripts/initialize-skills.ps1` | Download or reuse a `master` snapshot of the official review skills, preflight both trees, install unchanged `pr-code-review` and `code-review` into `.claude/skills/` (Claude) or `.agents/skills/` (others), report managed paths, exit 3 with diffs on unapproved conflicts |
| `scripts/repo-auth-helpers.ps1`, `scripts/assert-repo-auth.ps1` | Prove the active github.com account can administer the `origin` repository; do not trust `gh repo view` |
| `scripts/register-runner.ps1` | Hash-checked `curl.exe` download, PATH prefix with real `pwsh`, unlimited logon task, finish config when `.runner` is missing, graceful start, reuse/relabel. Calls `Resolve-ActiveGitHubRepoAccess` before registration |
| `scripts/runner-helpers.ps1` | Offline-testable digest, curl args, proxy URL, and `pwsh` path helpers |
| `templates/workflows/automatic-prr.yml` | Harness dispatcher and GitHub security controls |
| `templates/prompts/pr-review.md` | Shared pr-code-review request; harness writes `reviews/<PR_NUMBER>/` only |
| `tests/` | Offline rendering, tool-selection, helper, initializer, and docs coverage |

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
claude -p <prompt> --dangerously-skip-permissions --setting-sources user --no-session-persistence [--model <model>]
opencode run --standalone --auto [--model <model>] <prompt>
cursor-agent -p --force --trust --sandbox disabled --approve-mcps [--model <model>] <prompt>
codex exec --ephemeral --dangerously-bypass-approvals-and-sandbox [--model <model>] <prompt>
```

The prompt loads the initialized `pr-code-review` skill with its installed `code-review` companion; no preinstalled `/code-review` command is required. Skills are installed unchanged; the selected model is passed through the existing harness invocation. The harness writes Markdown only under `reviews/<PR_NUMBER>/` (required file `slack-report.md`) and must not commit, push, comment, or edit product code. After the harness exits, the workflow commits that folder onto the PR source branch and posts `slack-report.md` as a PR comment. READY includes both complete skill trees on the default branch.
