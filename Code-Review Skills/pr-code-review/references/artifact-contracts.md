# Aggregate artifact contracts

## `Review-Report.md`

Write a technical, evidence-backed report with this structure:

```markdown
# PR Review Report: <PR_Name>

## Review metadata
- Target: <PR/ref>
- Base revision: <sha>
- Head revision: <sha>
- Generated: <ISO-8601 timestamp>
- Raw diff: <files, additions, deletions>
- Reviewable changed lines: <count>
- Execution: <direct | delegated parallel | sequential fallback>

## Purpose and implementation summary
<What the PR is trying to accomplish and how it does so.>

## Scope and phase coverage
| Phase | Owned scope | Report | Status |
| --- | --- | --- | --- |

## Verdict
**ACCEPTED** or **REJECTED**

<One concise evidence-based rationale.>

## Confirmed findings
### <AGG-001> [CRITICAL|MODERATE|MINIMAL] <Title>
- Source findings: <phase IDs>
- Location: `<path>:<line or range>`
- Evidence: <reachable trigger and relevant code behavior>
- Impact: <consequence and affected users/systems>
- Recommendation: <actionable remediation direction>
- Validation: <command, test, trace, or static reasoning used>

## Open questions / unverified risks
<Items requiring information or execution not available to the review.>

## Validation performed
<Commands/checks and outcomes.>

## Coverage limitations
<Missing phases, unrun tests, unavailable services, or `None`.>

## Reconciliation notes
<Material deduplication or severity decisions, or `None`.>
```

Sort confirmed findings by severity (`CRITICAL`, `MODERATE`, `MINIMAL`), then by affected path. If none exist, say `No confirmed findings.` Do not hide minimal findings because the verdict is accepted.

## `Slack-Report.md`

Make this self-contained, comprehensive, and easy to scan in Slack. Do not assume readers will open `Review-Report.md`.

```markdown
*PR Code Review: <PR_Name>*

*What this PR is about*
<Goal and business/system context.>

*What changed*
• <Key implementation point>
• <Key implementation point>

*Review coverage*
<Phases reviewed, important validation, and any limitations.>

*Verdict: ACCEPTED|REJECTED*
<Short rationale.>

*Issues found (<total>)*
• `[CRITICAL]` <title> — `<path>:<line>` — <impact and required action>
• `[MODERATE]` ...
• `[MINIMAL]` ...

*Recommended next steps*
1. <Ordered action>
2. <Ordered action>
```

Use Slack-compatible bullets and emphasis. Do not use Markdown tables in this file. When there are no findings, write `• No confirmed issues.` When coverage is incomplete, state it prominently beneath the verdict and list the unreviewed phase.

## Consistency requirements

- The PR identity, base/head revisions, finding counts, severities, and verdict must match across aggregate files.
- `Slack-Report.md` may shorten explanations but may not change their meaning.
- Aggregate finding IDs should be `AGG-001`, `AGG-002`, and so on.
- Every aggregate finding must cite its originating phase finding ID or IDs.
- Do not include secrets, tokens, internal credentials, or sensitive runtime output in either report.
