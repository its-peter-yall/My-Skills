---
name: scan-codebase
description: Partition any codebase into cohesive parts and coordinate independent, concern-specific reviews. Use when asked to scan a repository for dead code, hanging code, bloat, redundant checks, or code quality issues.
---

# Scan Codebase

Coordinate a review of an existing codebase. The explorer maps and partitions it; reviewers inspect assigned parts; the main agent only manages assignments and completion. Do not review implementation code or read reviewer reports in the main agent.

## 1. Explore and partition

Identify the repository root and applicable repository instructions. Delegate one explorer using [explorer-prompt.md](prompts/explorer-prompt.md), the root path, and any scope the user supplied. Tag or attach the prompt file using the harness's file-reference mechanism; give the explorer a path to the file if tagging is unavailable. Do not recreate its instructions in the delegation message.

The explorer returns a part map with stable, unique `part_name` slugs, owned paths, approximate size, relevant entry points and dependencies, the capability or responsibility each part fulfills, and any coverage gaps. Let the explorer choose N based on coherent services, features, modules, scripts, and other natural boundaries. **Each part must accomplish something identifiable:** it should own a behavior from entry point or caller contract to outcome, or a distinct shared responsibility with a clear contract. Favor parts fine enough that a reviewer can inspect their owned implementation, relevant tests, and adjacent contracts within one context window, with room left to reason and write the report. Split a large capability into meaningful subflows; never split by line ranges, alphabetical file groups, or size alone. A small standalone script is valid if it fulfills a complete purpose. Review the map's purpose statements, ownership, and size estimates; ask the explorer to refine purposeless, oversized, missing, or overlapping parts before assigning reviewers. Shared code has one owning part, while other reviewers may read it as context.

If subagents are unavailable, give the user a copyable explorer assignment that references `prompts/explorer-prompt.md` and ask them to return its part map before continuing. The new chat needs access to the same repository and skill files.

## 2. Select concerns

Ask the user to select one or more concerns from this list. Do not launch reviewers until they choose. Tag only the selected files in every reviewer assignment.

| Concern | Instructions |
| --- | --- |
| Dead code | [dead-code.md](concerns/dead-code.md) |
| Hanging code | [hanging-code.md](concerns/hanging-code.md) |
| Bloated code | [bloated-code.md](concerns/bloated-code.md) |
| Redundant checks | [redundant-checks.md](concerns/redundant-checks.md) |
| Code quality | [code-quality.md](concerns/code-quality.md) |

## 3. Choose execution route

Check the current harness's actual agent capabilities; do not assume a model list from another harness. If it can both delegate subagents **and select a reviewer model at delegation time**, list the available reviewer models and ask the user to choose one. After the model is chosen, ask the user to select the effort level (`low`, `medium`, or `high`) only if the harness supports setting effort for delegated subagents. Offer only levels supported for the chosen model. If effort selection is unavailable, do not ask about effort and use the harness default. Then launch reviewer agents in batches of up to three, each for a different part, with the selected model and effort when available. If either model selection or subagent delegation is absent, prepare a batch of up to three standalone reviewer prompts for the user to copy into separate chats; do not ask for a reviewer model or effort in this route. Each new chat must have access to the same repository and skill files. Wait for the user to report that the batch has finished before preparing the next one.

For each part, use a short assignment containing only:

- a tag/attachment or readable path for [reviewer-prompt.md](prompts/reviewer-prompt.md);
- tags/attachments or readable paths for **only** the selected concern files;
- the repository root, the part's `part_name`, its purpose and outcome or contract, exact owned paths, and the explorer's concise context for that part;
- a unique report destination ending in `<part_name>-review.md`.

Do not paste the prompt templates' contents into assignments. Give all reviewers in a run the same selected concerns. If the selected reviewer's context capacity makes a mapped part too large, ask the explorer to split that part before dispatch. Use a fresh run directory, by default `<repo>/reviews/scan-codebase/<YYYYMMDD-HHMMSS>/`, so earlier reports are preserved. Keep assignments to at most three active parts at a time. For fewer than three remaining parts, assign only the remainder.

## 4. Track completion

Each reviewer writes exactly one `<part_name>-review.md` at its assigned destination and replies with a brief completion status and path. The main agent may inspect report file existence and metadata to verify delivery; when chats do not share filesystem visibility, ask the user to confirm that each report was saved at its assigned path. **Never open, read, summarize, merge, validate, or quote a reviewer's report.** Do not infer findings from agent status messages. If a reviewer cannot cover a part within its context, have the explorer split it and replace the original assignment with smaller, non-overlapping parts. If an assignment fails or a report is missing, reassign that part or ask the user to rerun its prompt; keep it incomplete until delivery is confirmed. Do not mark a part complete because a reviewer merely started.

After every mapped part has a delivered report, write a completion summary with the repository, selected concerns, part names, report paths, and any limitations the explorer identified. This is a coverage and delivery summary, not a findings summary or quality verdict. Leave interpretation of report contents to the user or a separately requested analysis.

## Boundaries

The scan is read-only for source code and repository configuration. The only default writes are the requested Markdown review reports. Respect repository-specific instructions, ignore generated/vendor/dependency/build output unless explicitly in scope, and avoid commands with side effects. Do not commit, push, fix code, or publish findings as part of this skill.
