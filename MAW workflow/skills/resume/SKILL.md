---
name: resume
description: Use when the user requests to resume, continue, or inspect an ongoing, paused, or interrupted multi-agent workflow (MAW or MAW-full).
---

# Workflow Resume Skill

You are the **Workflow Resumption Agent**. Your responsibility is to discover, validate, and restore the execution state of an interrupted or paused multi-agent workflow (`maw` or `maw-full`) from `docs/[objective-name]/state.md`.

*(Note: `maw-lite` is a streamlined single-pass pipeline that runs without `state.md`. Resumption applies to multi-phase `maw-full` and DAG-based `maw` workflows).*

---

## 1. Execution Flow

```
[User invokes /resume or asks to resume]
                    │
                    ▼
Does the user specify an objective name?
       │                             │
       ▼ (YES)                       ▼ (NO)
Discover with target objective   Discover all active workflows
       │                             │
       └──────────────┬──────────────┘
                      ▼
            Discovery Cascade:
      Tier 1: python resume.py
      Tier 2: node resume.js (zero external npm deps)
      Tier 3: Native agent tools (list_dir, view_file)
                      │
                      ▼
         Evaluate Discovery Result:
         ├─► DOCS_NOT_FOUND: Alert user that `docs/` is missing. Stop.
         ├─► NO_STATE_FILES: Alert user that no workflows exist. Stop.
         ├─► OBJECTIVE_NOT_FOUND / SELECT_OBJECTIVE:
         │   Display available workflows table and ask user to pick.
         │
         └─► OBJECTIVE_MATCHED (or user picked):
             1. Read `docs/[objective-name]/state.md`.
             2. Read `docs/[objective-name]/goal.md`.
             3. Extract workflow type (`maw` or `maw-full`).
             4. Locate first uncompleted (`[#]` or `[ ]`) task/phase.
             5. Load target skill (`maw` or `maw-full`) and resume.
```

---

## 2. Step-by-Step Instructions

### Step 1: Run the Discovery Cascade

Execute the discovery check using the first available tier:

#### Tier 1: Python Script (Primary if Python installed)
```bash
# With objective:
python ~/.config/opencode/skills/resume/scripts/resume.py --objective "<objective-name>"

# Without objective:
python ~/.config/opencode/skills/resume/scripts/resume.py
```

#### Tier 2: Node.js Script (Standard on OpenCode / when Python missing)
If Python is not installed or `python` command fails, use the zero-dependency Node.js script:
```bash
# With objective:
node ~/.config/opencode/skills/resume/scripts/resume.js --objective "<objective-name>"

# Without objective:
node ~/.config/opencode/skills/resume/scripts/resume.js
```
*(Both scripts produce identical JSON output schemas).*

#### Tier 3: Pure Native Tool Fallback (Zero Runtime Dependencies)
If *neither* Python nor Node.js is available, or terminal execution is restricted, execute discovery natively with built-in tools:
1. Call `list_dir(DirectoryPath="docs")`.
   - If `docs/` does not exist: Handle as `DOCS_NOT_FOUND`.
2. Inspect each child directory for `state.md`.
   - If no subdirectories contain `state.md`: Handle as `NO_STATE_FILES`.
3. For each found `docs/<dir>/state.md`, call `view_file`:
   - Extract frontmatter or header: `workflow:` (`maw` or `maw-full`) and `objective:`.
   - Count `- [x]` (completed), `- [#]` (in-progress), and `- [ ]` (pending).
4. If `<objective-name>` was provided:
   - If it matches a directory name: Treat as `OBJECTIVE_MATCHED`.
   - If no match: Treat as `OBJECTIVE_NOT_FOUND` and render the table.
5. If no objective was provided:
   - Treat as `SELECT_OBJECTIVE` and render the table.

---

### Step 2: Handle Discovery Output

Evaluate the discovery result:

#### Case A: `DOCS_NOT_FOUND`
Immediately inform the user:
> "No `docs/` directory was found in the current workspace. There are no active or previous workflows to resume."

#### Case B: `NO_STATE_FILES`
Inform the user:
> "A `docs/` directory exists, but no subdirectories contain a valid `state.md` checkpoint."

#### Case C: `SELECT_OBJECTIVE` or `OBJECTIVE_NOT_FOUND`
If the objective wasn't given, or if the requested objective was not found:
1. If the objective was not found, inform the user:
   > "Objective `'<requested>'` was not found with a valid `state.md`."
2. Render a clean table of all `available_objectives`:

| Objective Name | Workflow Type | Progress | Completed Tasks | State File |
| :--- | :--- | :--- | :--- | :--- |
| `auth-migration` | `maw-full` | 65% | 7 / 11 | `docs/auth-migration/state.md` |
| `csv-exporter` | `maw` | 25% | 1 / 4 | `docs/csv-exporter/state.md` |

3. Prompt the user to select which objective they wish to resume. **Do not guess or resume arbitrarily.** Wait for user selection.

---

### Step 3: Inspect & Restore State

Once an objective is confirmed (either matched directly or selected by the user):

1. **Read the State File**:
   Inspect `docs/[objective-name]/state.md`.
2. **Read the Goal & Context**:
   Read `docs/[objective-name]/goal.md` (and `docs/[objective-name]/research.md` if present).
3. **Determine the Workflow**:
   Extract the `workflow` attribute from `state.md` frontmatter or header (`maw` or `maw-full`).
4. **Locate Resume Point**:
   - Scan the dependency matrix or task checklist in `state.md`.
   - Identify any task marked `[#] In Progress`. If found, check what commits/files were produced before interruption.
   - If no tasks are `[#]`, find the first task/phase marked `[ ] Pending` whose prerequisites are satisfied.
5. **Report to User & Load Skill**:
   Output a brief status update:
   > "Resuming workflow **`[workflow]`** for objective **`[objective-name]`** at milestone: **`[current-task-or-phase]`**."
6. **Activate Skill**:
   - If workflow is `maw-full`: Activate the `maw-full` skill and resume executing the phase lifecycle.
   - If workflow is `maw`: Activate the `maw` skill and resume the pipelined DAG execution loop.
