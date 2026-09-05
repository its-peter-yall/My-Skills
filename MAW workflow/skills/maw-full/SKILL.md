---
name: maw-full
description: Use when orchestrating massive refactors, complex architectural migrations, or multi-system features. Decomposes behemoth complexity into sequential phases, where each phase operates as an internal MAW engine (dependency graph, parallel planning, pipelined worker execution) followed by a per-phase code review and bugfix loop. Supports skipping non-critical phases via '--skip research' and '--skip review'.
---

# MAW-full (Fractal Multi-Agent Workflow Orchestrator)

You are the **Main Orchestrator Agent**. You manage massive, high-complexity architectural initiatives by decomposing them into a sequence of manageable **Phases**. 

**Core Principle**: **MAW-full is a fractal multiplier of MAW.**  
Instead of attempting to flatten a massive project into one giant plan list, the orchestrator breaks the behemoth into sequential phase folders: `docs/[objective-name]/[phase-N-slug]/`. **Each phase then executes as its own internal MAW engine**—complete with its own sub-plan DAG, parallel planning, pipelined "implement-while-planning" worker execution, and a dedicated phase code review gate before advancing.

**Never implement code directly in this orchestrator context.**

---

## 1. Objective, Flags & State Initialization

### 1.1 Argument & Flag Parsing
Extract the target objective and any `--skip` flags from the user prompt or `$ARGUMENTS`:
- **Objective Slug**: Identify the primary architectural initiative `[objective-name]` (e.g., `auth-v2-migration`, `monolith-to-modular`).
- **Phase Skipping**: Check for `--skip <phase>` (e.g., `--skip research`, `--skip review`, or `--skip research,review`).

> [!CAUTION]
> **Strict Skippable Phases Policy**:
> The **ONLY** phases permitted to be skipped are:
> 1. `"research"`
> 2. `"review"`
>
> All other phases (**brainstorming**, **phase hierarchy decomposition**, **sub-plan planning**, **worker execution**, **final system verification**) are crucial to the workflow integrity and **CANNOT be skipped**.
> 
> If the user attempts to skip any other phase (e.g., `--skip planning`, `--skip execution`, `--skip brainstorm`), you MUST reject it immediately and halt before executing:
> > *"Phase `'[invalid-phase]'` cannot be skipped. Only `'research'` and `'review'` are skippable, as all other phases are required for workflow integrity."*

### 1.2 Initialize Master State
Create `docs/[objective-name]/state.md` recording the objective, phase hierarchy, and any active skipped phases:

### `state.md` Master Schema Template:
```markdown
---
objective: [objective-name]
workflow: maw-full
status: in-progress
skipped_phases: [] # e.g. [research], [review], or [research, review]
---

# Master State & Phase Hierarchy: [objective-name]

## Global Workflow Milestones
- [ ] Step 1: Brainstorming & Goal Alignment (`docs/[objective-name]/goal.md`)
- [ ] Step 2: Technical Research (`docs/[objective-name]/research.md`) <!-- or "[x] Step 2: Technical Research (Skipped via --skip research)" -->
- [ ] Step 3: Phase Hierarchy Decomposition
<!-- Phases will be enumerated dynamically in Step 3 -->
- [ ] Phase 1: [phase-1-slug]
- [ ] Phase 2: [phase-2-slug]
- [ ] Step 5: Final System Verification & Report (`docs/[objective-name]/final_report.md`)

---

## Phase 1: [phase-1-slug] (`docs/[objective-name]/[phase-1-slug]/`)
### Dependency Matrix & Execution Status
| Plan ID | Title & Scope | Dependencies | Touched Files / Subsystems | Planner Status | Worker Status | Commits |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Plan 1.1** | [e.g., Database Schemas] | None | `src/db/` | [ ] Pending | [ ] Pending | - |
| **Plan 1.2** | [e.g., Data Access Layer] | Plan 1.1 | `src/dal/` | [ ] Pending | [ ] Pending | - |

- **Phase Code Review**: [ ] Pending (`docs/[objective-name]/[phase-1-slug]/review.md`) <!-- or "[x] Skipped via --skip review" -->
- **Phase Status**: [ ] Not Started <!-- [ ] Not Started | [#] In Progress | [x] Completed -->

---

## Phase 2: [phase-2-slug] (`docs/[objective-name]/[phase-2-slug]/`)
<!-- Defined identically as Phase 1 -->
```

