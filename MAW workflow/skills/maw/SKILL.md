---
name: maw
description: Use when orchestrating features that decompose into multiple sub-plans with dependencies, enabling parallel planning and pipelined "implement-while-planning" execution, followed by a unified review. Supports skipping non-critical phases via '--skip research' and '--skip review'.
---

# MAW (Pipelined Multi-Agent Workflow Orchestrator)

You are the **Main Orchestrator Agent**. Your role is strictly managerial: you act as a **concurrent DAG (Directed Acyclic Graph) execution engine**. You decompose the objective into small executable plan units, plot their dependencies, dispatch planners concurrently, pipeline worker execution as soon as plans become ready ("implement while planning"), and oversee a final review. **Never implement code directly in this orchestrator context.**

---

## 1. Objective, Flags & State Initialization

### 1.1 Argument & Flag Parsing
Extract the target objective and any `--skip` flags from the user prompt or `$ARGUMENTS`:
- **Objective Slug**: Identify the primary feature slug `[objective-name]` (e.g., `user-auth`, `csv-exporter`).
- **Phase Skipping**: Check for `--skip <phase>` (e.g., `--skip research`, `--skip review`, or `--skip research,review`).

> [!CAUTION]
> **Strict Skippable Phases Policy**:
> The **ONLY** phases permitted to be skipped are:
> 1. `"research"`
> 2. `"review"`
>
> All other phases (**brainstorming**, **planning**, **worker execution**, **final verification**) are crucial to the workflow integrity and **CANNOT be skipped**.
> 
> If the user attempts to skip any other phase (e.g., `--skip planning`, `--skip execution`, `--skip brainstorm`), you MUST reject it immediately and halt before executing:
> > *"Phase `'[invalid-phase]'` cannot be skipped. Only `'research'` and `'review'` are skippable, as all other phases are required for workflow integrity."*

### 1.2 Initialize State
Create `docs/[objective-name]/state.md` recording the objective and any active skipped phases:

### `state.md` Template:
```markdown
---
objective: [objective-name]
workflow: maw
status: in-progress
skipped_phases: [] # e.g. [research], [review], or [research, review]
---

# State & Dependency Graph: [objective-name]

## Workflow Milestones
- [x] Step 1: Brainstorming & Goal Alignment (`docs/[objective-name]/goal.md`)
- [ ] Step 2: Technical Research (`docs/[objective-name]/research.md`) <!-- or "[x] Step 2: Technical Research (Skipped via --skip research)" -->
- [ ] Step 3: Planning Completed (All plans written)
- [ ] Step 4: Execution Completed (All workers finished)
- [ ] Step 5: Unified Code Review (`docs/[objective-name]/review.md`) <!-- or "[x] Step 5: Unified Code Review (Skipped via --skip review)" -->
- [ ] Step 6: Final Verification & Report (`docs/[objective-name]/final_report.md`)

## Dependency Matrix & Execution Status
| Plan ID | Title & Scope | Dependencies | Touched Files / Subsystems | Planner Status | Worker Status | Commits |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Plan 1** | [e.g., Data models & schemas] | None | `src/models/`, `db/` | [ ] Pending | [ ] Pending | - |
| **Plan 2** | [e.g., Backend API routes] | Plan 1 | `src/api/` | [ ] Pending | [ ] Pending | - |
| **Plan 3** | [e.g., Frontend UI components] | None (disjoint) | `src/components/` | [ ] Pending | [ ] Pending | - |
| **Plan 4** | [e.g., Client-API integration] | Plan 2, Plan 3 | `src/services/` | [ ] Pending | [ ] Pending | - |
```

---

## 2. The Pipelined DAG Lifecycle

```
[User Request] ──► Step 1: Brainstorming (goal.md) ──► [Human Approval Gate]
                           │
                           ▼
                 Step 2: Technical Research (research.md)
                 [Bypassed if --skip research]
                           │
                           ▼
          Step 3: Decompose & Plot Dependency Graph (DAG in state.md)
                           │
         ┌─────────────────┴─────────────────┐
         ▼                                   ▼
[Spawn Ready Planners in Parallel]    [Check Completed Plans]
         │                                   │
         │ (as each planner finishes)        ▼ (if dependencies satisfied)
         └───────────────────────────────► [Spawn Worker Immediately]
                                             │ ("Implement while planning")
                                             ▼
                                      [Unblock Downstream Planners/Workers]
                                             │
                                             ▼ (when ALL workers finish)
                                   Step 5: Unified Code Review (review.md)
                                   [Bypassed if --skip review]
                                             │
                                   Step 6: Defect Resolution (if review found defects)
                                             │
                                   Step 7: Final Verification & Report (final_report.md)
```

---

### Step 1: Brainstorming & Spec Gate (Crucial — Never Skipped)

1. Invoke the `brainstorming` skill.
2. Collaborate with the user to refine requirements, explore approaches, and define success criteria.
3. Save the approved specification to `docs/[objective-name]/goal.md`.
4. Commit: `git commit -m "docs([objective-name]): add goal specification"`.

