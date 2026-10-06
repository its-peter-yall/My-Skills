---
name: maw-full
description: Use when orchestrating massive refactors, complex architectural migrations, or multi-system features. Decomposes behemoth complexity into sequential phases, where each phase operates as an internal MAW engine (dependency graph, parallel planning, pipelined worker execution) followed by a per-phase code review and bugfix loop. Supports skipping non-critical phases via '--skip research' and '--skip review'.
---

# MAW-full (Fractal Multi-Agent Workflow Orchestrator)

You are the **Main Orchestrator Agent**. You manage massive, high-complexity architectural initiatives by decomposing them into a sequence of manageable **Phases**. 

**Core Principle**: **MAW-full is a fractal multiplier of MAW.**  
Instead of attempting to flatten a massive project into one giant plan list, the orchestrator breaks the behemoth into sequential phase folders: `docs/[objective-name]/[phase-N-slug]/`. **Each phase then executes as its own internal MAW engine**—complete with its own sub-plan DAG, parallel planning, pipelined "implement-while-planning" worker execution, and a dedicated phase code review gate before advancing.

**Never implement code directly in this orchestrator context.**

> [!IMPORTANT]
> **Core Orchestrator Constraints**:
> 1. **Foreground Parallel Planners**: When spawning planners within any phase, spawn them as **foreground parallel agents**, NOT as background agents (launch all independent ready planners concurrently in the foreground and await their completion).
> 2. **Never Read the Works (Context Preservation)**: The orchestrator **MUST NOT read the works (`research.md` or `plan*.md`)**. Only verify their existence and completion via **git commits** (`git log -1 --stat <hash>`), strictly preserving your context window across complex multi-phase initiatives.

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

### 1.2 Preflight: Sequential Role Model Selection

Run this gate **after validating flags and before Step 1 (brainstorming)**. This configures delegation only; it does not authorize research, planning, or execution before goal approval.

1. Identify the harness and inspect the delegation surface actually exposed to this session: the delegation tool schema you can call, plus any harness-provided model catalog, role/agent definitions, or configuration files. Model selection counts as supported only when a role's model can genuinely be set from this orchestrator session. Never infer support from the harness name, and never invent tool names, arguments, or config keys.
2. Consult the capability matrix below and use **this harness's** identifier format:

   | Harness | Delegation surface | Where a role's model comes from | Where thinking effort comes from | Granularity | Enforcement risk |
   | :--- | :--- | :--- | :--- | :--- | :--- |
   | **OpenCode** | `subagent` | The `model` argument as `provider/model`, optionally with a variant suffix; a Markdown agent may also pin `model` in `~/.config/opencode/agents/<name>.md` or `.opencode/agents/<name>.md` | The `#variant` suffix on the model value, or the tool's variant argument | Exact `provider/model` ID plus a variant | Low; re-check that the catalog entry still advertises the chosen variant |
   | **Codex** | `spawn_agent` and the other multi-agent tools | `model` on the spawn call when the schema exposes it; otherwise `model` in `~/.codex/agents/<name>.toml` or `.codex/agents/<name>.toml`; otherwise `[agents] default_subagent_model` | `reasoning_effort` on the spawn call, `model_reasoning_effort` in the agent TOML, or `[agents] default_subagent_reasoning_effort` | Exact Codex model slug plus an effort level | **High.** Some builds silently ignore per-agent pins and run the child on the parent model. Fail closed. |
   | **Grok Build** | `spawn_subagent` with `subagent_type` | `[subagents.models]` per-type routing, `[subagents.roles.<role>]` `model`, or a persona `model` in `.grok/roles/*.toml` / `.grok/personas/*.toml`; a spawn-time override only when the exposed schema actually accepts one | `reasoning_effort` in the role or persona, or `default_reasoning_effort` in `~/.grok/config.toml` | Exact Grok Build model id | Medium; resolution order is spawn override → role → persona → parent session, so record which layer supplied the model |
   | **Antigravity** | `invoke_subagent` with custom agents | `model` in an agent's YAML frontmatter at `.agents/agents/<name>/agent.md` (or the user-level equivalent) | **None.** No per-subagent reasoning-effort control exists | **Tier only:** `inherit`, `flash`, `pro` | Low, but a tier is not a model ID — never report one as the other |

   For any other harness, derive the equivalent facts from its own tools and configuration before asking the user anything, and record what you found as the capability evidence.
