# Harness-independent automatic pull-request review

## Goal

Extend `automatic-prr-setup` so one self-hosted Windows GitHub Actions runner can review same-repository pull requests with one user-selected coding harness:

- Claude Code
- OpenCode V2 CLI
- Cursor Agent CLI
- OpenAI Codex CLI

The setup flow asks for the harness after repository, GitHub CLI, and runner prerequisites are handled, then asks for an optional harness-specific model ID. An empty model selection delegates model choice to that CLI's configured default.

The selected harness CLI is installed automatically when missing. Harness authentication is intentionally outside setup: the skill neither logs in, checks login status, warns on missing login, nor makes harness authentication part of READY.

This remains a Windows-first, current-user, self-hosted runner. It does not move review execution to a GitHub-hosted runner or vendor GitHub Action.

## User experience

The skill accepts the existing optional runner-label argument. Its default changes from `claude-review` to the harness-neutral `automatic-prr`.

After base setup, the agent asks two questions:

1. Select exactly one harness: `claude`, `opencode`, `cursor`, or `codex`.
2. Enter an optional model ID. Blank means the harness default.

The questions belong to the skill procedure. File installers remain deterministic and non-interactive by accepting explicit runner label, harness, and model parameters. The same values are reused when rendering files in the isolated landing worktree.

One setup selects one reviewer. A pull request does not run all four harnesses, and PR authors cannot select a different harness through pull-request content or metadata.

## READY contract

The skill may report READY only when all of these are true:

1. `git`, `gh`, and the selected harness CLI are available on PATH for the current Windows user.
2. GitHub CLI authentication works for repository and self-hosted-runner operations.
3. GitHub lists an online runner with both `self-hosted` and the selected runner label.
4. The runner executes as the current user through the existing interactive logon scheduled-task design, not as `NETWORK SERVICE`.
5. The generic workflow and prompt exist on the repository default branch.

Harness authentication is explicitly not a READY condition. The final report states that the user must authenticate the selected harness before an automatic review can succeed.

## Architecture

Use one parameterized workflow template rather than four templates or an additional committed adapter script.

The rendered workflow contains:

- `REVIEW_HARNESS`: one validated harness identifier.
- `REVIEW_MODEL`: the exact selected model string, or an empty string.
- One PowerShell dispatcher that verifies and invokes only the selected CLI.

The workflow and prompt become harness-neutral:

- `.github/workflows/automatic-prr.yml`
- `.github/automatic-prr/pr-review.md`

The workflow name becomes `Automatic PR Review`. Step names and comments use generic terminology except where a command is necessarily harness-specific.

The prompt continues to begin with `/code-review --comment`. This design assumes `/code-review` is already available to every selected harness, as required. The installed command must not pin its own model; in particular, an OpenCode command-level model overrides the CLI `--model` selection. Setup does not install or verify that command because doing so would require spending a harness invocation and would couple the skill to four command-distribution mechanisms.

## CLI installation

Installation occurs only when the selected CLI is absent. After installation, setup verifies that the expected executable resolves and prints a version. It does not silently upgrade an existing installation.

Official Windows installation sources are used:

| Harness | Executable | Installation |
| --- | --- | --- |
| Claude Code | `claude` | Anthropic native PowerShell installer, `https://claude.ai/install.ps1` |
| OpenCode V2 | `opencode` | `npm install -g @opencode/cli`; install Node.js LTS with winget first only when npm is absent |
| Cursor Agent | `cursor-agent`, or verified Cursor `agent` | Cursor native Windows PowerShell installer, `https://cursor.com/install?win32=true` |
| Codex | `codex` | OpenAI standalone PowerShell installer, `https://chatgpt.com/codex/install.ps1`, in documented non-interactive mode |

If an installer, package manager, PATH update, or post-install version check fails, setup stops as not READY.

Cursor requires special executable detection because `agent` is a generic name and this development machine already has a non-Cursor `agent`. Prefer `cursor-agent`. Fall back to `agent` only when a read-only version/help or about check identifies it as Cursor Agent. The chosen binary directory is added to the runner launcher's PATH.

## CLI invocation

The workflow reads the prompt as raw UTF-8 text, substitutes `PR_NUMBER`, `PR_SHA`, `BASE_SHA`, and `REPOSITORY`, and passes the complete result as one argument. PowerShell argument arrays are used throughout; the prompt and model are never evaluated as shell source.

When `REVIEW_MODEL` is empty, the model option is omitted. Otherwise the exact model string is passed to the harness's documented model flag.

Conceptual invocations:

```text
claude -p <prompt> [--model <model>] --permission-mode dontAsk --setting-sources user --no-session-persistence
opencode run --standalone --auto [--model <provider/model#variant>] <prompt>
cursor-agent -p --force --trust [--model <model>] <prompt>
codex exec --ephemeral --sandbox workspace-write -c sandbox_workspace_write.network_access=true [--model <model>] <prompt>
```

For Cursor, the verified `agent` executable may replace `cursor-agent`. For Codex, workspace sandboxing plus explicit network access is required so the review command can call `gh` to post findings. The prompt forbids source edits even though the sandbox permits workspace writes. Broader danger-full-access and approval-bypass flags are not used.

OpenCode uses standalone automation to avoid depending on the user's background service. OpenCode has no documented ephemeral-run flag, so setup does not claim that its session is non-persistent.

## Validation and rendering

Harness values are a closed, case-insensitive enum and are normalized to lowercase.

The model is optional. Trim surrounding whitespace; an empty result means default. A non-empty value must contain no CR or LF and must be at most 256 characters. It is not restricted to Claude-style aliases because valid OpenCode provider/model references, OpenCode variants, Cursor parameterized models, and Codex model IDs use different punctuation. Rendering escapes the value as YAML data, and runtime invocation passes it as one process argument.