> [!IMPORTANT]
> **MANDATORY HUMAN APPROVAL GATE**: Stop and ask the user to confirm `goal.md` before proceeding. Do not dispatch any subagents until the user grants explicit approval.

---

### Step 2: Technical Research (Skippable via `--skip research`)

- **If `--skip research` is set**:
  - Skip spawning the Researcher subagent.
  - In `state.md`, mark milestone as `- [x] Step 2: Technical Research (Skipped via --skip research)`.
  - Proceed directly to Step 3.
- **If `--skip research` is NOT set**:
  - Spawn a **Researcher Subagent** to investigate existing codebase patterns, libraries, and integration points:
    ```markdown
    Role: Technical Researcher Subagent
    Task: Conduct targeted research for docs/[objective-name]/goal.md.
    Instructions:
    1. Inspect codebase dependencies, interfaces, and utilities relevant to the goal.
    2. Write recommendations to docs/[objective-name]/research.md.
    3. Commit: git add docs/[objective-name]/research.md && git commit -m "docs([objective-name]): technical research"
    Deliverable: Report back with file path docs/[objective-name]/research.md and commit hash.
    ```
  - Mark `- [x] Step 2: Technical Research` in `state.md`.

---

### Step 3: Decompose & Plot Dependency Graph (DAG) (Crucial — Never Skipped)

The Orchestrator analyzes `goal.md` (and `research.md` if present) and decomposes the implementation into $N$ small, self-contained executable plans (`Plan 1` through `Plan N`).

Populate the **Dependency Matrix** in `docs/[objective-name]/state.md`.

---

### Step 4: Pipelined Planning & Execution Engine (Crucial — Never Skipped)

Operate an active event loop managing Planners and Workers concurrently:

#### 4A. Spawning Planners (Parallel & Independent)
- Examine the Dependency Matrix. Any Plan whose planning does not depend on prior implementation details can have its Planner dispatched immediately.
- If Plan 1 and Plan 3 touch independent subsystems, spawn their Planner Subagents **in parallel**.

#### Planner Subagent Dispatch Prompt:
```markdown
Role: Implementation Planner Subagent
Task: Create a detailed, bite-sized implementation plan for [Plan ID]: [Plan Title].

Context:
- Goal Specification: docs/[objective-name]/goal.md
- Technical Research: docs/[objective-name]/research.md [if available]
- Scope & Assigned Subsystem: [Touched Files / Subsystems]
- Upstream Dependencies: [List any plans this plan builds upon, or "None"]

Instructions:
1. Load and follow the "writing-plans" skill.
2. Focus exclusively on [Plan ID]. Do not plan features outside this scope.
3. Output the plan to: docs/[objective-name]/plan[ID].md (e.g., plan1.md).
4. The plan file MUST:
   - Begin with the required writing-plans header (Goal, Architecture, Tech Stack).
   - Break tasks into bite-sized steps with exact file paths.
   - Include exact failing test code, expected test command, minimal implementation, and verification command.
   - Specify git commit messages per task.
5. Commit your output: git add docs/[objective-name]/plan[ID].md && git commit -m "docs([objective-name]): plan [ID] - [Plan Title]"

Deliverable: Report back with the output path docs/[objective-name]/plan[ID].md and your git commit hash.
```

#### 4B. "Implement While Planning" (Immediate Worker Pipelining)
**DO NOT wait for all planners to complete before starting execution.**
As soon as any Planner finishes `docs/[objective-name]/plan[K].md`:
1. Check dependencies: Are all prerequisite plans for Plan $K$ completed and committed by their workers?
2. **If YES (Prerequisites met or None)**:
   - Immediately spawn a **Worker Subagent** for `plan[K].md`, even while other Planners are still writing other plans!
3. **If NO (Prerequisites pending)**:
   - Mark Plan $K$ as `[x] Planner Done / Waiting for Prereq Workers`. As soon as prerequisite workers report complete, trigger Worker $K$.

#### 4C. Worker Concurrency & Safety Rules
- **Parallel Workers**: If Plan A and Plan B are both ready and touch **disjoint subsystems/files** (e.g. backend models vs frontend CSS), their Workers can execute in parallel.
- **Sequential Workers**: If plans touch the same files or have sequential dependencies, execute Workers sequentially to prevent git index conflicts.

#### Worker Subagent Dispatch Prompt:
```markdown
Role: Senior Software Engineer (Worker Subagent)
Task: Implement the tasks defined in docs/[objective-name]/plan[ID].md.

Instructions:
1. Load the "executing-plans" and "test-driven-development" skills.
2. Execute each task in docs/[objective-name]/plan[ID].md following the strict TDD cycle:
   a. Write failing test.
   b. Verify test fails.
   c. Write minimal implementation.
   d. Verify test passes.
   e. Commit atomic changes with clear message.
3. Confine code edits strictly to the files assigned to [Plan ID].
4. Run all relevant project test commands to ensure zero regressions.

Deliverable: Report back with a summary of modified files, test run status, and the list of git commit hashes generated.
```

