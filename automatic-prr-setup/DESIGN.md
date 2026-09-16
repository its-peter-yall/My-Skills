# automatic-prr-setup design contract

The approved full design is `../docs/harness-independent-pr-review/goal.md` from the repository root.

## Runtime contract

- Windows self-hosted GitHub Actions runner running as the current interactive user.
- One selected harness per setup: `claude`, `opencode`, `cursor`, or `codex`.
- Optional model; blank omits the CLI model flag.
- Generic managed paths:
  - `.github/workflows/automatic-prr.yml`
  - `.github/automatic-prr/pr-review.md`
- Default runner label: `automatic-prr`.
- Harness authentication is not performed or checked.
- Missing selected CLIs are installed from official vendor distributions.

## Security contract

- Same-repository, non-draft pull requests only.
- Exact head-SHA checkout and verification.
- Immutable checkout action pin `3d3c42e5aac5ba805825da76410c181273ba90b1`.
- `persist-credentials: false`.
- Permissions limited to `contents: read`, `issues: write`, and `pull-requests: write`.
- Registration tokens and harness credentials never enter git.
- Runner replacement requires explicit confirmation.

## Component responsibilities

| Path | Responsibility |
| --- | --- |
| `SKILL.md` | Interactive setup procedure and READY definition |
| `scripts/ensure-tools.ps1` | Ensure base `git` and `gh` tools |
| `scripts/ensure-harness.ps1` | Install or verify only the selected harness CLI |
| `scripts/setup.ps1`, `scripts/setup.sh` | Offline deterministic workflow/prompt rendering |
| `scripts/register-runner.ps1` | Reuse, relabel, or register the current-user runner |
| `templates/workflows/automatic-prr.yml` | Harness dispatcher and GitHub security controls |
| `templates/prompts/pr-review.md` | Shared `/code-review --comment` request |
| `tests/` | Offline rendering and tool-selection coverage |

## CLI contract

```text
claude -p <prompt> [--model <model>] --permission-mode dontAsk --setting-sources user --no-session-persistence
opencode run --standalone --auto [--model <model>] <prompt>
cursor-agent -p --force --trust [--model <model>] <prompt>
codex exec --ephemeral --sandbox workspace-write -c sandbox_workspace_write.network_access=true [--model <model>] <prompt>
```

The `/code-review` command is assumed to exist in each harness and must not pin its own model.
