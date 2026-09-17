---
name: code-review
description: Perform a risk-first review of an assigned pull-request scope, validate high-confidence defects in repository context, and write one structured phase review with CRITICAL, MODERATE, or MINIMAL findings. Use for reviewer-agent passes, not PR orchestration or final aggregation.
---

# Code Review

Review the assigned change scope for defects and engineering risk. This skill is the reviewer contract used by `$pr-code-review`; it does not partition PRs, aggregate other reviewers, choose the final PR verdict, modify product code, or publish review comments.

## Required inputs

The assignment should provide:

- base and head revisions or an unambiguous diff range;
- phase name and unique report path;
- owned files, hunks, or behavior;
- PR intent or an exploration summary when available.

If the range or owned scope is ambiguous, ask the orchestrator for clarification before writing a report. You may inspect callers, callees, tests, schemas, configuration, and adjacent modules outside the phase to understand impact. Report only issues caused by or materially exposed through the assigned change.

## Review method

Read [references/review-method.md](references/review-method.md) and follow it. Prioritize concrete risk over style. Validate each candidate finding against repository context and existing safeguards. Run focused tests, linters, type checks, or static analysis when they materially increase confidence and can be run safely.

Do not change implementation files, fix defects, post comments, or send messages. The only permitted repository write is the assigned phase-review Markdown file.

## Finding threshold

Report a finding only when all of the following are true:

1. The changed code introduces or exposes a specific failure, vulnerability, compatibility break, or meaningful maintenance risk.
2. The triggering path or condition is plausible and supported by code evidence.
3. Existing validation, error handling, tests, or framework behavior do not already neutralize it.
4. The report can explain the impact and a concrete remediation direction.

Do not report personal style preferences, speculative possibilities without a reachable path, pre-existing defects unrelated to the change, or missing tests without explaining the behavior that could regress.

## Severity

- `CRITICAL`: credible risk of security compromise, unrecoverable or widespread data loss/corruption, major production outage, or a fundamental correctness failure on a primary path. Must block acceptance.
- `MODERATE`: reproducible correctness, reliability, performance, compatibility, or maintainability defect with meaningful user or operational impact. Should block acceptance until fixed or explicitly waived.
- `MINIMAL`: real but limited-impact issue, narrow edge case, small test gap tied to a concrete regression risk, or low-cost hardening opportunity. Non-blocking by default.

Severity reflects impact and likelihood, not fix size. When evidence is insufficient, put the item under `Open Questions / Unverified Risks` instead of promoting it to a finding.

## Output

Read [references/phase-report.md](references/phase-report.md) and write exactly one report to the path assigned by the orchestrator, normally:

`./reviews/<PR_Name>/<Phase_Name>-Review.md`

Use stable finding IDs of the form `<PHASE_SLUG>-001`. Include `No confirmed findings` when appropriate. Always document what was inspected, what validation ran, and any coverage limitation. Return a short completion message with the report path and finding counts; leave aggregation and the final verdict to the orchestrator.