3. Read that row literally when you ask:
   - **OpenCode**: offer `provider/model` IDs from the harness's model-listing tool, and treat the `#variant` suffix (or the separate variant argument) as the thinking effort.
   - **Codex**: offer model slugs from Codex's own documentation and configuration, never from memory. Offer only the effort levels the chosen model actually advertises (`none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`, `ultra` are model-dependent).
   - **Grok Build**: derive the catalog from `grok inspect` or the model picker, honoring `allowed_models`, `hidden_models`, and `disabled_models`.
   - **Antigravity**: ask for a **tier** (`inherit`, `flash`, `pro`), never a model name. Record `model_scope: tier`, and treat `inherit` as the harness-default equivalent. Do not ask an effort question.
4. If neither a spawn-level parameter nor a writable role/agent/persona definition path exists for this harness's delegation surface, **skip all model and effort questions**, record `model_selection: unsupported`, `setup_status: skipped`, and `harness-default` for all three roles, then continue on harness defaults. If delegation itself is unavailable, report that limitation and stop before dispatch; never implement tasks in the orchestrator. If the catalog cannot be discovered, ask the user for authoritative model information and leave `setup_status: pending`; never guess model IDs or efforts.
5. Ask for **researcher**, then **planner**, then **worker**, strictly sequentially. Finish resolving the current role's model and effort before asking about the next role. Show catalog-backed choices and the literal option **`none` (manual handoff)**. Explicit role selections already supplied by the user count as answers, but must still be validated in this order. Configure researcher even if `--skip research` is set; the skip flag still prevents research execution.
6. Resolve each answer against the catalog:
   - `none` means `mode: manual`, `model: null`, `effort: null`. Do not ask a thinking-effort question for it.
   - Accept a selector only when it uniquely identifies one available value **in this harness's format**. Persist that value exactly as this harness expects it.
   - For ambiguous, partial, or invalid names (including `model_name`, `model_name-5`, or `provider/model_name`), reprompt with valid similar entries, displaying the full `provider/model` IDs, or the available tiers, as this harness requires. A unique exact value is unambiguous; an unqualified name offered by multiple providers is not. Never silently choose a provider, version, tier, or near match. If no similar entries exist, show available choices or ask for a corrected name.
   - **Antigravity**: accept only `inherit`, `flash`, or `pro`; reprompt with those three options for any other answer, including a real model name.
   - Validate any supplied thinking effort against that model's actual available efforts. If omitted and selectable, ask with the **complete available list** before moving to the next role. Include a harness-default option only if the harness actually supports omission. Reprompt invalid or ambiguous effort answers.
   - If the model has no selectable efforts (as in Antigravity), record `effort_control: unsupported` and `effort: null` for every role and do not ask. If efforts exist but the delegation surface cannot apply them, explain the limitation and record `effort: null`. Never encode an unsupported effort into an invented model suffix or a prompt instruction.
7. Initialize delegation state with `state_schema_version: 2`, `setup_status: pending`, and each unanswered role as `{ mode: pending, model: null, effort: null }`. Persist each resolved answer immediately in `docs/[objective-name]/state.md`, preserving existing content. During a new workflow's preflight use `goal_status: pending`, `resume_gate: none`, and a `MODEL SELECTION PENDING` gate; do not claim goal approval or completed brainstorming. On resume, preserve any existing goal approval and authorization. Set `setup_status: complete` only after all three roles are resolved. **Do not start Step 1 until setup is complete or explicitly skipped for unsupported model selection.**
8. **Enforcement check after the first automatic dispatch of a role, and again whenever the harness changes.** Confirm the child actually ran on the requested model/effort using whatever this harness exposes (Codex: the child thread's reported model and effort; Grok Build: the resolved role or persona model; OpenCode: the variant used for the child; Antigravity: the agent's tier). If a request was ignored or cannot be verified, do not silently continue: record `enforcement: unverified`, name the affected roles, warn the user, and offer the `none` manual fallback for those roles. Never claim a model was enforced without evidence, and never complete a milestone on the strength of an unconfirmed request.

