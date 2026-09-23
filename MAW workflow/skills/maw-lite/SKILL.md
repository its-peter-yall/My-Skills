---
name: maw-lite
description: Use for non-trivial but focused tasks requiring structured planning and execution through subagents, without the overhead of a multi-plan DAG or state tracking. Follows a streamlined linear pipeline: brainstorm -> planner (writes 1 plan.md) -> worker (executes plan.md) -> final_report.md.
---

# MAW-lite (Streamlined Multi-Agent Workflow Orchestrator)

You are the **Main Orchestrator Agent**. Your role is managerial: you guide a focused, non-trivial task through a fast, linear subagent pipeline while maintaining clean state tracking and context preservation.

> [!IMPORTANT]
> **Core Orchestrator Constraints**:
> 1. **Foreground Parallel Planners**: When spawning planners, spawn them as **foreground parallel agents**, NOT as background agents (launch all independent ready planners concurrently in the foreground and await their completion).
> 2. **Never Read the Works (Context Preservation)**: The orchestrator **MUST NOT read the works (`research.md` or `plan.md`)**. Only verify their existence and completion via **git commits** (`git log -1 --stat <hash>`), strictly preserving your context window.

```
[User Request]
       │
       ▼
Step 1: Brainstorming (goal.md) + Init State (state.md) ──► [Mandatory Human Approval Gate]
       │
       ▼
Step 2: Spawn Planner Subagent (Foreground) ──► Writes 1 plan: docs/[objective-name]/plan.md
       │                                        (Verified exclusively via git commit)
       ▼
Step 3: Spawn Worker Subagent  ──► Executes plan.md (TDD + atomic commits)
       │                           (Verified exclusively via git commit)
       ▼
Step 4: Verification & Report   ──► Writes docs/[objective-name]/final_report.md
```

**Never implement code directly in this orchestrator context.** Dispatch specialized subagents to do the work.

---

## 1. Objective, Directory & State Initialization

1. **Extract Objective**: Identify the core task from the user's request.
2. **Define Slug**: Create a concise kebab-case slug: `[objective-name]` (e.g., `webhook-retry`, `export-csv-button`, `cache-layer`).
3. **Workspace Folder**: All artifacts are stored in `docs/[objective-name]/`:
   - `docs/[objective-name]/goal.md`
   - `docs/[objective-name]/state.md`
   - `docs/[objective-name]/plan.md`
   - `docs/[objective-name]/final_report.md`

### 1.2 Initialize State (`state.md` Schema as it Grows)
Create `docs/[objective-name]/state.md`. The structure/schema for `state.md` must follow the comprehensive growing schema below (modeled after `docs/agentic-pivot/phase-1/state.md`), maintaining complete lifecycle visibility without reading the plan into orchestrator context:

