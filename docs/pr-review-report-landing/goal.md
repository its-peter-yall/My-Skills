# PR review report landing

## Goal

Change automatic PR review so Markdown reports use a PR-number folder, are committed onto the **PR source branch** by the workflow (not by the harness), and the contents of `slack-report.md` are posted as a pull-request comment — all with **no human in the loop**.

This supersedes the artifact-path and comment-authorship parts of `docs/pr-review-skill-initialization/goal.md` and the `contents: read` / job-wide `GH_TOKEN` permission lines in `docs/harness-independent-pr-review/goal.md`. Draft/fork rejection, exact-SHA checkout, checkout pin, `persist-credentials: false`, per-PR concurrency, and harness CLI flags stay in force.

## Approved decisions

- Parent directory: `reviews/` (unchanged).
- Inner directory: PR number digits only, for example `reviews/142/`. No title, no `PR-` prefix.
- Required Slack/PR-comment file name: exactly `slack-report.md`.
- Other reports in the same folder, lowercase kebab-case: `review-report.md`, `full-pr-review.md`, `<phase>-review.md`.
- Persist reports by **committing them onto the PR source branch** (the branch the pull request was opened from). Not Main, not `chore/…`.
- Also post the **verbatim** body of `slack-report.md` as a GitHub PR **comment** (`gh pr comment`). Do not approve, request changes, dismiss reviews, or otherwise use GitHub review actions.
- Do **not** have the harness commit, push, or call `gh`. The workflow owns git and GitHub after the harness exits.
- Strictly no HITL: no permission dialogs, no GitHub account picker, no interactive `git`/`gh` login, no waiting for a person.

## Architecture

The job checks out the PR head SHA, attaches the PR source branch, and reviews **base…head** in that checkout. After a successful review, only `reviews/<PR_NUMBER>/` is committed and pushed to that same branch.

```text
PR event (same-repo, non-draft)
  → skip if HEAD is already this job's report commit (loop guard)
  → checkout exact PR SHA, attach source branch
  → harness writes only reviews/<PR_NUMBER>/*.md
       (no GH_TOKEN, no git commit/push, no gh)
  → workflow with GITHUB_TOKEN:
       discard any non-report dirty files
       commit + push only reviews/<PR_NUMBER>/
       comment with slack-report.md
```

`GITHUB_TOKEN` pushes often do not retrigger workflows. Implement the loop guard anyway so a retrigger cannot review-and-commit forever.

## Token and permission split

- Do **not** set `GH_TOKEN` at job level.
- The harness step must not receive `GITHUB_TOKEN` / `GH_TOKEN`.
- Checkout stays `persist-credentials: false`.
- The land+comment step is the only step that receives `GITHUB_TOKEN`.
- Workflow permissions: `contents: write`, `pull-requests: write`. Drop `issues: write`.
- Do not fall back to the interactive user's `gh auth` if the token fails.
- Never print the token. Push with an `x-access-token` URL (or equivalent non-interactive remote) only inside that step.
- Never `--force` push. Never bypass branch protection.

## Workflow steps

Keep a single `review` job.

1. **Guards** — existing draft and fork rejection. After checkout, skip the rest of the job (success, not failure) when HEAD's commit message is exactly `chore(review): reports for #<PR_NUMBER>` **and** that commit touches only paths under `reviews/<PR_NUMBER>/`.
2. **Checkout** — existing pinned `actions/checkout`, `ref: PR head SHA`, `fetch-depth: 0`, `persist-credentials: false`, then `git switch -C $PR_BRANCH $PR_SHA` with SHA re-check.
3. **Prerequisites** — `git --version` and selected harness `--version` only. Remove `gh --version` / `gh auth status` from this step; the harness no longer uses `gh`.
4. **Review** — existing harness dispatcher and non-interactive flags. No token in the environment. Timeout remains 45 minutes.
5. **Land + comment** — `GITHUB_TOKEN` only:
   - Fail if `reviews/<PR_NUMBER>/slack-report.md` is missing or empty.
   - Fail if the other required reports for the chosen execution path are missing (`review-report.md` plus `full-pr-review.md` on the small path, or every planned `<phase>-review.md` on the large path).
   - Restore/clean the worktree so nothing except `reviews/<PR_NUMBER>/` remains staged or dirty.
   - Stage only `reviews/<PR_NUMBER>/`.
   - Commit as `github-actions[bot]` (`41898282+github-actions[bot]@users.noreply.github.com`) with message `chore(review): reports for #<PR_NUMBER>`.
   - If there is no staged diff, skip commit and push; still post the comment unless this HEAD is already the matching report commit (then skip the comment too, to avoid duplicates).
   - Push `HEAD:refs/heads/<PR_BRANCH>` to `github.repository`. Fast-forward only.
   - `gh pr comment <PR_NUMBER> --body-file reviews/<PR_NUMBER>/slack-report.md` using `GITHUB_TOKEN`. No Slack delivery. No markdown conversion.

