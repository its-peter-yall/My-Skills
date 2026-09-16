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
2. Ensures `git` and GitHub CLI are available; installs `gh` with winget when needed.
3. Requires GitHub CLI login because runner registration and the landing PR use GitHub APIs.
4. Asks for the review harness and optional model.
5. Installs the selected CLI from its official distribution when missing:
   - Claude: Anthropic native installer
   - OpenCode: official `@opencode/cli` npm package
   - Cursor: Cursor native Windows installer
   - Codex: OpenAI standalone Windows installer
6. Writes the generic workflow and prompt without committing unrelated files.
7. Registers or reuses a current-user self-hosted runner outside the repository.
8. Lands only the managed files through an isolated PR from the default branch.

Setup does **not** authenticate or check authentication for the selected harness. Authenticate it yourself before expecting PR reviews to succeed.

## Managed repository files

- `.github/workflows/automatic-prr.yml`
- `.github/automatic-prr/pr-review.md`

Older installations may also have `.github/claude/prompts/pr-review.md`. Setup removes that legacy path only when its content exactly matches the managed prompt. Modified legacy files are preserved.

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

## READY meaning

READY means:

1. `git`, `gh`, and the selected CLI are on the current user's PATH.
2. GitHub CLI is authenticated.
3. A matching self-hosted runner is online.
4. The runner runs as the current interactive Windows user, not `NETWORK SERVICE`.
5. The workflow and prompt are on the repository default branch.

Harness authentication is intentionally not included. The final setup report reminds you to authenticate it.

## Runner behavior

- Runner directory: `%USERPROFILE%\actions-runners\automatic-prr`
- Scheduled task: `GitHubActions-automatic-prr`
- Trigger: logon of the current Windows user
- Default label: `automatic-prr`
- Existing configured runners can receive the new label without replacement
- The user must remain logged in for reviews to run

## Security

The workflow rejects draft and fork pull requests before assigning work to the persistent runner. It checks out and verifies the exact PR SHA, pins checkout to an immutable commit, disables persisted checkout credentials, and gives GitHub only read-content and write-review permissions.

Registration tokens and harness credentials are never stored in the repository. Do not enable fork reviews on this runner.

## Tests

PowerShell:

```powershell
powershell -NoProfile -File tests\test-setup.ps1
powershell -NoProfile -File tests\test-tools.ps1
```

Git Bash or POSIX:

```bash
bash tests/test-setup.sh
```

Tests are offline. They do not register a runner, call GitHub APIs, download CLIs, authenticate providers, or invoke a model.
