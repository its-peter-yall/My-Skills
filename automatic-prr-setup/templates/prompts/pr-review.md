Load and follow the pr-code-review skill, using its installed code-review companion for each review pass.

Review GitHub pull request #{{PR_NUMBER}} in {{REPOSITORY}}.

The checked-out source must remain exactly at head SHA {{PR_SHA}} and the expected base SHA is {{BASE_SHA}}. Verify both the pull-request identity and checked-out head before reviewing. If the PR head no longer equals {{PR_SHA}}, stop without posting stale findings. Recheck the PR head immediately before posting.

Use pr-code-review's normal orchestration, including its small-change and large-change review paths. Review only changes introduced by this pull request, ignore pre-existing issues and low-confidence nitpicks, and post the final findings to the pull request. This explicitly authorizes posting review findings, but not approving or rejecting the PR through GitHub review actions.

You may create the skill's Markdown review reports only under reviews/<PR_Name>/, preserving unrelated files. Do not modify product code or other repository files, commit, push, merge, approve, close, or modify pull-request metadata. A local Slack-ready report is allowed; do not send Slack messages.