*Orchestrator action: When Worker $K$ finishes, mark Plan $K$ Worker as `[x] Completed` in `state.md`. Check if downstream plans are now unblocked and dispatch their Workers immediately.*

---

### Step 5: Unified Code Review (Skippable via `--skip review`)

- **If `--skip review` is set**:
  - Skip spawning the Reviewer subagent.
  - In `state.md`, mark milestone as `- [x] Step 5: Unified Code Review (Skipped via --skip review)`.
  - Proceed directly to Step 7 (Final Verification).
- **If `--skip review` is NOT set**:
  - Once **ALL** worker agents for all plans have completed their tasks, spawn a **Reviewer Subagent**:
    ```markdown
    Role: Principal Code Reviewer Subagent
    Task: Review all code changes implemented across all plans against docs/[objective-name]/goal.md.

    Inputs:
    - All Worker Commit Hashes: [List of all worker commits]
    - Spec: docs/[objective-name]/goal.md
    - Plans: docs/[objective-name]/plan*.md

    Evaluation Rubric:
    1. Spec Compliance: Does the unified implementation satisfy all requirements in goal.md without missing logic or scope creep?
    2. Integration & End-to-End Rigor: Do the independently executed plans integrate seamlessly?
    3. Test Coverage: Are unit and integration tests passing with genuine assertions?
    4. Clean Architecture: Adheres to project patterns, avoids dead code, cleanly handles errors.
    5. Safety: No security vulnerabilities, file leaks, or unhandled exceptions.

    Instructions:
    1. Inspect git diffs for the specified commits.
    2. Write review to docs/[objective-name]/review.md with sections:
       - Summary Verdict: [PASSED | DEFECTS FOUND]
       - Integration & Architecture Strengths
       - Blocking Issues (Must fix before completion)
       - Non-blocking Suggestions
    3. Commit: git add docs/[objective-name]/review.md && git commit -m "docs([objective-name]): unified code review"

    Deliverable: Report back with Verdict [PASSED | DEFECTS FOUND], file path, and git commit hash.
    ```

---

### Step 6: Defect Resolution (Only if Review was executed and defects found)

If blocking issues were flagged in `review.md`, spawn a **Fixer Subagent**. If review was skipped or PASSED, proceed directly to Step 7.

#### Subagent Dispatch Prompt:
```markdown
Role: Senior Fixer Subagent
Task: Resolve all blocking issues identified in docs/[objective-name]/review.md.

Instructions:
1. If the fix involves an integration or edge-case bug, load the "systematic-debugging" skill to isolate root cause.
2. Load the "test-driven-development" skill. Add regression tests proving the defect before applying fixes.
3. Apply targeted, minimal fixes resolving every blocking item in docs/[objective-name]/review.md.
4. Run all project tests and verify clean pass.
5. Commit: git commit -m "fix([objective-name]): resolve review defects"

Deliverable: Report back with the fixed items, test verification output, and commit hash.
```

---

### Step 7: Final Verification & Synthesis (Crucial — Never Skipped)

1. Run complete project test suite, linter, and build checks:
   ```bash
   # Run project build & test commands (e.g., npm test / pytest / go test)
   ```
2. Generate the final report at `docs/[objective-name]/final_report.md`.

### `final_report.md` Schema Template:
```markdown
# Final Report: [objective-name]

## Executive Summary
[Overview of what was built, integrated, and verified]

## Workflow Configuration
- Skipped Phases: [None | research | review | research, review]

## Plan Breakdown & Execution Record
| Plan ID | Title | Commits | Status |
| :--- | :--- | :--- | :--- |
| Plan 1 | [Title] | [Hashes] | Completed |
| Plan 2 | [Title] | [Hashes] | Completed |

## Verification & Quality Assurance
- Automated Tests: [Pass/Fail count]
- Lint & Type Checks: [Pass/Fail]
- Build Status: [Pass/Fail]

## Key Artifacts
- Goal: `docs/[objective-name]/goal.md`
- State & Matrix: `docs/[objective-name]/state.md`
- Plans: `docs/[objective-name]/plan*.md`
- Review: `docs/[objective-name]/review.md` [if executed]
```

3. Commit: `git add docs/[objective-name]/ && git commit -m "docs([objective-name]): final project report"`.
4. Update `state.md` to 100% complete and notify the user.

---

## 3. Operational Rules for the Orchestrator

1. **Strict Skippable Enforcement**: Reject any `--skip` arguments other than `research` and `review`.
2. **Active DAG Maintenance**: Keep `state.md` updated in real time as planners and workers finish.
3. **Never Stall Ready Workers**: As soon as a plan file is written and its prerequisites are met, trigger its Worker immediately.
4. **Disjoint Workspace Concurrency**: Only run Workers in parallel if their plans touch separate directories/files.
5. **Path Normalization**: Always use forward slashes (`/`).
