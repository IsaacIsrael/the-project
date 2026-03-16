#!/usr/bin/env bash
# Create a GitHub **story** issue (Description, Objective, Acceptance Criteria).
# Labels are read from .github/ISSUE_TEMPLATE/story.md so changing the template updates behavior without editing this script.
# Usage: bash .cursor/scripts/create-story.sh [--title "Title"] [--description "..."] [--objective "..."] [--acceptance-criteria "..."]
#   Use -file suffix for multiline. Default title: "[Story] New story".
# Uses: gh. Run from repo root.

set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

if ! command -v gh &>/dev/null || ! gh auth status &>/dev/null; then
  echo "GitHub CLI (gh) must be installed and authenticated." >&2
  exit 1
fi

usage() {
  echo "Usage: $0 [--title \"Title\"] [--description \"...\"] [--objective \"...\"] [--acceptance-criteria \"...\"]" >&2
  echo "       Use --description-file, --objective-file, --acceptance-criteria-file for multiline." >&2
  echo "       Labels come from .github/ISSUE_TEMPLATE/story.md. Default title: \"[Story] New story\"." >&2
  exit 1
}

# Read labels from template frontmatter. Arg: template filename (e.g. story.md). Fallback: first arg is default label.
get_labels_from_template() {
  local name="$1" default_label="${2:-}"
  local template_file="${ROOT}/.github/ISSUE_TEMPLATE/${name}"
  if [[ ! -f "$template_file" ]]; then
    echo "$default_label"
    return
  fi
  local block
  block=$(sed -n '/^---$/,/^---$/p' "$template_file" | sed '1d;$d')
  local labels_line
  labels_line=$(grep '^labels:' <<< "$block" || true)
  if [[ -z "$labels_line" ]]; then
    echo "$default_label"
    return
  fi
  sed 's/labels: *//; s/\[//; s/\]//; s/"//g; s/,//g' <<< "$labels_line" | tr -s ' ' '\n' | grep -v '^$' || echo "$default_label"
}

title="[Story] New story"
description="Clearly describe the purpose of this story. What problem does it solve or what value does it add?"
objective="What is the expected outcome once this story is completed?"
acceptance_criteria="- [ ] Criteria 1
- [ ] Criteria 2
- [ ] Criteria 3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) title="$2"; shift 2 ;;
    --description) description="$2"; shift 2 ;;
    --description-file) description=$(cat "$2"); shift 2 ;;
    --objective) objective="$2"; shift 2 ;;
    --objective-file) objective=$(cat "$2"); shift 2 ;;
    --acceptance-criteria) acceptance_criteria="$2"; shift 2 ;;
    --acceptance-criteria-file) acceptance_criteria=$(cat "$2"); shift 2 ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

body_file="$TMPDIR/body.md"
cat << BODY > "$body_file"
## 📖 Description
${description}

---

## 🎯 Objective
${objective}

---

## ✅ Acceptance Criteria
${acceptance_criteria}
BODY

LABELS=($(get_labels_from_template story.md storie))
label_args=()
for l in "${LABELS[@]}"; do label_args+=(--label "$l"); done
gh issue create --title "$title" --body-file "$body_file" "${label_args[@]}"
echo "Story issue created."