The workflow does not read ACCEPTED/REJECTED. Verdicts live in the Markdown. The comment is the slack-report body as-is.

## Prompt and skill contracts

### Managed prompt (`.github/automatic-prr/pr-review.md`)

Keep PR identity, repository, exact head SHA, expected base SHA, and the stale-head stop rule.

Instruct the harness to load `pr-code-review` (and its `code-review` companion) and review only this PR's base…head changes.

Require Markdown under `reviews/<PR_NUMBER>/` with `slack-report.md` as the exact Slack-ready filename. Preserve unrelated files.

Prohibit product-code edits, other repository writes, commits, pushes, merges, approvals, closing the PR, PR metadata changes, GitHub comments, GitHub review actions, and sending Slack messages. Comment posting is the workflow's job after the harness exits.

### `pr-code-review` and `code-review` (source under `Code-Review Skills/`)

When a PR number is known, `PR_Name` is that number and the directory is `./reviews/<PR_NUMBER>/`.

When no PR number exists (local/manual review), use `./reviews/<base>-to-<head>/` with the same lowercase filenames. Automatic PRR always has a number.

Rename artifacts:

| Role | Path |
| --- | --- |
| Slack / PR-comment body | `./reviews/<PR_Name>/slack-report.md` |
| Aggregate technical report | `./reviews/<PR_Name>/review-report.md` |
| Small-change single phase | `./reviews/<PR_Name>/full-pr-review.md` |
| Large-change phase | `./reviews/<PR_Name>/<Phase_Name>-review.md` |

Phase names stay filesystem-safe; the suffix is `-review.md` (lowercase).

Agents still must not commit, push, or post comments. Only the assigned Markdown files may be written. Automatic landing is workflow-only.

Report **bodies** (sections, severities, verdicts, Slack-oriented formatting) stay as they are; this change is path, filename, publisher, and landing branch.

`automatic-prr-setup` continues to copy these skills **unchanged** from the source snapshot. Edit the skills in this repository; do not rewrite them during setup.

## Error handling

No step may wait for a human. Fail or skip, then stop.

| Situation | Result |
| --- | --- |
| Draft or fork | Skip job (existing) |
| HEAD is the report commit for this PR number and only `reviews/<PR_NUMBER>/` | Skip remaining steps; success |
| HEAD ≠ `PR_SHA` before review | Fail; do not write or push |
| Harness missing or `--version` fails | Fail; do not land |
| Harness exits non-zero | Fail; do not commit or comment |
| Harness dirtyed product files or other paths | Discard; only `reviews/<PR_NUMBER>/` may be committed |
| `slack-report.md` missing or empty | Fail land+comment; no commit; no comment |
| Other required reports missing | Fail land+comment; no commit; no comment |
| Push rejected (non-fast-forward or protection) | Fail; never `--force` |
| `gh pr comment` fails after a successful push | Fail the job; leave the pushed commit; do not retry the push |
| `slack-report.md` larger than GitHub's comment size limit | Fail the comment step after push; the committed file is the full record; do not truncate |
| Token or permission error | Fail; do not use user `gh auth` or interactive login |
| Harness blocks on HITL despite flags | Job times out at 45 minutes; do not wait on a person |

## Tests

Keep tests offline: no runner registration, no live GitHub API, no harness login, no model calls.

**automatic-prr-setup**

- Rendered prompt uses `reviews/{{PR_NUMBER}}/` (after substitution, a numeric folder), requires `slack-report.md`, and forbids harness commit, push, `gh`, product edits, and GitHub comments.
- Rendered workflow has no job-level `GH_TOKEN`; the harness step has no token; land+comment has `GITHUB_TOKEN`.
- Permissions are `contents: write` and `pull-requests: write` only.
- Loop-guard skip, exact report commit message, no `--force`, `persist-credentials: false`, draft/fork guards, and checkout pin still hold.
- Prerequisite step does not call `gh auth status`.
- Existing harness/model rendering tests still pass.

**Code-Review Skills**

- Path rules: numeric folder when a PR number exists; `<base>-to-<head>` otherwise.
- Required filenames match the table above.
- Agent contract still forbids commit/push/comment.

No live smoke PR is required in automated tests. Optional post-READY manual proof remains a tiny same-repo non-draft PR.

## Documentation

Update `automatic-prr-setup` `SKILL.md`, `README.md`, and `DESIGN.md` for: numeric report path, workflow-owned landing on the source branch, token split, permission change, and harness-must-not-post-comments.

Update `Code-Review Skills` skill text and references (`orchestration.md`, `artifact-contracts.md`, `phase-report.md`) for the new paths and filenames.

## Non-goals

- Landing reports on Main or on a `chore/…` branch.
- Committing product code or any path outside `reviews/<PR_NUMBER>/`.
- Harness-owned `git` / `gh`.
- Slack message delivery.
- Approving or rejecting the PR through GitHub review actions.
- Fork PR support, GitHub-hosted runners, harness login during setup, runner replacement behavior, or new harnesses.
- Changing review methodology, severity definitions, or verdict policy.