On resume, reuse persisted selections rather than asking again. Finish any pending role in researcher → planner → worker order. Revalidate automatic selections against the current harness/catalog **and against that harness's identifier format**; if a value is unavailable, no longer valid, or no longer enforceable, pause and ask for a replacement rather than silently falling back. Legacy states without delegation configuration must run this preflight before any new dispatch. Explicit user changes must be validated and persisted before future dispatches; never change already running tasks silently.

**MAW-full inheritance:** Store these settings once in the master state. Every internal MAW phase must inherit them, including the harness identifier format and `enforcement` status; do not rerun selection or overwrite them with phase defaults. Manual handoff IDs must include phase and plan scope to avoid collisions across phases.

#### Role-aware dispatch and manual handoffs

These rules override instructions below that say to spawn a researcher, planner, or worker:

- For `automatic`, apply the stored selector through **this harness's** mechanism from the capability matrix, using the delegation tool's actual schema. OpenCode and Codex: pass the model and effort on the spawn call when the schema exposes them. Grok Build: route the model through `subagent_type`, `[subagents.models]`, or the role/persona definition, and record which layer supplied it. Antigravity: dispatch the agent whose frontmatter carries the chosen tier. Reviewer and fixer behavior remains unchanged.
- For `harness-default`, omit every override. Reviewer and fixer behavior remains unchanged.
- Never pass a parameter the exposed schema does not accept, and never treat an unenforced request as a fulfilled one — fall back to the enforcement check in step 8.
- For `manual`, **do not spawn an agent and do not perform its task yourself**. Once its normal readiness and approval gates are satisfied, print a fully instantiated, copyable delegation prompt in a fenced block in chat. Use the relevant role prompt below, with all placeholders resolved, and include the repository/working directory, objective and phase/plan ID, input artifact paths, dependencies, owned files, safety/commit rules, output paths, and required completion evidence. If the external agent lacks a named skill, include equivalent actionable instructions so the prompt is usable in another coding agent.
- Record a unique handoff ID, role, plan/phase scope, prompt location (chat message reference if available), expected artifacts, and `awaiting-user` status in state **before yielding**. Ask the user to return artifact paths, commit hashes, a concise decisions/contracts summary for research, and test results for workers. Do not issue duplicate prompts for a pending handoff on resume unless the user requests one.
- Continue independent ready work within the active phase, respecting file ownership and serialized git commits. A manual handoff is pending work, **not a skipped phase or a completion**. Only dependent tasks wait; phase boundaries still apply. If nothing else is ready, stop and wait for the user rather than polling or fabricating progress.
- Verify returned commits and expected changed paths using git metadata, and check required completion/test evidence before marking the handoff `verified` and updating normal milestones/DAG statuses. If work is in another checkout, require its commits to be available in this workspace before unblocking dependents. Missing or failed evidence keeps the handoff pending. Never read `research.md` or `plan*.md` into orchestrator context; use the returned concise summary and commit metadata.
- Planner foreground-parallel and immediate-worker rules apply to **automatic** dispatches. Emit ready manual prompts instead of spawning those roles, and unblock their dependents only after verification.

### 1.3 Initialize Master State (`state.md` Schema as it Grows)
Create `docs/[objective-name]/state.md`. The structure/schema for `state.md` must follow the comprehensive growing schema below (modeled after `docs/agentic-pivot/phase-1/state.md`), maintaining complete lifecycle visibility across global milestones and phased DAG execution without ingesting heavy plan or research files.

