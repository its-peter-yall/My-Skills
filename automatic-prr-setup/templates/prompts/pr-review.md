Load and follow the pr-code-review skill, using its installed code-review companion for each review pass.

Review GitHub pull request #{{PR_NUMBER}} in {{REPOSITORY}}.

The checked-out source must remain exactly at head SHA {{PR_SHA}} and the expected base SHA is {{BASE_SHA}}. Verify both the pull-request identity and checked-out head before reviewing. If the PR head no longer equals {{PR_SHA}}, stop without writing reports.

Use pr-code-review's normal orchestration, including its small-change and large-change review paths. Review only changes introduced by this pull request, ignore pre-existing issues and low-confidence nitpicks.

Write the Markdown review reports under reviews/{{PR_NUMBER}}/, including slack-report.md, review-report.md, and the phase review file(s). Preserve unrelated files. Do not modify product code or other repository files, commit, push, merge, approve, close, comment on GitHub, use GitHub review actions, or modify pull-request metadata. Do not run gh, git commit, git push, or git fetch. A local Slack-ready slack-report.md is required; do not send Slack messages. The workflow, not this harness, commits those reports onto the pull-request source branch and posts slack-report.md as a pull-request comment.