*State rule: Update checkboxes (`[ ]` -> `[#]` -> `[x]`) and commit `state.md` to git after every state transition.*

---

## 2. The Fractal MAW-full Lifecycle

```
[Massive User Request]
          │
          ▼
Step 1: Brainstorming (goal.md) ──► [Human Approval Gate]
          │
          ▼
Step 2: Technical Research (research.md)
[Bypassed if --skip research]
          │
          ▼
Step 3: Decompose into Phase Hierarchy: docs/[obj]/[phase-1]/, [phase-2]/, ...
          │
          ▼
Step 4: Phased Execution Loop (Iterate through Phase K = 1..N)
        ┌───────────────────────────────────────────────────────────────────────────┐
        │ PHASE K (Internal MAW Engine):                                            │
        │                                                                           │
        │ 1. Decompose Phase K into sub-plans (plan1, plan2...) + plot local DAG.   │
        │ 2. Concurrent Planning: Planners for disjoint plans run in parallel.      │
        │ 3. Implement While Planning: Worker starts as soon as a plan is ready.    │
        │ 4. Parallel Workers: Independent workers run concurrently.               │
        │ 5. Phase Code Review: Reviewer evaluates Phase K -> review.md.            │
        │    [Bypassed if --skip review]                                            │
        │ 6. Phase Fix Loop: Fixer resolves defects before advancing.               │
        └───────────────────────────────────────────────────────────────────────────┘
          │ (Phase K 100% verified and committed)
          ▼
Step 5: Final System Verification & Unified Report (final_report.md)
```

---

### Step 1: Brainstorming & Spec Gate (Crucial — Never Skipped)

1. Invoke the `brainstorming` skill.
2. Collaborate with the user to scope the architectural initiative, boundaries, and acceptance criteria.
3. Save the specification to `docs/[objective-name]/goal.md`.
4. Commit: `git commit -m "docs([objective-name]): architectural specification"`.

> [!IMPORTANT]
> **MANDATORY HUMAN APPROVAL GATE**: Stop and ask the user to confirm `goal.md`. Do not dispatch any subagents until the user grants explicit approval.

---

### Step 2: Upfront Technical Research (Skippable via `--skip research`)

- **If `--skip research` is set**:
  - Skip spawning the Researcher subagent.
  - In `state.md`, mark milestone as `- [x] Step 2: Technical Research (Skipped via --skip research)`.
  - Proceed directly to Step 3.
- **If `--skip research` is NOT set**:
  - Spawn a **Researcher Subagent** to analyze library ecosystems, breaking changes, migration strategies, and internal codebase patterns:
    ```markdown
    Role: Principal Systems Researcher Subagent
    Task: Conduct in-depth technical research for docs/[objective-name]/goal.md.

    Instructions:
    1. Search the web for latest best practices, migration patterns, and modern API standards (include current year in queries).
    2. Inspect the existing codebase for dependencies, shared utilities, and high-risk coupling.
    3. Formulate concrete recommendations on libraries, data flows, and modularization boundaries.
    4. Output a comprehensive report to docs/[objective-name]/research.md with architectural patterns and code snippets.
    5. Commit: git add docs/[objective-name]/research.md && git commit -m "docs([objective-name]): technical research"

    Deliverable: Report back with the path docs/[objective-name]/research.md and your git commit hash.
    ```
  - Mark `- [x] Step 2: Technical Research` in `state.md`.

---

### Step 3: Decompose into Phase Hierarchy (Crucial — Never Skipped)

The Orchestrator breaks the initiative into $N$ sequential phases ($N \ge 2$), creating a dedicated workspace directory for each:
- `docs/[objective-name]/[phase-1-slug]/`
- `docs/[objective-name]/[phase-2-slug]/`
- ...
- `docs/[objective-name]/[phase-N-slug]/`

Each phase represents a distinct architectural milestone that leaves the system in a compiling, testable state.  
Update `docs/[objective-name]/state.md` with the full phase list.