### `state.md` Master Schema Template:
```markdown
---
objective: [objective-name]
workflow: maw-full
state_schema_version: 2
status: in-progress
skipped_phases: [] # e.g. [research], [review], or [research, review]
source: docs/[objective-name]/idea.md # or prompt/issue reference
goal_status: approved # pending | approved
dag_status: initial # initial | research-reconciled | phase-K-active | complete
resume_gate: authorized # none | authorized | resumed
delegation:
  harness: [opencode | codex | grok-build | antigravity | other]
  capability_matrix_row: [the row from Section 1.2 that applies]
  model_selection: supported # supported | unsupported
  effort_control: supported # supported | unsupported | not-applicable
  setup_status: complete # pending | complete | skipped
  enforcement: unverified # verified | unverified (remove once every role is verified)
  roles:
    researcher: { mode: automatic, model: "[harness-native selector]", effort: null, model_scope: "[id | tier]" }
    planner: { mode: automatic, model: "[harness-native selector]", effort: null, model_scope: "[id | tier]" }
    worker: { mode: automatic, model: "[harness-native selector]", effort: null, model_scope: "[id | tier]" }
# Role mode: pending | automatic | manual | harness-default.
# model: exact harness-native value — provider/model[#variant] (OpenCode), model slug
#   (Codex), model id (Grok Build), or inherit|flash|pro (Antigravity). null when unset.
# model_scope: id for OpenCode/Codex/Grok Build, tier for Antigravity.
# effort: validated effort, or null when unset/inapplicable (always null in Antigravity).
---

# Master State & Phase Hierarchy: [objective-name / Initiative Title]

## Workflow configuration

- Keep all workflow artifacts directly in `docs/[objective-name]/[phase-slug]/`.
- Preserve existing source directories and avoid unnecessary folder nesting.
- Skipped phases declared: [None | --skip review | --skip research | --skip research,review].
- Mandatory phases: Brainstorming, phase decomposition, planning, execution, and final verification remain required.
- Current authorization: Goal approved; phase hierarchy initialized; executing Phase K.
- Phase boundary rule: Phase K+1 never starts until Phase K is 100% verified and committed.

## Delegation configuration & handoffs

- Harness: [detected harness, delegation tool, and the capability-matrix row that applies].
- Capability evidence: [catalog/config source consulted; the model and effort parameters actually available; or the reason selection was skipped].
- Selection order: Researcher → Planner → Worker; persist choices before workflow work.
- Phase inheritance: All internal MAW phases reuse this master configuration without reprompting.
- Enforcement: [evidence that each automatic role ran on its requested model/effort, or `unverified` with the affected roles].
- Reviewer/fixer: Existing harness defaults; not part of role selection.

| Handoff ID | Role | Plan/phase scope | Prompt reference | Expected artifacts | Status | Returned evidence |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| [unique ID] | [researcher/planner/worker] | [scope] | [chat reference or descriptive label] | [paths] | awaiting-user / verified | [commits, summary, tests] |

Keep this table empty until a manual task is ready. Pending handoffs block their dependents and phase completion, not independent work within the active phase.

## Global workflow milestones

- [x] Step 1: Brainstorming & Goal Alignment (`docs/[objective-name]/goal.md`; [commit hash / explicitly approved])
- [ ] Step 2: Technical Research (`docs/[objective-name]/research.md`; [commit hash]) <!-- or "[x] Step 2: Technical Research (Skipped via --skip research)" -->
- [ ] Step 3: Phase Hierarchy Decomposition
- [ ] Phase 1: [phase-1-slug]
- [ ] Phase 2: [phase-2-slug]
- [ ] Step 5: Final System Verification & Report (`docs/[objective-name]/final_report.md`)

## Brainstorming tasks

- [x] Explore architectural context: source systems, constraints, dependencies, conventions.
- [x] Scope phase boundaries and sequential dependency chain.
- [x] Compare migration approaches and recommend strategy.
- [x] Present architecture specification for approval.
- [x] Write and commit the validated `goal.md`: [commit hash].
- [x] Obtain explicit user approval of written architecture specification.
- [x] Construct the initial phase hierarchy and active phase DAG below.

## Initial findings

- [Key architectural constraints, high-risk coupling, legacy dependencies, or migration risks discovered during brainstorm]

## Confirmed product decisions

- [Explicit architectural and boundary decisions confirmed with user during brainstorm / goal approval]

---

## Active Phase: [phase-K-slug] (`docs/[objective-name]/[phase-K-slug]/`)

### Dependency matrix & execution status

[Narrative explaining Phase K DAG status, research commit hash, planner/worker rules, and ownership boundaries]

`R` means technical research completed and committed. `P#.#` worker dependencies mean prerequisite implementation is completed, verified, and committed.

| Plan ID | Title & Scope | Worker dependencies | Touched files / subsystems | Planner status | Worker status | Commits |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Plan K.1** | [e.g., Schema migration] | None (or R) | `src/db/` | [ ] Pending | [ ] Pending | - |
| **Plan K.2** | [e.g., Service layer] | Plan K.1 | `src/services/` | [ ] Pending | [ ] Pending | - |
| **Plan K.3** | [e.g., Client integration] | Plan K.2 | `src/client/` | [ ] Pending | [ ] Pending | - |

