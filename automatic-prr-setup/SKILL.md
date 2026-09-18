---
name: automatic-prr-setup
description: Set up automatic pull-request review with Claude Code, OpenCode, Cursor, or Codex on this Windows PC as a self-hosted GitHub Actions runner. Installs the selected CLI, initializes the pr-code-review and code-review skills, workflow files, GitHub CLI if needed, registers a current-user runner, and lands the workflow on the default branch.
---

# Automatic PR review setup

Make **this Windows PC** review same-repository pull requests with one user-selected coding harness. File installation alone is not success.

Canonical skill directory: the folder containing this `SKILL.md`. Scripts live in `scripts/` relative to it.

## READY (all required)

Say READY only when every item is true:

1. `git`, `gh`, `pwsh`, and the selected harness CLI are on PATH for the current Windows user.
2. `gh auth status` succeeds for that user.
3. `gh api repos/<owner>/<repo>/actions/runners` lists an **online** runner with both `self-hosted` and the chosen label, and the local listener is accepting work (`Listening for Jobs` in `_diag/Runner_*.log`, not a stale online API row while `TaskAgentSessionConflictException` is looping).
4. That runner runs as this user through a logon scheduled task and `run.cmd`, not `NETWORK SERVICE`. The task has an unlimited execution time limit.
5. `.github/workflows/automatic-prr.yml` and `.github/automatic-prr/pr-review.md` exist on the repository default branch.
6. Both complete `pr-code-review/` and `code-review/` skill folders from the selected source snapshot exist unchanged on the default branch under `.claude/skills/` for Claude Code, or `.agents/skills/` for OpenCode, Cursor, and Codex.

Harness authentication is deliberately not checked and is not part of READY. Always tell the user to authenticate the selected harness before expecting reviews to succeed. Do not run harness login or status commands.

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
- Commit, push, and merge only the managed workflow, generic prompt, source-backed files in the two initialized skill folders, and an exact-match legacy prompt deletion, using an isolated branch from default.
- Preserve unrelated skills and extra destination files. Do not stage whole skill directories blindly or rewrite the downloaded skills.

The only setup authentication gate is `gh auth login`. Harness login belongs to the user after setup.

## Migration from older installs

Existing machines may still use runner label `claude-review` and prompt path `.github/claude/prompts/pr-review.md`. The new default label is `automatic-prr` and the managed prompt path is `.github/automatic-prr/pr-review.md`. Relabel and reuse the already-configured runner. Do not pass `-Replace` / `--replace` without confirmation. Force-overwrite managed files only after showing the diff and receiving an explicit yes.

## Procedure

1. Confirm a Git working tree. Report the current branch. Stop on detached HEAD. Inspect `git status --short` and preserve unrelated changes.

2. Resolve the runner label from the single `$ARGUMENTS` value, or use `automatic-prr`. Accept only letters, digits, `_`, `-`, and `.`.

3. On Windows, ensure base tools:

   ```powershell
   powershell -NoProfile -File "<skill>/scripts/ensure-tools.ps1"
   ```

   This requires `git`. It installs GitHub CLI (`gh`) and PowerShell 7 (`pwsh`) with winget when missing. It prefers a real `pwsh.exe` directory (`C:\Program Files\PowerShell\7` or the WindowsApps package folder), not the 0-byte WindowsApps execution alias. On POSIX, require `git` and `gh`; this skill does not register a POSIX runner.

   After `ensure-tools.ps1` returns, prepend the printed `gh:` and `pwsh:` directories onto `$env:Path` in the **current agent session**. winget does not update parent shells; later `gh` / `pwsh` calls fail until you do this.

4. Run `gh auth status`. If unauthenticated, run `gh auth login` using HTTPS. If the agent TTY cannot show the device code, launch a **visible** PowerShell window, then poll status. Do not treat a hidden hung login as success:

   ```powershell
   Start-Process powershell -ArgumentList @(
     '-NoProfile',
     '-Command',
     'gh auth login --hostname github.com --git-protocol https --web'
   )
   do {
     Start-Sleep -Seconds 5
     gh auth status 2>$null | Out-Null
   } while ($LASTEXITCODE -ne 0)
   ```

   If it still fails, stop as not READY.

5. Ask the user to select exactly one review harness:

   - `claude` — Claude Code
   - `opencode` — OpenCode V2 CLI
   - `cursor` — Cursor Agent CLI
   - `codex` — OpenAI Codex CLI

