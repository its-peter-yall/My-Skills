#!/usr/bin/env bash
set -euo pipefail

runner_label="automatic-prr"
harness="claude"
model=""
force="false"

usage() {
  printf '%s\n' "Usage: setup.sh [--runner-label LABEL] [--harness claude|opencode|cursor|codex] [--model MODEL] [--force]"
}

while (($#)); do
  case "$1" in
    --runner-label)
      (($# >= 2)) || { usage >&2; exit 2; }
      runner_label="$2"
      shift 2
      ;;
    --harness)
      (($# >= 2)) || { usage >&2; exit 2; }
      harness="${2,,}"
      shift 2
      ;;
    --model)
      (($# >= 2)) || { usage >&2; exit 2; }
      model="$2"
      shift 2
      ;;
    --force)
      force="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! "$runner_label" =~ ^[A-Za-z0-9_.-]+$ ]]; then
  printf 'Invalid runner label: %s\n' "$runner_label" >&2
  exit 2
fi

case "$harness" in
  claude|opencode|cursor|codex) ;;
  *)
    printf 'Invalid review harness: %s\n' "$harness" >&2
    exit 2
    ;;
esac

model="$(printf '%s' "$model" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
if ((${#model} > 256)) || [[ "$model" == *$'\n'* || "$model" == *$'\r'* ]]; then
  printf '%s\n' 'Invalid review model: use a single line of at most 256 characters.' >&2
  exit 2
fi
if [[ "$model" =~ [[:cntrl:]] ]]; then
  printf '%s\n' 'Invalid review model: control characters are not allowed.' >&2
  exit 2
fi

if ! command -v git >/dev/null 2>&1; then
  printf 'Missing prerequisite: git is not available on PATH.\n' >&2
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf '%s\n' 'Run this skill from inside the target Git repository.' >&2
  exit 1
}

branch_name="$(git -C "$repo_root" symbolic-ref --quiet --short HEAD 2>/dev/null)" || {
  printf '%s\n' 'Detached HEAD detected. Switch to the setup branch first.' >&2
  exit 1
}

skill_dir="${AUTOMATIC_PRR_SKILL_DIR:-${CLAUDE_SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
workflow_source="$skill_dir/templates/workflows/automatic-prr.yml"
prompt_source="$skill_dir/templates/prompts/pr-review.md"
workflow_target="$repo_root/.github/workflows/automatic-prr.yml"
prompt_target="$repo_root/.github/automatic-prr/pr-review.md"
legacy_prompt_target="$repo_root/.github/claude/prompts/pr-review.md"

for source_path in "$workflow_source" "$prompt_source"; do
  if [[ ! -f "$source_path" ]]; then
    printf 'Skill asset is missing: %s\n' "$source_path" >&2
    exit 1
  fi
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
workflow_rendered="$tmp_dir/automatic-prr.yml"
prompt_rendered="$tmp_dir/pr-review.md"

escaped_model="${model//\\/\\\\}"
escaped_model="${escaped_model//\"/\\\"}"
sed_model="${escaped_model//\\/\\\\}"
sed_model="${sed_model//&/\\&}"
sed_model="${sed_model//|/\\|}"
sed \
  -e "s/__RUNNER_LABEL__/$runner_label/g" \
  -e "s/__REVIEW_HARNESS__/$harness/g" \
  -e "s|__REVIEW_MODEL__|$sed_model|g" \
  "$workflow_source" > "$workflow_rendered"
cp "$prompt_source" "$prompt_rendered"

conflicts=()
if [[ -e "$workflow_target" ]] && ! cmp -s "$workflow_rendered" "$workflow_target"; then
  conflicts+=("$workflow_target")
fi
if [[ -e "$prompt_target" ]] && ! cmp -s "$prompt_rendered" "$prompt_target"; then
  conflicts+=("$prompt_target")
fi

if ((${#conflicts[@]})) && [[ "$force" != "true" ]]; then
  printf '%s\n' 'Existing managed file(s) differ:' >&2
  printf '  %s\n' "${conflicts[@]}" >&2
  printf '%s\n' 'Inspect the differences and rerun with --force only after approval.' >&2
  exit 3
fi

mkdir -p "$(dirname "$workflow_target")" "$(dirname "$prompt_target")"
install -m 0644 "$workflow_rendered" "$workflow_target"
install -m 0644 "$prompt_rendered" "$prompt_target"

if [[ -f "$legacy_prompt_target" ]] && cmp -s "$legacy_prompt_target" "$prompt_rendered"; then
  rm -f "$legacy_prompt_target"
  printf 'Removed exact managed legacy prompt: %s\n' "$legacy_prompt_target"
elif [[ -f "$legacy_prompt_target" ]]; then
  printf 'Preserved modified legacy prompt: %s\n' "$legacy_prompt_target"
fi

model_display="${model:-default}"
printf 'Installed automatic PR review on branch %s.\n' "$branch_name"
printf 'Runner label: %s\n' "$runner_label"
printf 'Review harness: %s\n' "$harness"
printf 'Review model: %s\n' "$model_display"
printf 'Workflow: %s\n' "$workflow_target"
printf 'Prompt:   %s\n' "$prompt_target"
printf '%s\n' 'No files were committed or pushed.'
