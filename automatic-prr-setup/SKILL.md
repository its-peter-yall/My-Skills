---
name: automatic-prr-setup
description: Set up automatic Claude Code pull-request review on this Windows PC as a self-hosted GitHub Actions runner. Installs workflow files, GitHub CLI if needed, registers a current-user runner, and lands the workflow on the default branch. Use when the user invokes automatic-prr-setup or wants out-of-the-box PR review on this machine.
---

# Automatic PR review setup

Make **this Windows PC** review same-repository pull requests. File install alone is not success.

Canonical skill directory: the folder that contains this `SKILL.md`. Resolve it from the loaded skill path. Scripts live in `scripts/` relative to that folder.

## READY (all required)

Say READY only when every item is true:

1. `git`, `gh`, and `claude` are on PATH for the current Windows user.
2. `gh auth status` and `claude auth status` succeed for that user.
3. `gh api repos/<owner>/<repo>/actions/runners` lists an **online** runner whose labels include both `self-hosted` and the chosen label.
4. That runner runs as this user (logon scheduled task + `run.cmd`), not `NETWORK SERVICE`.
5. `.github/workflows/automatic-prr.yml` and `.github/claude/prompts/pr-review.md` exist on the repository **default branch**.

If any item fails, say **not READY** and stop. Do not dump a leftover-prerequisites list as if setup succeeded.

## Boundaries

- This machine is the runner. Do not switch to GitHub-hosted `ubuntu-latest` or `anthropics/claude-code-action`.
- Never enable forked pull requests on this persistent runner. Keep the workflow `if` that rejects drafts and `head.repo.full_name != github.repository`.
- Do not store registration tokens, PATs, or Claude credentials in git.
- Do not change branch protection or create GitHub Apps.
- Do not silent-install or upgrade Claude Code.
- Do not overwrite managed files that differ unless you showed the diff and the user approved `--force` / `-Force`.
- Do not delete or `--replace` an existing runner without explicit confirmation.
- Do not merge unrelated feature branches (including `phase-4-voice-layer`) to land the workflow.
- Do not put the runner application inside a git working tree.
- Do not copy this skill tree into the application repository as part of invoke.
- Do not commit, push, or merge anything except the two managed workflow files on an isolated branch from default (step 9).

Human-only gates: `gh auth login` and `claude auth login`. After those succeed, finish the rest.

## Procedure

1. Confirm a Git working tree. Report the current branch. Stop on detached HEAD. Inspect `git status --short` and preserve unrelated user changes.

2. Runner label: the single `$ARGUMENTS` value if provided, otherwise `claude-review`. Accept only letters, digits, `_`, `-`, and `.`.

3. From the skill directory on Windows run:

   ```powershell
   powershell -NoProfile -File "<skill>/scripts/ensure-tools.ps1"
   ```

   If `claude` is missing, stop with the official Claude Code install URL. Do not winget-install Claude Code. `ensure-tools.ps1` may install GitHub CLI via winget.

   On POSIX, require `git`, `gh`, and `claude` already on PATH. This revision does not register a Linux runner.

4. Run `gh auth status` and `claude auth status` (read-only first). If `gh` is unauthenticated, run `gh auth login` (HTTPS). If `claude` is unauthenticated, run `claude auth login`. If either still fails: **stop, not READY**.

5. Inspect these paths in the application repo:

   - `.github/workflows/automatic-prr.yml`
   - `.github/claude/prompts/pr-review.md`

6. Install files **without** force. `setup.ps1` / `setup.sh` must not require `gh` or `claude`.

   ```powershell
   powershell -NoProfile -File "<skill>/scripts/setup.ps1" -RunnerLabel "<label>"
   ```

   ```bash
   bash "<skill>/scripts/setup.sh" --runner-label "<label>"
   ```

7. If the installer exits 3, show a concise diff of both managed files. Ask whether to replace them. Only after explicit yes, rerun with `-Force` / `--force`.

8. `git add -N` the two paths if untracked, then:

   ```bash
   git diff --check -- .github/workflows/automatic-prr.yml .github/claude/prompts/pr-review.md
   ```

9. Register or reuse the runner:

   ```powershell
   powershell -NoProfile -File "<skill>/scripts/register-runner.ps1" -RunnerLabel "<label>"
   ```

   Skip registration when an **online** runner already has `self-hosted` and the chosen label. If the runner directory is configured but offline, start it; do not `--replace` without confirmation. After this step the API must show the runner **online** or **stop, not READY**. Registration tokens stay in memory; never write them into the repo or skill folder.

10. Land the two managed files on the **default branch** without merging feature work:

    - `git fetch origin`
    - Default branch: `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`
    - `git worktree add -b chore/automatic-prr-setup "%LOCALAPPDATA%\Temp\opencode\automatic-prr-setup-land" "origin/<default>"` (create the parent directory if needed)
    - In that worktree only, run `setup.ps1`/`setup.sh` with the same label (use `-Force` if the default branch already has different managed files **and** the user approved replacing them)
    - Commit **only** those two files. Push. `gh pr create` targeting the default branch.
    - Merge that PR if it contains only those two files and `gh` permits. If merge is denied, leave the PR open and **not READY**.
    - `git worktree remove` the land worktree. Do not switch the user’s original dirty checkout.

11. Report READY with: landing branch, PR URL, runner name, API status `online`, label, and that this Windows user must stay logged in. Recommend a local smoke test only if the user wants to spend a Claude invocation. Use model `sonnet` and the same placeholders as the workflow:

    ```powershell
    $PR_NUMBER = gh pr view --json number --jq .number
    $PR_SHA = git rev-parse HEAD
    $BASE_SHA = gh pr view --json baseRefOid --jq .baseRefOid
    $REPOSITORY = gh repo view --json nameWithOwner --jq .nameWithOwner
    $MODEL = "sonnet"
    $prompt = Get-Content -Raw .github/claude/prompts/pr-review.md
    $prompt = $prompt.Replace('{{PR_NUMBER}}', $PR_NUMBER)
    $prompt = $prompt.Replace('{{PR_SHA}}', $PR_SHA)
    $prompt = $prompt.Replace('{{BASE_SHA}}', $BASE_SHA)
    $prompt = $prompt.Replace('{{REPOSITORY}}', $REPOSITORY)
    claude -p $prompt --model $MODEL --permission-mode dontAsk --setting-sources user --no-session-persistence
    ```

The workflow checks out and verifies `github.event.pull_request.head.sha`, rejects drafts and fork PRs, pins `actions/checkout` to SHA `3d3c42e5aac5ba805825da76410c181273ba90b1`, uses `shell: pwsh`, `MODEL: "sonnet"`, avoids persisted checkout credentials, cancels superseded reviews, and invokes Claude with project/local settings excluded.

## Errors

| Case | Result |
| --- | --- |
| Not a git repo or detached HEAD | Stop |
| Invalid runner label | Stop |
| `git` missing | Stop |
| `claude` missing | Stop with install command |
| `gh` missing | `ensure-tools.ps1` installs via winget; if that fails, stop with https://cli.github.com/ |
| Auth fails after login | Stop, not READY |
| Registration token 403 | Stop: repository admin required for self-hosted runners |
| Managed files differ | Diff + wait; force only after yes |
| Isolated PR merge denied | PR left open; not READY |
| Matching runner already online | Skip register; continue landing files |
| Configured runner offline | Start `run.cmd`; if still offline, not READY |
| Unrelated dirty files | Leave them; land via worktree |