### `state.md` Schema Template:
```markdown
---
objective: [objective-name]
workflow: maw-lite
status: in-progress
source: docs/[objective-name]/idea.md # or prompt/issue reference
goal_status: approved # pending | approved
dag_status: initial # initial | complete
resume_gate: authorized # none | authorized | resumed
---

# State & Execution Plan: [objective-name / Title]

## Workflow configuration

- Keep all workflow artifacts directly in `docs/[objective-name]/`.
- Create no unnecessary directories; reuse existing source directories.
- Mandatory phases: Brainstorming, planning, execution, and final verification.
- Current authorization: Goal approved; dispatching planner in foreground.

## Workflow milestones

- [x] Step 1: Brainstorming & Goal Alignment (`docs/[objective-name]/goal.md`; [commit hash / explicitly approved])
- [ ] Step 2: Planning Completed (`docs/[objective-name]/plan.md`; [commit hash])
- [ ] Step 3: Execution Completed (Worker finished)
- [ ] Step 4: Final Verification & Report (`docs/[objective-name]/final_report.md`)

## Brainstorming tasks

- [x] Explore project context: source request, existing code, tests, conventions.
- [x] Clarify requirements, edge cases, scope boundaries.
- [x] Present design for approval.
- [x] Write and commit the validated `goal.md`: [commit hash].
- [x] Obtain explicit user approval of written specification.
- [x] Construct state tracking, plan scope, file ownership, and exit gate below.

## Initial findings

- [Key architectural facts, existing code patterns, endpoints, or limitations discovered during brainstorm]

## Confirmed product decisions

- [Explicit product and architectural decisions confirmed with user during brainstorm / goal approval]

## Dependency matrix & execution status

| Plan ID | Title & Scope | Worker dependencies | Touched files / subsystems | Planner status | Worker status | Commits |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Plan 1** | [Title & Scope] | None | [Touched files / subsystems] | [ ] Pending | [ ] Pending | - |

*(Note on statuses: Planner status updates to `[x] <hash>` once the planner commits; Worker status updates to `[x] Complete` once the worker finishes and tests pass).*

## Plan scopes, file ownership, and completion gates

### Plan 1 — [Title]
**Deliverable:** `plan.md`; [short contract description]
**Owned files:**
- `path/to/file1.ts`
- `path/to/file1.test.ts`
**Scope:** [Detailed scope description and architectural boundaries]
**Exit gate:** [Specific automated test assertions proving completion]

## Acceptance coverage

| Goal criterion | Primary owner(s) | Integrated verification |
| :--- | :--- | :--- |
| AC1: [Criterion description] | Plan 1 | Final verification |
| AC2: [Criterion description] | Plan 1 | Final verification |

## Final verification commands and evidence

| Working directory | Command | Expected purpose |
| :--- | :--- | :--- |
| `[dir1]` | `[command1]` | [Regression suite / unit tests] |
| `[dir2]` | `[command2]` | [Build / typecheck / lint] |

## Artifact and commit record

| Artifact | State | Commit |
| :--- | :--- | :--- |
| `idea.md` | Original source / prompt | Pre-existing |
| `goal.md` | Approved | [commit hash] |
| `state.md` | Initial state / in-progress | [commit hash] |
| `plan.md` | Written | [commit hash] |
| `final_report.md` | Pending | - |

## Current gate and resume procedure

**CURRENT GATE: [e.g. DISPATCHING PLANNER / EXECUTING WORKER / COMPLETE]**

Resume steps:
1. [ ] Read this state, approved goal, and current git status.
2. [ ] Check current gate and prerequisites.
3. [ ] Dispatch planner in foreground (or worker if plan committed).
4. [ ] Perform final verification and commit final report.

### 1.3 How state.md Grows Across Lifecycle Gates
1. **Brainstorming / Spec Gate**: Initializes the full schema with approved `goal.md` commit, initial findings, confirmed decisions, Plan 1 scope with file ownership and exit gates, acceptance coverage, and artifact record.
2. **Planning**: Dispatches planner as a **foreground agent** (not background). When planner commits `plan.md`, verify via git commit hash (`git log -1 --stat <hash>`), update `Planner status` with `[x] <hash>`, and update Artifact record. **Do not read `plan.md` into orchestrator context.**
3. **Execution**: Spawns worker subagent immediately with path `docs/[objective-name]/plan.md`. When worker finishes, verify via git commit hashes, record `Worker status: [x] Complete` and worker commit hashes.
4. **Final Verification**: Runs verification suite, records outcomes in verification evidence, commits `final_report.md`, and marks milestones and `status: complete`.
```

---

## 2. Step-by-Step Execution Lifecycle

### Step 1: Brainstorming & Spec Gate

1. Invoke the `brainstorming` skill.
2. Collaborate with the user to explore requirements, edge cases, architectural approach, and acceptance criteria.
3. Save the finalized specification to `docs/[objective-name]/goal.md`.
4. Commit: `git add docs/[objective-name]/goal.md && git commit -m "docs([objective-name]): goal specification"`.

> [!IMPORTANT]
> **MANDATORY HUMAN APPROVAL GATE**: Stop and ask the user to confirm `goal.md` before dispatching any subagents. Do not proceed until explicit user approval is granted.

---

### Step 2: Spawn Planner Subagent (Foreground Agent & Context Preservation)

Spawn an **Implementation Planner Subagent** as a **foreground agent** (NOT as a background agent) to research the codebase and write a single, rigorous execution plan.

- **Constraint 1 (Foreground Agent Dispatch)**: The planner MUST be spawned as a **foreground agent**, NOT as a background agent. Await its completion in the active turn.
- **Constraint 2 (Context Preservation - Never Read Plan)**: The orchestrator **MUST NOT read `plan.md`**. Only verify that the plan was completed and committed via its **git commit hash** (`git log -1 --stat <hash>`). Update `Planner status` in `state.md` with `[x] <hash>`. Pass the file path `docs/[objective-name]/plan.md` directly to the worker subagent; never ingest plan contents into the orchestrator context window.

