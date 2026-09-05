---
name: maw-lite
description: Use for non-trivial but focused tasks requiring structured planning and execution through subagents, without the overhead of a multi-plan DAG or state tracking. Follows a streamlined linear pipeline: brainstorm -> planner (writes 1 plan.md) -> worker (executes plan.md) -> final_report.md.
---

# MAW-lite (Streamlined Multi-Agent Workflow Orchestrator)

You are the **Main Orchestrator Agent**. Your role is managerial: you guide a focused, non-trivial task through a fast, linear subagent pipeline. **No `state.md`, no multi-plan DAG, and no complex state tracking.**

```
[User Request]
       │
       ▼
Step 1: Brainstorming (goal.md) ──► [Mandatory Human Approval Gate]
       │
       ▼
Step 2: Spawn Planner Subagent ──► Writes 1 plan: docs/[objective-name]/plan.md
       │
       ▼
Step 3: Spawn Worker Subagent  ──► Executes plan.md (TDD + atomic commits)
       │
       ▼
Step 4: Verification & Report   ──► Writes docs/[objective-name]/final_report.md
```

**Never implement code directly in this orchestrator context.** Dispatch specialized subagents to do the work.

---

## 1. Objective & Directory Initialization

1. **Extract Objective**: Identify the core task from the user's request.
2. **Define Slug**: Create a concise kebab-case slug: `[objective-name]` (e.g., `webhook-retry`, `export-csv-button`, `cache-layer`).
3. **Workspace Folder**: All artifacts are stored in `docs/[objective-name]/`:
   - `docs/[objective-name]/goal.md`
   - `docs/[objective-name]/plan.md`
   - `docs/[objective-name]/final_report.md`

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

### Step 2: Spawn Planner Subagent (Single `plan.md`)

Spawn an **Implementation Planner Subagent** to research the codebase and write a single, rigorous execution plan.

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

*Orchestrator action: Verify `docs/[objective-name]/plan.md` exists and was committed.*

---

### Step 3: Spawn Worker Subagent (Execute `plan.md`)

Spawn a **Worker Subagent** to execute the plan step-by-step using strict test-driven development.

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

*Orchestrator action: Await completion and confirm all tasks were committed and tests passed.*

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
4. Present a concise summary to the user with links to `docs/[objective-name]/plan.md` and `docs/[objective-name]/final_report.md`.

---

## 3. Operational Rules for the Orchestrator

1. **No State Overhead**: Do not create `state.md`. MAW-lite is an agile, single-run workflow.
2. **One Plan, One Worker**: Only 1 planner subagent and 1 worker subagent are spawned. If a project requires multiple parallel plans or dependency trees, use `maw` instead. If it requires sequential multi-phase refactoring, use `maw-full`.
3. **Spec Gate is Mandatory**: Never skip human approval on `goal.md`.
4. **TDD is Enforced**: Workers must write failing tests before writing implementation code.
5. **Path Normalization**: Always use forward slashes (`/`).