6. Ask for an optional model ID. Trim surrounding whitespace. Blank means the CLI's configured default. Reject CR/LF, control characters, and values longer than 256 characters. Do not offer hard-coded model menus. Keep the downloaded review skills unchanged; model selection belongs to the harness invocation.

7. Install or verify only the selected harness CLI:

   ```powershell
   powershell -NoProfile -File "<skill>/scripts/ensure-harness.ps1" -Harness "<harness>"
   ```

   Official installers are used for missing CLIs. Do not run any harness login or status command. Workflow prerequisite checks stay `--version` only.

8. **Skill Initialization** — fetch both complete, unchanged skill folders from <https://github.com/its-peter-yall/My-Skills/tree/master/Code-Review%20Skills>:

   ```powershell
   $snapshot = Join-Path $env:LOCALAPPDATA ("Temp\opencode\automatic-prr-skills-" + [guid]::NewGuid().ToString('N'))
   powershell -NoProfile -File "<skill>/scripts/initialize-skills.ps1" -Harness "<harness>" -SnapshotDirectory $snapshot
   ```

   Claude Code installs `pr-code-review/` and `code-review/` under `.claude/skills/`. OpenCode, Cursor, and Codex install them under `.agents/skills/`. This shared layout also supports Antigravity, but Antigravity is not a selectable setup harness.

   Keep the reported `SOURCE_DIRECTORY`, `SOURCE_SHA`, and individual `MANAGED_PATH` entries. The snapshot is outside the target repository and must be retained until landing completes or setup aborts. Reuse it without downloading again:

   ```powershell
   powershell -NoProfile -File "<skill>/scripts/initialize-skills.ps1" -Harness "<harness>" -SourceDirectory $snapshot
   ```

   Exit 3 means existing skill files differ: review the printed diffs, ask for explicit approval, and rerun with `-SourceDirectory $snapshot -Force` only after approval. Other failures stop setup as not READY. Both skill trees are preflighted before copying. Preserve additional destination files, other skills, and installations for other harnesses. Never rewrite the downloaded skills or execute their contents during setup.

9. Inspect these application-repository paths:

   - `.github/workflows/automatic-prr.yml`
   - `.github/automatic-prr/pr-review.md`
   - `.github/claude/prompts/pr-review.md` (legacy migration only)
   - The source-backed `MANAGED_PATH` files under the selected harness's two skill folders

10. Install files without force, passing the exact selected values:

   ```powershell
   powershell -NoProfile -File "<skill>/scripts/setup.ps1" -RunnerLabel "<label>" -Harness "<harness>" -Model "<model>"
   ```

   ```bash
   bash "<skill>/scripts/setup.sh" --runner-label "<label>" --harness "<harness>" --model "<model>"
   ```

   Omit the model option when blank if the calling shell cannot preserve an empty argument. These file-only installers must not require `gh` or any harness CLI.

11. If the installer exits 3, show a concise diff of managed files. Ask whether to replace them. Rerun with `-Force` or `--force` only after explicit approval. A modified legacy Claude prompt is preserved without blocking setup.

12. Use intent-to-add for untracked managed files, then run `git diff --check` over the workflow, generic prompt, source-backed skill files, and legacy prompt when changed. Do not rewrite upstream skills to fix whitespace; report upstream whitespace warnings separately.

13. Register, relabel, or reuse the runner:

    ```powershell
    powershell -NoProfile -File "<skill>/scripts/register-runner.ps1" -RunnerLabel "<label>" -Harness "<harness>"
    ```

    Reuse an online matching runner that is actually listening. If the configured online runner lacks the chosen label, add it through GitHub's runner-label API. If `config.cmd` exists but `.runner` is missing, finish registration; do not skip config. If configured but offline, start it. Never replace it without confirmation. Never `Stop-Process -Force` on `Runner.Listener`. Download the runner zip with `curl.exe` (TLS 1.2, official asset URL first, SHA256 from `asset.digest`); on CDN TLS reset retry `--ipv4` then the hash-checked `gh-proxy.com` fallback. The logon scheduled task must keep `run.cmd` alive (unlimited `ExecutionTimeLimit`). READY requires API online **and** a local listener that is not stuck in a session-conflict retry.