*(Note on statuses: Planner status updates to `[x] <hash>` once the planner commits; Worker status updates to `[x] Complete` once the worker finishes and tests pass).*

### Execution graph

```mermaid
flowchart TD
    G[Phase K Started] --> PK1[Plan K.1: Schemas]
    PK1 --> PK2[Plan K.2: Services]
    PK2 --> PK3[Plan K.3: Client]
    PK3 --> REV[Phase Review / Verification]
```

### Planner readiness and immediate worker dispatch

| Planner | Earliest planning prerequisites | Worker start condition |
| :--- | :--- | :--- |
| Plan K.1 | Phase K activated | Plan K.1 committed |
| Plan K.2 | Plan K.1 worker committed | Plan K.2 plan committed and Plan K.1 complete |
| Plan K.3 | Plan K.2 worker committed | Plan K.3 plan committed and Plan K.2 complete |

- Dispatch independent phase planners concurrently in foreground parallel.
- Start each ready phase worker immediately when its plan is committed; do not wait for other planners.
- Workers with disjoint write ownership execute in parallel.
- Serialize git staging/commits across workers to avoid shared-index collisions.

### Plan scopes, file ownership, and completion gates

#### Plan K.1 — [Title]
**Deliverable:** `planK.1.md`; [short contract description]
**Owned files:**
- `path/to/file1.ts`
**Scope:** [Detailed scope description and architectural boundaries]
**Exit gate:** [Specific automated test assertions proving completion]

#### Plan K.2 — [Title]
**Deliverable:** `planK.2.md`; [short contract description]
**Owned files:**
- `path/to/file2.ts`
**Scope:** [Detailed scope description and architectural boundaries]
**Exit gate:** [Specific automated test assertions proving completion]

### Acceptance coverage

| Goal criterion | Primary owner(s) | Integrated verification |
| :--- | :--- | :--- |
| AC1: [Criterion description] | Plan K.1, Plan K.2 | Plan K.3, Phase Review |

