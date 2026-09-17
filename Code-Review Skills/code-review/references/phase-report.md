# Phase review artifact

Write the assigned report in this structure:

```markdown
# Phase Review: <Phase_Name>

## Assignment
- Review range: <base>...<head>
- Owned scope: <files, hunks, or behavior>
- Context inspected: <adjacent files or systems>

## Phase summary
<What this phase changes and how it fits the PR intent.>

## Findings

### <PHASE_SLUG-001> [CRITICAL|MODERATE|MINIMAL] <Concise title>
- Location: `<path>:<line or range>`
- Changed behavior: <what the diff now does>
- Trigger: <input, state, sequence, or workload>
- Evidence: <relevant control/data flow and why safeguards do not prevent it>
- Impact: <specific user, data, security, performance, or operational consequence>
- Recommendation: <concrete remediation direction without editing the code>
- Validation: <test, command, trace, or static reasoning>
- Confidence: <high|medium>

## Open questions / unverified risks
- <Question, missing fact, or environment-dependent concern>

## Validation performed
- `<command or inspection>`: <outcome>

## Coverage limitations
- <Anything not validated, or `None`.>

## Phase disposition
<No blocking findings | Blocking findings present | Review incomplete>
```

## Rules

- Use repository-relative paths and head-revision line numbers when possible.
- Sort findings by severity, then by source location.
- Do not use `low` confidence. Move low-confidence concerns to open questions.
- If there are no findings, write `No confirmed findings.` under `## Findings`.
- `Blocking findings present` means at least one `CRITICAL` or `MODERATE` finding.
- `Review incomplete` means material assigned scope could not be inspected or validated.
- Never issue the final PR verdict in a phase report.