`setup.ps1` and `setup.sh` remain file-only installers. They do not require `gh` or any harness CLI and do not access the network. Their interfaces add explicit harness and model options while preserving runner-label and force behavior.

## Base tools and runner integration

Refactor tool setup into two responsibilities:

- Base setup ensures `git` and `gh`, retaining the existing GitHub CLI winget installation path.
- Harness setup installs or verifies only the selected CLI.

GitHub authentication remains required because setup must query/register a runner and land a pull request. Harness authentication is not inspected.

Runner registration accepts the selected harness so the generated `start-runner.cmd` includes that CLI's resolved directory. Existing Git, GitHub CLI, and common user binary paths remain present.

When an existing configured runner is online but lacks the new default label, add the custom `automatic-prr` label through GitHub's runner-label API rather than deleting or replacing the runner. Destructive replacement still requires explicit confirmation. A custom label supplied by the user follows the same reuse/add-label behavior.

## Managed-file migration

The current workflow path is reused and remains protected by the existing compare-before-overwrite behavior.

The prompt moves from `.github/claude/prompts/pr-review.md` to `.github/automatic-prr/pr-review.md`:

- Install the generic prompt path.
- Delete the legacy prompt only when its content exactly matches the managed prompt template.
- Preserve a modified legacy prompt and report that it was left untouched.

The isolated landing pull request may therefore contain two additions/updates plus deletion of the exact managed legacy prompt. It must contain no unrelated files. Diff checks and conflict approval cover every managed path that changes.

## Security invariants

The existing workflow protections remain mandatory:

- Reject draft pull requests.
- Reject fork pull requests before a persistent self-hosted runner is assigned.
- Check out the exact pull-request head SHA with full history.
- Pin `actions/checkout` to the existing immutable full commit SHA.
- Set `persist-credentials: false`.
- Verify HEAD before review and attach the expected PR branch at the same SHA.
- Keep `contents: read`, `issues: write`, and `pull-requests: write` permissions.
- Keep per-PR concurrency with cancellation of superseded reviews.
- Pass `GH_TOKEN` only through the workflow environment.
- Never commit runner registration tokens, PATs, provider keys, or harness credentials.

The review prompt continues to require PR identity and head-SHA verification, review only changes introduced by the PR, avoid low-confidence findings, and prohibit edits, commits, pushes, merges, approvals, closure, or metadata changes.

## Error handling

| Case | Result |
| --- | --- |
| Invalid or missing harness selection | Ask again; do not render files |
| Invalid multiline or oversized model | Reject and ask again |
| Selected CLI installation fails | Stop, not READY |
| Selected executable cannot be verified after installation | Stop, not READY |
| Cursor `agent` resolves to another product | Ignore it; use/install `cursor-agent` |
| Harness is unauthenticated | Not checked during setup; a later workflow invocation may fail |
| Managed workflow or generic prompt differs | Show diff and require explicit force approval |
| Modified legacy Claude prompt exists | Preserve and report it |
| Existing runner lacks selected label | Add label and reuse it when possible |
| Workflow invocation exits nonzero | Fail the job and identify the selected harness and exit code without exposing credentials |

Existing repository, detached-HEAD, GitHub auth, runner token, merge-denied, dirty-worktree, and runner-offline error behavior remains in force.

## Tests

Default tests remain offline and never register a runner, call GitHub APIs, download installers, or invoke a paid model.

PowerShell and POSIX file-install tests cover:

- Rendering each of the four harness values.
- Correct non-interactive CLI and permission flags for each harness.
- Explicit model rendering and blank-model flag omission.
- Model values containing provider separators, variants, dots, colons, brackets, commas, and equals signs.
- Rejection of unknown harnesses and invalid model newlines/length.
- Generic workflow name, prompt path, environment names, and runner-label substitution.
- Exact checkout pin, fork/draft guards, SHA verification, permissions, and non-persisted checkout credentials.
- Prompt placeholders and `/code-review --comment`.
- Idempotent reinstall.
- Conflict exit code without force and replacement with force.
- Exact-match legacy prompt deletion and preservation of a modified legacy prompt.
- Absence of `gh` and harness CLIs during file-only installation.

Tool-install and runner-label behavior is split into testable functions or command-selection helpers so tests can mock command discovery and installer execution without network or machine changes.

## Documentation changes

Update `SKILL.md`, `README.md`, and the existing `DESIGN.md` contract to use harness-neutral terminology, document the interactive harness/model choices, explain automatic installation and the lack of auth checks, list each CLI invocation, and update READY and smoke-test examples.

The final report includes selected harness, selected model or `default`, runner name/status/label, landing branch and PR URL, and two operational reminders: the Windows user must remain logged in, and the user must authenticate the selected harness separately.

## Sources

- OpenCode V2 CLI and commands: <https://opencode.ai/v2/docs/cli/commands/> and <https://opencode.ai/v2/docs/commands/>
- OpenCode V2 models and install: <https://opencode.ai/v2/docs/models/> and <https://opencode.ai/v2/docs/>
- Cursor CLI parameters, authentication, and installation: <https://cursor.com/docs/cli/reference/parameters>, <https://cursor.com/docs/cli/reference/authentication>, and <https://cursor.com/docs/cli/installation>
- Codex non-interactive mode, CLI, skills, and authentication: <https://developers.openai.com/codex/non-interactive-mode>, <https://developers.openai.com/codex/cli>, <https://developers.openai.com/codex/build-skills>, and <https://developers.openai.com/codex/auth>
- Claude Code setup: <https://code.claude.com/docs/en/setup>
