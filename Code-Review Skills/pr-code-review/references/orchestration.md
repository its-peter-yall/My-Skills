# Orchestration and reconciliation

## Exploration assignment

For a large PR, the exploration subagent receives the full diff range and changed-file list. Its response should cover:

1. the user-visible or system-level goal of the PR;
2. behavior added, removed, or changed;
3. affected subsystems and important call or data flows;
4. API, schema, migration, persistence, security, concurrency, and compatibility surfaces;
5. tests added or changed and conspicuous untested behavior;
6. a proposed phase map with dependencies between phases.

The explorer maps the implementation; it does not perform the authoritative review, write artifacts, or assign a verdict.

## Phase design

A phase should be independently reviewable and cohesive. Prefer behavioral boundaries such as `Authentication-and-Authorization`, `Database-Migration`, `API-Contract`, `Async-Worker`, or `Frontend-State`.

- Give every changed reviewable hunk exactly one owning phase.
- Allow reviewers to inspect shared or unchanged files for context.
- Keep tightly coupled producer/consumer changes together.
- Isolate migrations, permission boundaries, external APIs, concurrency, and money/data-integrity paths when they warrant focused attention.
- Avoid one phase per file when several files implement one behavior.
- Avoid phases so broad that a reviewer cannot trace the relevant paths thoroughly.
- Use a short filesystem-safe phase name. Resolve collisions before spawning agents.

The main agent should retain a phase manifest in working context containing phase name, owned files or hunks, behavioral responsibility, important dependencies, and output path.

## Reviewer assignment contract

Each reviewer prompt should contain:

```text
Load and follow $code-review.
Review range: <base>...<head>
PR intent: <concise intent>
Phase: <phase-name>
Owned scope: <files/hunks/behavior>
Context dependencies: <adjacent paths or phases>
Write exactly: ./reviews/<PR_Name>/<phase-name>-review.md
Do not modify product code or write aggregate reports.
```

Parallel agents must never share an output file.

## Reconciliation

After every phase finishes, the main agent must read the report files themselves rather than relying only on completion messages.

For each material finding:

1. open the cited code at the reviewed head revision;
2. confirm the triggering path and absence of an existing safeguard;
3. normalize file paths and lines;
4. adjust severity when the impact or likelihood was overstated or understated;
5. merge duplicates that share one root cause, retaining all source finding IDs;
6. keep distinct defects separate even when they affect the same file;
7. move unresolved hypotheses to open questions rather than presenting them as confirmed.

If reviewers disagree, prefer code evidence and reproducible behavior. Document any consequential reconciliation decision in the aggregate report.

## Failure and coverage handling

- A phase is complete only when its report exists and includes scope, validation, findings, and limitations.
- Retry an incidental failed review once. Do not loop indefinitely.
- When coverage is incomplete, list the missing phase and reason.
- Incomplete required coverage forces `REJECTED`; phrase it as a review limitation, not a confirmed code defect.
- Do not erase successful phase reports when one phase fails.
