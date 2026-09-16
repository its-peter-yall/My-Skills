---
name: automatic-prr-setup
description: Set up automatic pull-request review with Claude Code, OpenCode, Cursor, or Codex on this Windows PC as a self-hosted GitHub Actions runner. Installs the selected CLI, workflow files, GitHub CLI if needed, registers a current-user runner, and lands the workflow on the default branch.
---

# Automatic PR review setup

Make **this Windows PC** review same-repository pull requests with one user-selected coding harness. File installation alone is not success.

Canonical skill directory: the folder containing this `SKILL.md`. Scripts live in `scripts/` relative to it.

## READY (all required)

Say READY only when every item is true:

1. `git`, `gh`, and the selected harness CLI are on PATH for the current Windows user.
2. `gh auth status` succeeds for that user.
3. `gh api repos/<owner>/<repo>/actions/runners` lists an **online** runner with both `self-hosted` and the chosen label.
4. That runner runs as this user through a logon scheduled task and `run.cmd`, not `NETWORK SERVICE`.
5. `.github/workflows/automatic-prr.yml` and `.github/automatic-prr/pr-review.md` exist on the repository default branch.

Harness authentication is deliberately not checked and is not part of READY. Always tell the user to authenticate the selected harness before expecting reviews to succeed.

If any required item fails, say **not READY** and stop.

## Boundaries

- This machine is the runner. Do not switch to GitHub-hosted runners or vendor review actions.
- Never enable forked pull requests on this persistent runner. Keep the draft and fork rejection guard.
- Install only the selected harness CLI, never all four.
- Do not run, check, or automate harness authentication.
- Do not store registration tokens, PATs, API keys, or harness credentials in git.
- Do not change branch protection or create GitHub Apps.
- Do not overwrite differing managed files without showing the diff and receiving explicit force approval.
- Delete the legacy `.github/claude/prompts/pr-review.md` only when it exactly matches the managed prompt template.
- Do not delete or replace an existing runner without explicit confirmation. Add the chosen label to the configured runner when possible.
- Do not merge unrelated feature branches to land the workflow.
- Do not put the runner application inside a git working tree.
- Do not copy this skill tree into the application repository during setup.
- Commit, push, and merge only the managed workflow, generic prompt, and an exact-match legacy prompt deletion, using an isolated branch from default.

The only setup authentication gate is `gh auth login`. Harness login belongs to the user after setup.

## Procedure

1. Confirm a Git working tree. Report the current branch. Stop on detached HEAD. Inspect `git status --short` and preserve unrelated changes.

2. Resolve the runner label from the single `$ARGUMENTS` value, or use `automatic-prr`. Accept only letters, digits, `_`, `-`, and `.`.

3. On Windows, ensure base tools:

   ```powershell
   powershell -NoProfile -File "<skill>/scripts/ensure-tools.ps1"
   ```

   This requires `git` and installs `gh` with winget when missing. On POSIX, require `git` and `gh`; this skill does not register a POSIX runner.

4. Run `gh auth status`. If unauthenticated, run `gh auth login` using HTTPS. If it still fails, stop as not READY.

5. Ask the user to select exactly one review harness:

   - `claude` — Claude Code
   - `opencode` — OpenCode V2 CLI
   - `cursor` — Cursor Agent CLI
   - `codex` — OpenAI Codex CLI

6. Ask for an optional model ID. Trim surrounding whitespace. Blank means the CLI's configured default. Reject CR/LF, control characters, and values longer than 256 characters. Do not offer hard-coded model menus. The installed `/code-review` command must not pin its own model, because command-level model settings can override CLI selection.

7. Install or verify only the selected harness CLI:

   ```powershell
   powershell -NoProfile -File "<skill>/scripts/ensure-harness.ps1" -Harness "<harness>"
   ```

   Official installers are used for missing CLIs. Do not run any harness login or status command.

8. Inspect these application-repository paths:

   - `.github/workflows/automatic-prr.yml`
   - `.github/automatic-prr/pr-review.md`
   - `.github/claude/prompts/pr-review.md` (legacy migration only)