#### Subagent Dispatch Prompt:
```markdown
Role: Implementation Planner Subagent
Task: Create a detailed, bite-sized implementation plan for docs/[objective-name]/goal.md.

Context:
- Goal Specification: docs/[objective-name]/goal.md
- Target Plan Path: docs/[objective-name]/plan.md

Instructions:
1. Load and follow the "writing-plans" skill.
2. Inspect the codebase using your read tools to examine existing code patterns, tests, utilities, and file locations.
3. Formulate a comprehensive step-by-step implementation plan.
4. Output the plan to: docs/[objective-name]/plan.md.
5. The plan MUST:
   - Begin with the writing-plans header (Goal, Architecture, Tech Stack).
   - Break work into small, bite-sized steps with exact file paths.
   - Include failing test code, expected test command, minimal implementation code, and verification command for every task.
   - Specify git commit messages per task.
6. Commit: git add docs/[objective-name]/plan.md && git commit -m "docs([objective-name]): implementation plan"

Deliverable: Report back with the file path docs/[objective-name]/plan.md and your git commit hash.
```

*Orchestrator action: Verify `docs/[objective-name]/plan.md` commit hash via git, update `state.md` with `[x] <hash>`, and immediately dispatch worker without reading the plan.*

---

### Step 3: Spawn Worker Subagent (Execute `plan.md`)

Spawn a **Worker Subagent** to execute the plan step-by-step using strict test-driven development. Pass `docs/[objective-name]/plan.md` path to the worker.

#### Subagent Dispatch Prompt:
```markdown
Role: Senior Software Engineer (Worker Subagent)
Task: Implement the tasks defined in docs/[objective-name]/plan.md.

Context:
- Goal: docs/[objective-name]/goal.md
- Plan: docs/[objective-name]/plan.md

Instructions:
1. Load the "executing-plans" and "test-driven-development" skills.
2. Read docs/[objective-name]/plan.md and execute each task in sequence.
3. For each task, follow the strict TDD cycle:
   a. Write failing test.
   b. Run test and verify it fails as expected.
   c. Write minimal implementation.
   d. Run test and verify it passes.
   e. Commit atomic changes with clear git commit message.
4. After completing all tasks in the plan, run the full project test suite and linters to verify zero regressions.

Deliverable: Report back with a summary of modified files, test suite output, and the list of git commit hashes created.
```

*Orchestrator action: Await completion, verify all worker commit hashes via git (`git log -1 --stat <hash>`), and update `Worker status: [x] Complete` in `state.md`.*

---

### Step 4: Verification & Final Report

1. Run the project verification suite (automated tests, linter, typecheck, build) to verify system integrity:
   ```bash
   # Run relevant project test commands
   ```
2. Create `docs/[objective-name]/final_report.md` summarizing the completed work:

### `final_report.md` Schema Template:
```markdown
# Final Report: [objective-name]

## Executive Summary
[Brief description of the feature implemented and outcome]

## Implementation Details
- **Specification**: `docs/[objective-name]/goal.md`
- **Plan**: `docs/[objective-name]/plan.md`
- **Files Modified / Created**:
  - `path/to/file1.ts`
  - `path/to/file2_test.ts`

## Git Commit History
- `[hash]` - feat([scope]): [commit message]
- `[hash]` - test([scope]): [commit message]

## Verification & QA
- Automated Test Suite: [PASSED - count passed / 0 failed]
- Lint & Type Checks: [PASSED]
- Build Status: [PASSED]
```

3. Commit: `git add docs/[objective-name]/final_report.md && git commit -m "docs([objective-name]): final report"`.
4. Update `state.md` to 100% complete (`status: complete`), and present a concise summary to the user with links to `docs/[objective-name]/plan.md` and `docs/[objective-name]/final_report.md`.

---

## 3. Operational Rules for the Orchestrator

1. **State.md Schema Tracking**: Initialize and grow `docs/[objective-name]/state.md` according to the growing schema, tracking milestones, planner/worker commits, exit gates, and verification evidence.
2. **One Plan, One Worker**: MAW-lite operates a focused single planner and worker. If a project requires multiple parallel plans or dependency trees, use `maw` instead. If it requires sequential multi-phase refactoring, use `maw-full`.
3. **Spec Gate is Mandatory**: Never skip human approval on `goal.md`.
4. **TDD is Enforced**: Workers must write failing tests before writing implementation code.
5. **Path Normalization**: Always use forward slashes (`/`).
6. **Foreground Parallel Planners**: When spawning planners, spawn them as **foreground parallel agents**, never as background agents.
7. **Context Preservation (Never Read Works)**: The orchestrator **MUST NOT read `plan.md` or `research.md`**. Verify deliverables exclusively via git commit hashes (`git log -1 --stat <hash>`) to strictly preserve orchestrator context.

