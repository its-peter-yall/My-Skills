# Reviewer assignment

Review only the assigned part for the concern files attached to your assignment. Read each selected concern file before inspecting code. You may inspect other parts to understand callers, contracts, or safeguards, but report findings only for code owned by your assigned part. Do not broaden the concern set yourself.

Read applicable repository instructions. Work incrementally from the assigned path inventory and targeted searches; do not dump the whole repository or large directories into context. Read owned code and the relevant tests and contracts needed for each selected concern. Trace plausible execution and usage paths instead of treating search matches as proof. Check relevant framework conventions, entry-point registration, dynamic wiring, tests, and configuration before confirming any candidate. Prefer high-confidence, actionable findings with concrete impact. Do not report style preferences, speculation, or the same root cause twice. If evidence is incomplete, record an open question rather than a confirmed finding. If the assigned part is too large to review reliably, stop and request a finer split rather than silently sampling it.

The review is read-only for source, tests, and configuration. Do not fix code, change dependencies, commit, push, post comments, or run commands with side effects. Focused tests or static checks are allowed only when safe and useful; document what ran. Write exactly one Markdown report at the assigned destination; create only its parent directory if needed. Do not overwrite an unrelated existing report.

Use this report structure:

```markdown
# <part_name> review

## Scope
- Owned paths: ...
- Selected concerns: ...
- Context inspected: ...

## Confirmed findings
### <part_name>-001 — <short title>
- Concern: ...
- Severity: High | Medium | Low
- Evidence: `path:line` and the specific usage or execution path
- Impact: ...
- Suggested direction: ...

## Open questions
- ...

## Validation and coverage
- Checks run and results: ...
- Coverage limitations: ...
```

Use `No confirmed findings` when appropriate. Severity reflects plausible impact, not repair effort: High means serious correctness, security, data, or availability risk; Medium means a meaningful reliability, performance, or maintenance problem; Low means a concrete limited-impact issue. Include line references for confirmed findings and explain evidence from other files when the conclusion depends on them. Do not claim exhaustive coverage when time, tooling, or access limited the review.

After writing the report, reply only with completion status, your `part_name`, and the report path. In a separate chat, give this status to the user to relay to the orchestrator. Do not send findings in the status message; the orchestrator does not read reviewer work.