9. Install files without force, passing the exact selected values:

   ```powershell
   powershell -NoProfile -File "<skill>/scripts/setup.ps1" -RunnerLabel "<label>" -Harness "<harness>" -Model "<model>"
   ```

   ```bash
   bash "<skill>/scripts/setup.sh" --runner-label "<label>" --harness "<harness>" --model "<model>"
   ```

   Omit the model option when blank if the calling shell cannot preserve an empty argument. These file-only installers must not require `gh` or any harness CLI.

10. If the installer exits 3, show a concise diff of managed files. Ask whether to replace them. Rerun with `-Force` or `--force` only after explicit approval. A modified legacy Claude prompt is preserved without blocking setup.

11. Use intent-to-add for untracked managed files, then run `git diff --check` over the workflow, generic prompt, and legacy prompt when changed.

12. Register, relabel, or reuse the runner:

   ```powershell
   powershell -NoProfile -File "<skill>/scripts/register-runner.ps1" -RunnerLabel "<label>" -Harness "<harness>"
   ```

   Reuse an online matching runner. If the configured online runner lacks the chosen label, add it through GitHub's runner-label API. If configured but offline, start it. Never replace it without confirmation. The API must show it online or setup is not READY.

13. Land managed changes on the default branch without merging feature work:

   - `git fetch origin`.
   - Read the default branch with `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`.
   - Create an isolated worktree under `%LOCALAPPDATA%\Temp\opencode\automatic-prr-setup-land` on `chore/automatic-prr-setup` from `origin/<default>`.
   - Run the installer there with the same label, harness, and model. Use force only if already approved.
   - Commit only `.github/workflows/automatic-prr.yml`, `.github/automatic-prr/pr-review.md`, and an exact-match deletion of `.github/claude/prompts/pr-review.md` when present.
   - Push, create a PR targeting default, verify its file list, and merge if permitted.
   - If merge is denied, leave the PR open and report not READY.
   - Remove the temporary worktree without switching the user's original checkout.

14. Report READY with landing branch, PR URL, runner name, API status `online`, label, harness, and selected model or `default`. Remind the user that this Windows account must remain logged in and that they must authenticate the harness separately.

Recommend a local smoke test only when the user wants to spend a harness invocation. Use the same rendered prompt and selected model behavior as the workflow; never silently run it.

## Harness invocation contract

The workflow passes the rendered prompt as one process argument and omits the model flag when model is blank:

```text
claude -p <prompt> [--model <model>] --permission-mode dontAsk --setting-sources user --no-session-persistence
opencode run --standalone --auto [--model <provider/model#variant>] <prompt>
cursor-agent -p --force --trust [--model <model>] <prompt>
codex exec --ephemeral --sandbox workspace-write -c sandbox_workspace_write.network_access=true [--model <model>] <prompt>
```

Cursor may use `agent` only after verifying it is Cursor Agent. Never invoke an unrelated executable named `agent`.

The workflow checks the exact PR SHA, rejects drafts and forks, pins `actions/checkout` to `3d3c42e5aac5ba805825da76410c181273ba90b1`, uses `pwsh`, avoids persisted checkout credentials, and cancels superseded reviews.

## Errors

| Case | Result |
| --- | --- |
| Not a git repo or detached HEAD | Stop |
| Invalid runner label, harness, or model | Stop |
| `git` missing | Stop |
| `gh` missing | Install via winget; stop with <https://cli.github.com/> if installation fails |
| Selected harness missing | Install from the official source; stop if post-install verification fails |
| GitHub auth fails after login | Stop, not READY |
| Harness unauthenticated | Do not check; remind the user in the final report |
| Cursor `agent` is another product | Ignore it; use or install `cursor-agent` |
| Registration token 403 | Stop: repository admin access is required |
| Managed files differ | Diff and wait; force only after approval |
| Modified legacy Claude prompt | Preserve and report it |
| Isolated PR merge denied | Leave PR open; not READY |
| Matching runner online | Reuse it |
| Configured runner lacks label | Add label and reuse it |
| Configured runner offline | Start it; if still offline, not READY |
| Unrelated dirty files | Preserve them; land through the isolated worktree |