14. Land managed changes on the default branch without merging feature work:

    - `git fetch origin`.
    - Read the default branch with `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`.
    - Create an isolated worktree under `%LOCALAPPDATA%\Temp\opencode\automatic-prr-setup-land` on `chore/automatic-prr-setup` from `origin/<default>`.
    - Run `initialize-skills.ps1 -Harness "<harness>" -SourceDirectory $snapshot` there, then the workflow/prompt installer with the same label, harness, and model. Do not fetch a new snapshot. Review any new conflicts on default; prior approval does not cover unseen differences.
    - Stage only the initializer's individual `MANAGED_PATH` entries, `.github/workflows/automatic-prr.yml`, `.github/automatic-prr/pr-review.md`, and an exact-match deletion of `.github/claude/prompts/pr-review.md` when present. Never stage entire skill directories containing unrelated extras. Verify staged skill bytes against the snapshot; if repository attributes would transform content, stop and report rather than silently changing the skills or attributes.
    - Commit, push, create a PR targeting default, verify its file list against that exact allowlist, and merge if permitted.
    - If merge is denied, leave the PR open and report not READY.
    - Verify both complete skill trees and the workflow/prompt exist on default. Remove the temporary worktree without switching the user's original checkout. Remove the retained snapshot after landing or aborting setup.

15. Report READY with landing branch, PR URL, runner name, API status `online`, label, harness, and selected model or `default`. Remind the user that this Windows account must remain logged in and that they must authenticate the harness separately.

Recommend a local smoke test only when the user wants to spend a harness invocation. Use the same rendered prompt and selected model behavior as the workflow; never silently run it.

After READY, recommend a tiny same-repo non-draft PR only if the user wants to prove job pickup. Do not merge feature branches for that proof.

## Harness invocation contract

The workflow passes the rendered prompt as one process argument and omits the model flag when model is blank:

```text
claude -p <prompt> [--model <model>] --permission-mode dontAsk --setting-sources user --no-session-persistence
opencode run --standalone --auto [--model <provider/model#variant>] <prompt>
cursor-agent -p --force --trust [--model <model>] <prompt>
codex exec --ephemeral --sandbox workspace-write -c sandbox_workspace_write.network_access=true [--model <model>] <prompt>
```

Cursor may use `agent` only after verifying it is Cursor Agent. Never invoke an unrelated executable named `agent`.

The workflow checks the exact PR SHA, rejects drafts and forks, pins `actions/checkout` to `3d3c42e5aac5ba805825da76410c181273ba90b1`, uses `pwsh`, avoids persisted checkout credentials, and cancels superseded reviews. The prerequisite step checks harness `--version` only, never harness login. The harness does not receive `GH_TOKEN` and must not commit, push, or comment. After a successful review the workflow commits only `reviews/<PR_NUMBER>/` onto the PR source branch and posts `slack-report.md` as a pull-request comment.

## Errors

| Case | Result |
| --- | --- |
| Not a git repo or detached HEAD | Stop |
| Invalid runner label, harness, or model | Stop |
| `git` missing | Stop |
| `gh` missing | Install via winget; stop with <https://cli.github.com/> if installation fails |
| `pwsh` missing | Install Microsoft.PowerShell via winget; prefer a real `pwsh.exe` directory |
| Selected harness missing | Install from the official source; stop if post-install verification fails |
| GitHub auth fails after login | Stop, not READY |
| Hidden `gh auth login` hung with no device code | Launch a visible PowerShell window; do not treat it as success |
| Harness unauthenticated | Do not check; remind the user in the final report |
| Cursor `agent` is another product | Ignore it; use or install `cursor-agent` |
| Registration token 403 | Stop: repository admin access is required |
| Official runner CDN TLS reset | `curl.exe` + hash-checked fallback; delete zip and fail on digest mismatch |
| Managed files differ | Diff and wait; force only after approval |
| Modified legacy Claude prompt | Preserve and report it |
| Isolated PR merge denied | Leave PR open; not READY |
| Matching runner online and listening | Reuse it |
| Configured runner lacks label | Add label and reuse it |
| `config.cmd` exists without `.runner` | Finish registration; do not skip config |
| Configured runner offline | Start it; if still offline, not READY |
| API online but session-conflict loop | Keep waiting; not READY from a stale online row |
| Unrelated dirty files | Preserve them; land through the isolated worktree |
