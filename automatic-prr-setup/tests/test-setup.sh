#!/usr/bin/env bash
set -euo pipefail

skill_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
repo="$fixture/repo"
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$repo"

git -C "$repo" init -q
git -C "$repo" config user.name test
git -C "$repo" config user.email test@example.com
git -C "$repo" switch -q -c feature/setup

# File install must succeed without gh or claude on PATH.
empty_bin="$fixture/empty-bin"
mkdir -p "$empty_bin"
git_dir="$(cd "$(dirname "$(command -v git)")" && pwd)"
core_dir="$(cd "$(dirname "$(command -v sed)")" && pwd)"
restricted_path="$empty_bin:$git_dir:$core_dir:/usr/bin:/bin"

(cd "$repo" && PATH="$restricted_path" CLAUDE_SKILL_DIR="$skill_root" \
  bash "$skill_root/scripts/setup.sh" --runner-label review-box)

workflow="$repo/.github/workflows/automatic-prr.yml"
prompt="$repo/.github/claude/prompts/pr-review.md"

test -f "$workflow"
test -f "$prompt"
grep -Fq 'runs-on: [self-hosted, review-box]' "$workflow"
grep -Fq 'github.event.pull_request.head.sha' "$workflow"
grep -Fq 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1' "$workflow"
grep -Fq 'MODEL: "sonnet"' "$workflow"
grep -Fq 'shell: pwsh' "$workflow"
grep -Fq -e '--model $env:MODEL' "$workflow"
grep -Fq '/code-review --comment' "$prompt"

if grep -Fq 'gh is not available on PATH' "$workflow"; then
  printf '%s\n' 'Workflow template should not mention local installer gh checks.' >&2
  exit 1
fi

(cd "$repo" && PATH="$restricted_path" CLAUDE_SKILL_DIR="$skill_root" \
  bash "$skill_root/scripts/setup.sh" --runner-label review-box)

printf '%s\n' '# local edit' >> "$workflow"
if (cd "$repo" && PATH="$restricted_path" CLAUDE_SKILL_DIR="$skill_root" \
  bash "$skill_root/scripts/setup.sh" --runner-label review-box); then
  printf '%s\n' 'Expected conflict protection to fail.' >&2
  exit 1
fi

(cd "$repo" && PATH="$restricted_path" CLAUDE_SKILL_DIR="$skill_root" \
  bash "$skill_root/scripts/setup.sh" --runner-label review-box --force)

if grep -Fq '# local edit' "$workflow"; then
  printf '%s\n' 'Force install did not replace the conflicting file.' >&2
  exit 1
fi

printf '%s\n' 'setup tests passed'