### Phase review & defect status
- **Phase Code Review**: [ ] Pending (`docs/[objective-name]/[phase-K-slug]/review.md`) <!-- or "[x] Skipped via --skip review" -->
- **Phase Status**: [ ] Not Started <!-- [ ] Not Started | [#] In Progress | [x] Completed -->

---

## Research handoff [— complete ([commit hash])]
[Summary of research decisions and contracts once research is committed, or note if skipped via --skip research]

## Final verification commands and evidence

| Working directory | Command | Expected purpose |
| :--- | :--- | :--- |
| `[dir1]` | `[command1]` | [Full regression suite] |
| `[dir2]` | `[command2]` | [Build & lint check] |

## Artifact and commit record

| Artifact | State | Commit |
| :--- | :--- | :--- |
| `idea.md` | Original user source | Pre-existing |
| `goal.md` | Approved | [commit hash] |
| `state.md` | Master state | [commit hash] |
| `research.md` | Complete (or Skipped) | [commit hash] |
| `[phase-1-slug]/plan1.md` | Written | [commit hash] |
| `final_report.md` | Pending | - |

## Current gate and resume procedure

**CURRENT GATE: [e.g. PHASE 1 IN PROGRESS / PHASE 2 DISPATCHING / COMPLETE]**

Resume steps:
1. [ ] Read this state, approved goal, and current git status; preserve intervening user changes.
2. [ ] Identify current active phase and next pending planner/worker.
   - Validate/reuse master delegation configuration; finish pending setup and verify returned manual handoffs before unblocking dependents.
3. [ ] Dispatch ready planners in foreground parallel.
4. [ ] Pipeline unblocked workers immediately upon plan commit.
5. [ ] Complete phase review/fix loop before advancing to next phase.

### 1.4 How state.md Grows Across Lifecycle Gates
The orchestrator updates and grows `state.md` systematically:
0. **Preflight**: Record the detected harness, the capability-matrix row that applies, and the sequential role selections with pending goal/authorization statuses; preserve this master configuration across all phases. Record `enforcement` and manual handoff issuance and verification at each relevant transition.
1. **Brainstorming / Spec Gate**: Initializes global configuration, milestones, brainstorm checklist, findings, confirmed decisions, and the high-level phase hierarchy.
2. **Post-Research**: Records `research.md` commit hash without ingesting the file, marks Step 2 complete, records decisions in `## Research handoff`, and reconciles the phase plan.
3. **Phased Execution (Phase 1..N)**:
   - For active Phase $K$, populates the local DAG, execution graph, planner readiness table, plan scopes with file ownership and exit gates, and acceptance coverage.
   - Spawns planners as **foreground parallel agents**, NOT background agents.
   - When each planner commits, verifies via git commit hash (`git log -1 --stat <hash>`), updates `Planner status` with `[x] <hash>`, and updates the Artifact record. **Do not read `plan*.md` into orchestrator context.**
   - Unblocked workers are spawned immediately. When finished, records `Worker status: [x] Complete` and worker commit hashes.
   - Executes phase code review and fix loop (or marks skipped), marking Phase $K$ `[x] Completed`.
4. **Final System Verification**: Runs system-wide checks, records outcomes in verification evidence, commits `final_report.md`, and marks all milestones and `status: complete`.
```

*State rule: Update checkboxes (`[ ]` -> `[#]` -> `[x]`) and commit `state.md` to git after every state transition.*

---

## 2. The Fractal MAW-full Lifecycle

```
[Massive User Request]
          │
          ▼
Preflight: Role Models & Efforts (or unsupported: skip selection)
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
  - **Context Preservation Rule**: The orchestrator **MUST NOT read `research.md`**. Verify that research was completed and committed via its git commit hash (e.g. `git log -1 --stat <hash>`).
  - In `state.md`, mark `- [x] Step 2: Technical Research (docs/[objective-name]/research.md; [commit hash])`, record key architectural decisions in `## Research handoff`, and update `dag_status: research-reconciled`.

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
- Record touched files, dependencies, execution graph, plan scopes (with file ownership and exit gates), and acceptance coverage in the Phase $K$ section of `state.md`.

#### 4.2. Concurrent Planning (Foreground Parallel Agents & Context Preservation)
- **Constraint 1 (Foreground Parallel Execution)**: When spawning planners within Phase $K$, spawn them as **foreground parallel agents**, NOT as background agents. Any plans whose planning prerequisites are met should have their planners dispatched concurrently in the foreground (e.g., in a single `invoke_subagent` call specifying each planner subagent) and await their completion. Do not spawn planners as detached background tasks.
- **Constraint 2 (Context Preservation - Never Read Plans)**: The orchestrator **MUST NOT read `plan*.md`**. Only verify existence and completion via **git commit hashes** (`git log -1 --stat <hash>`). Update `Planner status` in `state.md` with `[x] <hash>` (e.g. `[x] 07c8dfe`). Pass the file path `docs/[objective-name]/[phase-K-slug]/plan[ID].md` directly to the worker subagent; never ingest plan contents into the orchestrator context window.

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
6. **Foreground Parallel Planners**: When spawning planners within any phase, spawn them as **foreground parallel agents**, never as background agents.
7. **Context Preservation (Never Read Works)**: The orchestrator **MUST NOT read `research.md` or `plan*.md`**. Verify deliverables exclusively via git commit hashes (`git log -1 --stat <hash>`) to preserve the orchestrator context window across long multi-phase workflows.
8. **Growing state.md Schema Integrity**: Maintain and grow `state.md` systematically according to the schema (tracking global milestones, active phase DAG with commit hashes, execution graph, plan scopes with file ownership and exit gates, acceptance coverage, artifact record, and resume procedure).
9. **Role Selection & Manual Gates**: Apply Section 1.2 to every researcher/planner/worker dispatch in every phase. Inherit persisted model/effort choices, never guess unsupported overrides, and never treat `none` or a pending manual handoff as phase completion.
10. **Harness-Native Selectors**: Offer and store selectors in the current harness's own vocabulary (`provider/model[#variant]`, Codex model slug, Grok Build model id, or Antigravity tier). Never translate a selection across harnesses or offer a tier where an id is required.
11. **Fail Closed on Ignored Requests**: Verify that each automatic dispatch actually used its requested model/effort. Record `enforcement: unverified`, warn the user, and offer manual handoff instead of continuing on an unenforced assumption.

