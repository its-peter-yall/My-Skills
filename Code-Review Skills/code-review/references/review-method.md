# Risk-first review method

## 1. Understand the change

- Read the assigned diff and the PR intent before judging individual lines.
- Read applicable repository instructions, tests, and surrounding implementation.
- Trace changed inputs, outputs, state transitions, external effects, and error paths.
- Distinguish newly introduced behavior from pre-existing code.

## 2. Inspect risks in priority order

### Correctness and runtime safety

Look for invalid assumptions, wrong branches, missing states, boundary errors, nullability mistakes, exception leaks, resource lifecycle problems, and behavior that contradicts the intended contract.

### Data integrity and side effects

Check transactional boundaries, partial failure, retry behavior, idempotency, duplicate operations, ordering, persistence semantics, destructive operations, and cleanup.

### Security and access control

Trace authentication, authorization, tenant or object ownership, input validation, injection paths, secret handling, sensitive logging, unsafe deserialization, and trust boundaries. Report only credible reachable vulnerabilities.

### Concurrency and distributed behavior

Inspect race conditions, stale reads, locking, reentrancy, cancellation, timeouts, retries, message delivery semantics, and cross-process consistency where relevant.

### Performance and resource use

Look for N+1 queries, unbounded work or memory, repeated network/database calls, blocking work on hot paths, inefficient algorithms at realistic scale, missing pagination, and cache invalidation issues. Tie findings to a plausible workload.

### Compatibility and contracts

Check public APIs, events, schemas, serialization, configuration, CLI behavior, migrations, rollout order, backward compatibility, and callers that may still depend on old behavior.

### Architecture and maintainability

Report design concerns only when they create a concrete risk such as duplicated business rules, broken ownership boundaries, hidden coupling, an unreachable migration path, or code that cannot be safely operated or tested.

### Tests and observability

Confirm that tests exercise meaningful changed behavior and failure paths. Check whether operators can detect and diagnose failures. Missing tests are findings only when connected to a specific regression risk.

## 3. Validate suspected findings

For every candidate:

1. identify the exact changed behavior and trigger;
2. inspect relevant callers, callees, types, schema, configuration, and framework guarantees;
3. search for guards or compensating behavior;
4. run the smallest useful test or static check when practical;
5. state what is proven and what remains inferred;
6. discard the candidate if evidence does not support a plausible impact.

Do not assume a function name, comment, or test name proves behavior. Prefer executable evidence and direct code paths.

## 4. Keep the review scoped

- You may inspect outside the assigned phase for context.
- Report only issues introduced by or materially exposed through owned changes.
- Mention cross-phase dependencies in the report, but do not duplicate another phase's defect.
- Place uncertain or environment-dependent concerns under open questions.
- Never broaden the task into refactoring or implementation work.
