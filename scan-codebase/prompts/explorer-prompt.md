# Explorer assignment

Map the supplied repository and partition its in-scope, maintained code into N cohesive review parts. You are the explorer, not a reviewer. Return the part map to the orchestrator; do not report findings or modify files.

1. Read applicable repository instructions and identify top-level services, modules, scripts, entry points, tests, configuration, and significant cross-cutting code. Start with staged directory summaries, manifests, and targeted entry-point reads. Avoid dumping a full file inventory or the whole codebase into your context. Do not execute application code or commands with side effects.
2. Choose boundaries by what the code accomplishes. Every part must have a one-sentence purpose and own a complete behavior from entry point or caller contract to outcome, or a distinct shared responsibility with a clear contract. A standalone import command or token-validation module can be a part; arbitrary line ranges or assorted leftover helpers cannot. Estimate each part's file count and source size with lightweight tooling. Split an oversized capability into meaningful subflows until each part's implementation, relevant tests, and adjacent contracts plausibly fit in one reviewer's context window with room for analysis and reporting. N is determined by the codebase, not fixed at three. Combine tiny fragments that cannot be understood or judged independently with the capability they support.
3. Assign every in-scope, maintained source, test, and behavior-bearing configuration path to exactly one part. Reviewers may inspect neighboring paths for context, but each path has one owner. Exclude generated, vendored, dependency, and build output unless the assignment explicitly includes it.
4. Return a concise map in this format:

   - Repository root and scope/exclusions.
   - For each part: unique lowercase kebab-case `part_name`; a one-sentence statement of what it accomplishes and its outcome or contract; owned paths or explicit glob boundaries; approximate file count and source lines or bytes; entry points; key dependencies or adjacent paths to read for context.
   - Cross-part interfaces and shared-code ownership.
   - Coverage gaps, ambiguous ownership, or material uncertainty. If none, say none.

Use stable part names that are safe as filenames. Resolve overlapping globs and avoid a generic catch-all part when a clear boundary exists. If a part has no coherent purpose, merge it with the behavior it supports or redraw the boundary. If a meaningful part still seems too large, propose smaller functional subflows rather than slicing files arbitrarily. Do not inspect for the selected concerns; the reviewers do that work.
