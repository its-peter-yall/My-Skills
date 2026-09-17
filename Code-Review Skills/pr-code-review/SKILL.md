---
name: pr-code-review
description: Orchestrate a pull-request review from a local Git diff, using a direct review for changes under 100 reviewable lines and parallel phase reviewers for larger changes, then write phase, aggregate, and Slack-ready Markdown reports in the repository reviews directory.
---

# PR Code Review

Review the requested PR, branch, commit range, or current working branch. Produce review artifacts only; do not modify product code, post comments, send Slack messages, approve, merge, or reject a PR unless the user separately asks for that action.

## Required companion skill

Every actual code-review pass must load and follow `$code-review`. This skill owns orchestration, partitioning, reconciliation, verdicts, and final artifacts. `$code-review` owns review methodology and phase-report structure.

If `$code-review` cannot be found, stop before reviewing and tell the user that the companion skill must be installed beside this skill.

## Start the review

1. Resolve the review target and base. Prefer an explicit PR number, base/head pair, or ref range. Otherwise infer the current branch against its configured upstream or repository default branch. Do not silently review an ambiguous range.
2. Read the repository's applicable agent instructions and review configuration.
3. Inspect the complete diff and changed-file list before deciding the execution path.
4. Derive a filesystem-safe `PR_Name`. Prefer `PR-<number>-<short-title>` when PR metadata exists; otherwise use `<base>-to-<head>`. Replace unsafe characters with hyphens.
5. Create `./reviews/<PR_Name>/`. Preserve unrelated existing files. If artifacts for the same review already exist, replace only the three expected report types after confirming they correspond to the same base and head revisions.
6. Compute reviewable changed lines as additions plus deletions from non-binary files. Include source, tests, migrations, configuration, schemas, and behavior-bearing scripts. Exclude vendored/generated files, compiled output, dependency lockfiles, snapshots, and documentation-only changes unless they affect runtime behavior. Record both the raw diff totals and the reviewable total in the aggregate report.

Read [references/orchestration.md](references/orchestration.md) for delegation, partitioning, failure handling, and reconciliation. Read [references/artifact-contracts.md](references/artifact-contracts.md) before writing aggregate artifacts.

## Choose the execution path

### Small change: fewer than 100 reviewable changed lines

Do not spawn subagents.

Load `$code-review` in the main agent, review the entire diff as one phase named `Full-PR`, and write:

- `./reviews/<PR_Name>/Full-PR-Review.md`
- `./reviews/<PR_Name>/Review-Report.md`
- `./reviews/<PR_Name>/Slack-Report.md`

The aggregate reports may reuse verified facts from the full-PR review, but must still follow their distinct contracts.

### Large change: 100 or more reviewable changed lines

Use delegation when the environment supports it.

1. Spawn one exploration subagent first. Give it the base/head revisions and complete changed-file list. Ask it to inspect all changes and return a concise implementation map: PR intent, behavior added or changed, affected subsystems, cross-cutting dependencies, migrations or compatibility surfaces, test changes, and likely risk boundaries. It must not write a phase report or issue a verdict.
2. Combine the exploration summary with the main agent's diff inspection. Partition the PR into cohesive, non-overlapping review phases based on behavior and risk, not arbitrary file counts.
3. Spawn one reviewer subagent per phase and run them in parallel. Each assignment must require the subagent to load `$code-review`, identify its unique output path, list its owned files/hunks or behavior, name relevant adjacent code it may inspect for context, and state the shared base/head revisions.
4. Each reviewer writes exactly one unique `./reviews/<PR_Name>/<Phase_Name>-Review.md`. Reviewers may inspect the whole repository, but must report only defects introduced by or materially exposed through their assigned phase.
5. Wait for every phase. Retry a failed phase once only when the failure is incidental and retrying is safe. If a phase remains incomplete, do not silently infer its findings. Mark coverage incomplete in both aggregate artifacts and do not return `ACCEPTED`.
6. Read every phase report, verify material findings against code, deduplicate by root cause, reconcile conflicting severities, then write `Review-Report.md` and `Slack-Report.md`.

If subagents are unavailable, review the phases sequentially in the main agent with `$code-review`, state the limitation in `Review-Report.md`, and keep the same artifact contract. Do not omit coverage solely because parallelism is unavailable.

## Verdict policy

Use only these final verdicts:

- `ACCEPTED`: all planned phases completed and no confirmed `CRITICAL` or `MODERATE` findings remain. `MINIMAL` findings may be present because they are non-blocking.
- `REJECTED`: at least one confirmed `CRITICAL` or `MODERATE` finding exists, or required review coverage is incomplete.

Every issue must have exactly one severity: `CRITICAL`, `MODERATE`, or `MINIMAL`. Do not inflate severity because a finding sounds undesirable. Follow the definitions in the companion `$code-review` skill.

## Completion check

Before finishing, confirm that:

- every planned phase has one readable phase report;
- every aggregate finding traces to one or more phase finding IDs;
- file and line references point to the reviewed head revision;
- duplicate symptoms are merged under one root cause;
- verdict logic matches the policy above;
- `Slack-Report.md` is self-contained and ready to paste into Slack;
- no product code or unrelated repository files were changed by the review.