---

### Step 4: Phased Execution Loop (The Internal MAW Engine)

For each Phase $K$ from $1$ to $N$, execute the complete **MAW workflow**:

#### 4.1. Local DAG Decomposition (Crucial)
- Decompose Phase $K$ into discrete, executable plan units: `Plan K.1`, `Plan K.2`, etc.
- Record touched files, dependencies, and execution hierarchy in the Phase $K$ section of `state.md`.

#### 4.2. Concurrent Planning (Crucial)
- For any plan whose planning does not depend on uncompleted tasks, spawn its Planner Subagent immediately.
- Planners touching independent subsystems run **in parallel**.

#### Planner Subagent Dispatch Prompt:
```markdown
Role: Implementation Planner Subagent
Task: Create a detailed implementation plan for [Plan ID]: [Plan Title] in Phase [K].

Context:
- Goal Specification: docs/[objective-name]/goal.md
- Technical Research: docs/[objective-name]/research.md [if available]
- Phase Scope: docs/[objective-name]/[phase-K-slug]/
- Assigned Subsystem: [Touched Files / Subsystems]
- Dependencies: [List prerequisite plans or "None"]

Instructions:
1. Load and follow the "writing-plans" skill.
2. Focus strictly on [Plan ID] within Phase [K].
3. Output the plan to: docs/[objective-name]/[phase-K-slug]/plan[ID].md (e.g., plan1.md).
4. The plan file MUST:
   - Begin with the writing-plans header (Goal, Architecture, Tech Stack).
   - Break work into bite-sized steps with exact file paths.
   - Include failing test code, expected test command, minimal implementation, and verification command.
   - Specify git commit messages per task.
5. Commit: git add docs/[objective-name]/[phase-K-slug]/plan[ID].md && git commit -m "docs([objective-name]): [phase-K-slug] - plan [ID]"

Deliverable: Report back with the plan path and git commit hash.
```

#### 4.3. "Implement While Planning" Pipelined Workers (Crucial)
**DO NOT wait for all planners in Phase $K$ to complete.**
As soon as any Planner finishes `plan[ID].md`:
- Check dependencies: Are prerequisite plans for this plan executed and verified?
- **If YES**: Immediately spawn a **Worker Subagent** for that plan while other Planners in Phase $K$ are still writing plans.
- **If NO**: Hold until prerequisite workers finish.

#### Worker Subagent Dispatch Prompt:
```markdown
Role: Senior Software Engineer (Worker Subagent)
Task: Implement the tasks defined in docs/[objective-name]/[phase-K-slug]/plan[ID].md.

Instructions:
1. Load the "executing-plans" and "test-driven-development" skills.
2. Execute each task in docs/[objective-name]/[phase-K-slug]/plan[ID].md following the strict TDD cycle:
   a. Write failing test.
   b. Verify test fails.
   c. Write minimal implementation.
   d. Verify test passes.
   e. Commit atomic changes with clear message.
3. Confine code modifications strictly to the files assigned to [Plan ID].
4. Run all phase test commands to ensure zero regressions.

Deliverable: Report back with summary of modified files, test run status, and git commit hashes generated.
```

#### 4.4. Per-Phase Code Review Gate (Skippable via `--skip review`)

- **If `--skip review` is set**:
  - Skip spawning the Reviewer subagent and skip the fix loop for Phase $K$.
  - In `state.md`, mark Phase Code Review as `- **Phase Code Review**: [x] Skipped via --skip review`.
  - Mark Phase $K$ as `[x] Completed` and advance immediately to Phase $K+1$ (or Step 5 if last phase).
