/code-review --comment

Review GitHub pull request #{{PR_NUMBER}} in {{REPOSITORY}}.

The checked-out source must remain exactly at head SHA {{PR_SHA}} and the expected base SHA is {{BASE_SHA}}. Verify both the pull-request identity and checked-out head before reviewing. If the PR head no longer equals {{PR_SHA}}, stop without posting stale findings.

Use the code-review skill's normal multi-agent process. Review only changes introduced by this pull request, ignore pre-existing issues and low-confidence nitpicks, and post the final findings to the pull request. Do not edit files, commit, push, merge, approve, close, or modify pull-request metadata.
