#!/usr/bin/env bash
set -euo pipefail

skill_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
git_dir="$(cd "$(dirname "$(command -v git)")" && pwd)"
restricted_path="$git_dir:/usr/bin:/bin"

new_repo() {
  local name="$1"
  local repo="$fixture/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.name test
  git -C "$repo" config user.email test@example.com
  git -C "$repo" switch -q -c feature/setup
  printf '%s' "$repo"
}

run_setup() {
  local repo="$1"
  local harness="$2"
  local model="$3"
  shift 3
  (cd "$repo" && PATH="$restricted_path" AUTOMATIC_PRR_SKILL_DIR="$skill_root" \
    bash "$skill_root/scripts/setup.sh" \
      --runner-label review-box --harness "$harness" --model "$model" "$@")
}

for harness in claude opencode cursor codex; do
  repo="$(new_repo "repo-$harness")"
  if [[ "$harness" == opencode ]]; then
    model='openai/gpt-5.2#high'
  else
    model='model-1.2:test[effort=high,fast=false]'
  fi

  run_setup "$repo" "$harness" "$model"
  workflow="$repo/.github/workflows/automatic-prr.yml"
  prompt="$repo/.github/automatic-prr/pr-review.md"
  test -f "$workflow"
  test -f "$prompt"
  grep -Fq 'name: Automatic PR Review' "$workflow"
  grep -Fq 'runs-on: [self-hosted, review-box]' "$workflow"
  grep -Fq 'github.event.pull_request.head.sha' "$workflow"
  grep -Fq 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1' "$workflow"
  grep -Fq 'persist-credentials: false' "$workflow"
  grep -Fq "REVIEW_HARNESS: \"$harness\"" "$workflow"
  grep -Fq "REVIEW_MODEL: \"$model\"" "$workflow"
  grep -Fq '.github/automatic-prr/pr-review.md' "$workflow"
  grep -Fq 'contents: write' "$workflow"
  grep -Fq 'pull-requests: write' "$workflow"
  grep -Fq 'Land reports and comment' "$workflow"
  grep -Fq 'chore(review): reports for' "$workflow"
  grep -Fq 'slack-report.md' "$workflow"
  grep -Fq 'git log -1 --format=%B' "$workflow"
  grep -Fq 'HEAD:refs/heads/' "$workflow"
  grep -Fq 'missing planned phase report' "$workflow"
  grep -Fq 'slack-report.md exceeds GitHub comment size limit' "$workflow"
  if grep -Fq 'contents: read' "$workflow"; then
    printf '%s\n' 'Workflow still requests contents: read.' >&2
    exit 1
  fi
  if grep -Fq 'issues: write' "$workflow"; then
    printf '%s\n' 'Workflow still requests issues: write.' >&2
    exit 1
  fi
  if grep -Fq 'gh auth status' "$workflow"; then
    printf '%s\n' 'Workflow still runs gh auth status.' >&2
    exit 1
  fi
  if grep -Fq 'git push --force' "$workflow" || grep -Fq 'git push -f' "$workflow"; then
    printf '%s\n' 'Workflow must not force-push.' >&2
    exit 1
  fi
  grep -Fq 'pr-code-review' "$prompt"
  grep -Fq 'reviews/{{PR_NUMBER}}/' "$prompt"
  grep -Fq 'slack-report.md' "$prompt"
  grep -Fq 'Do not run gh' "$prompt"
  ! grep -Fq 'post the final findings to the pull request' "$prompt"
  ! grep -Fq '/code-review --comment' "$prompt"
  ! grep -Fq 'Do not edit files' "$prompt"
done

blank_repo="$(new_repo repo-default-model)"
run_setup "$blank_repo" codex ''
grep -Fq 'REVIEW_MODEL: ""' "$blank_repo/.github/workflows/automatic-prr.yml"
grep -Fq '$hasModel = -not [string]::IsNullOrWhiteSpace($env:REVIEW_MODEL)' "$blank_repo/.github/workflows/automatic-prr.yml"

escaped_repo="$(new_repo repo-escaped-model)"
escaped_model='provider/model\path&x|y'
run_setup "$escaped_repo" cursor "$escaped_model"
grep -Fq 'REVIEW_MODEL: "provider/model\\path&x|y"' "$escaped_repo/.github/workflows/automatic-prr.yml"

legacy_repo="$(new_repo repo-legacy)"
legacy_prompt="$legacy_repo/.github/claude/prompts/pr-review.md"
mkdir -p "$(dirname "$legacy_prompt")"
cp "$skill_root/templates/prompts/pr-review.md" "$legacy_prompt"
run_setup "$legacy_repo" claude ''
test ! -e "$legacy_prompt"

modified_repo="$(new_repo repo-modified-legacy)"
modified_prompt="$modified_repo/.github/claude/prompts/pr-review.md"
mkdir -p "$(dirname "$modified_prompt")"
printf '%s\n' 'custom legacy prompt' > "$modified_prompt"
run_setup "$modified_repo" cursor ''
test -f "$modified_prompt"

conflict_repo="$(new_repo repo-conflict)"
run_setup "$conflict_repo" opencode 'openai/gpt-5.2#high'
workflow="$conflict_repo/.github/workflows/automatic-prr.yml"
printf '%s\n' '# local edit' >> "$workflow"
if run_setup "$conflict_repo" opencode 'openai/gpt-5.2#high'; then
  printf '%s\n' 'Expected conflict protection to fail.' >&2
  exit 1
else
  code=$?
  test "$code" -eq 3
fi
run_setup "$conflict_repo" opencode 'openai/gpt-5.2#high' --force
if grep -Fq '# local edit' "$workflow"; then
  printf '%s\n' 'Force install did not replace the conflicting file.' >&2
  exit 1
fi

invalid_repo="$(new_repo repo-invalid)"
if run_setup "$invalid_repo" unknown ''; then
  printf '%s\n' 'Expected unknown harness to fail.' >&2
  exit 1
else
  code=$?
  test "$code" -eq 2
fi
if run_setup "$invalid_repo" claude $'bad\nmodel'; then
  printf '%s\n' 'Expected multiline model to fail.' >&2
  exit 1
else
  code=$?
  test "$code" -eq 2
fi

for doc in "$skill_root/SKILL.md" "$skill_root/README.md" "$skill_root/DESIGN.md"; do
  grep -Fq '$env:Path' "$doc"
  grep -Fq 'Start-Process powershell' "$doc"
  grep -Fq 'gh auth login --hostname github.com --git-protocol https --web' "$doc"
  grep -Fq 'Listening for Jobs' "$doc"
  grep -Fq 'gh-proxy.com' "$doc"
  grep -Fq 'ExecutionTimeLimit' "$doc"
  grep -Fq '.runner' "$doc"
  grep -Fq 'claude-review' "$doc"
  grep -Fq '.github/automatic-prr/pr-review.md' "$doc"
  if grep -Fq 'you must install pwsh yourself' "$doc"; then
    printf '%s\n' "Docs still tell the user to install pwsh after READY: $doc" >&2
    exit 1
  fi
done

printf '%s\n' 'setup tests passed'