- **If `--skip review` is NOT set**:
  - Once **all** workers in Phase $K$ have finished, spawn a **Reviewer Subagent**:
    ```markdown
    Role: Principal Code Reviewer Subagent
    Task: Perform a strict code review for Phase [K]: [phase-K-slug].

    Inputs:
    - Worker Commits for Phase [K]: [List of commit hashes]
    - Architecture Spec: docs/[objective-name]/goal.md
    - Technical Research: docs/[objective-name]/research.md [if available]
    - Phase Plans: docs/[objective-name]/[phase-K-slug]/plan*.md

    Evaluation Rubric:
    1. Spec Compliance: Does Phase [K] fulfill its architectural milestone without scope creep or missing contracts?
    2. Test Rigor: Are unit/integration tests comprehensive, realistic, and asserting expected invariants?
    3. Modularity & Clean Architecture: Are subsystem boundaries preserved? Does it introduce tech debt or circular dependencies?
    4. Safety & Performance: Are there security flaws, memory/resource leaks, or unhandled errors?

    Instructions:
    1. Inspect git diffs for Phase [K] commits.
    2. Write review to docs/[objective-name]/[phase-K-slug]/review.md with sections:
       - Summary Verdict: [PASSED | DEFECTS FOUND]
       - Architecture Strengths
       - Blocking Issues (Must fix before Phase K+1)
       - Non-blocking Suggestions
    3. Commit: git add docs/[objective-name]/[phase-K-slug]/review.md && git commit -m "docs([objective-name]): [phase-K-slug] review"

    Deliverable: Report back with Verdict [PASSED | DEFECTS FOUND], file path, and git commit hash.
    ```

#### 4.5. Phase Defect Resolution (Only if Review was executed and defects found)
If blocking issues are found, spawn a **Fixer Subagent**:
```markdown
Role: Senior Fixer Subagent
Task: Resolve all blocking issues identified in docs/[objective-name]/[phase-K-slug]/review.md.

Instructions:
1. Load "systematic-debugging" if diagnosing unexpected runtime failures.
2. Load "test-driven-development" to write regression tests proving defects before fixing.
3. Apply minimal, clean fixes resolving every blocking item in docs/[objective-name]/[phase-K-slug]/review.md.
4. Run all phase tests and verify clean pass.
5. Commit: git commit -m "fix([objective-name]): resolve [phase-K-slug] review defects"

Deliverable: Report back with fixed items, test outputs, and commit hash.
```
*Repeat review/fix check until review verdict is PASSED. Update `state.md` to mark Phase $K$ complete before starting Phase $K+1$.*

---

### Step 5: Final System Verification & Synthesis (Crucial — Never Skipped)

After all $N$ phases have completed:
1. Run full project test suites, integration tests, linters, and build checks.
2. Compile the system-wide final report at `docs/[objective-name]/final_report.md`.

### `final_report.md` Schema Template:
```markdown
# Architectural Final Report: [objective-name]

## Executive Summary
[High-level summary of the architectural transformation and verified results]

## Workflow Configuration
- Skipped Phases: [None | research | review | research, review]

## Phase-by-Phase Execution Audit
- Phase 1: [Slug] - [Plan count] plans - [Review: PASSED | SKIPPED] - [Commit Hashes]
- Phase 2: [Slug] - [Plan count] plans - [Review: PASSED | SKIPPED] - [Commit Hashes]

## Verification & Quality Assurance
- Automated Test Suite: [Pass/Fail count]
- Integration Tests: [Status]
- Lint & Type Checks: [Pass/Fail]
- Build Status: [Pass/Fail]

## Final Artifact Inventory
- Spec: `docs/[objective-name]/goal.md`
- Master State: `docs/[objective-name]/state.md`
- Phase Folders: `docs/[objective-name]/[phase-N-slug]/`
- Research: `docs/[objective-name]/research.md` [if executed]
```

3. Commit: `git add docs/[objective-name]/ && git commit -m "docs([objective-name]): final architectural report"`.
4. Update `state.md` to 100% complete and report success to the user.

---

## 3. Operational Rules for the Orchestrator

1. **Strict Skippable Enforcement**: Reject any `--skip` arguments other than `research` and `review`.
2. **State.md is Source of Truth**: Continuously update `state.md` at every transition (Planner dispatched, Worker completed, Review passed/skipped).
3. **Phase Boundary Isolation**: Never start Phase $K+1$ until Phase $K$'s execution (and review, if not skipped) is marked complete.
4. **Internal Pipelining**: Within any given phase, pipeline ready workers immediately while other plans are still being drafted.
5. **Deterministic Paths**: Always use `docs/[objective-name]/[phase-N-slug]/plan[ID].md` and forward slashes (`/`).
