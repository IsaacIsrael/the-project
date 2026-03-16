#!/usr/bin/env bash
# Create a GitHub **task** issue (Parent, Description, Objective, Scope, Tech Notes, AC, References).
# Labels are read from .github/ISSUE_TEMPLATE/task.md so changing the template updates behavior without editing this script.
# Usage: bash .cursor/scripts/create-task.sh --parent STORY_ISSUE_NUM [--title "Title"] [--description "..."] ...
#   Use -file suffix for multiline. Default title: "[Task] New task".
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
  echo "Usage: $0 --parent STORY_ISSUE_NUM [--title \"Title\"] [--description \"...\"] [--objective \"...\"]" >&2
  echo "       [--scope \"...\"] [--technical-notes \"...\"] [--acceptance-criteria \"...\"] [--references \"...\"]" >&2
  echo "       Labels come from .github/ISSUE_TEMPLATE/task.md. Default title: \"[Task] New task\"." >&2
  exit 1
}

# Read labels from template frontmatter. Arg: template filename (e.g. task.md). Fallback: second arg is default label.
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

parent=""
title="[Task] New task"
description="Clearly describe the purpose of this task. What problem does it solve or what value does it add?"
objective="What is the expected outcome once this task is completed?"
scope="- [ ] Item 1
- [ ] Item 2
- [ ] Item 3"
technical_notes="Include implementation details, constraints, decisions, or references."
acceptance_criteria="- [ ] Criteria 1
- [ ] Criteria 2
- [ ] Criteria 3"
references="Links to documentation, related issues, designs, or external resources."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent) parent="$2"; shift 2 ;;
    --title) title="$2"; shift 2 ;;
    --description) description="$2"; shift 2 ;;
    --description-file) description=$(cat "$2"); shift 2 ;;
    --objective) objective="$2"; shift 2 ;;
    --objective-file) objective=$(cat "$2"); shift 2 ;;
    --scope) scope="$2"; shift 2 ;;
    --scope-file) scope=$(cat "$2"); shift 2 ;;
    --technical-notes) technical_notes="$2"; shift 2 ;;
    --technical-notes-file) technical_notes=$(cat "$2"); shift 2 ;;
    --acceptance-criteria) acceptance_criteria="$2"; shift 2 ;;
    --acceptance-criteria-file) acceptance_criteria=$(cat "$2"); shift 2 ;;
    --references) references="$2"; shift 2 ;;
    --references-file) references=$(cat "$2"); shift 2 ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ -z "$parent" ]]; then
  echo "Missing required --parent STORY_ISSUE_NUM (the story issue number this task belongs to)." >&2
  usage
fi

body_file="$TMPDIR/body.md"
cat << BODY > "$body_file"
## Parent story
Parent: #${parent}

---

## 📖 Description
${description}

---

## 🎯 Objective
${objective}

---

## 🧩 Scope
${scope}

---

## 🛠 Technical Notes
${technical_notes}

---

## ✅ Acceptance Criteria
${acceptance_criteria}

---

## 📎 References
${references}
BODY

LABELS=($(get_labels_from_template task.md tasks))
label_args=()
for l in "${LABELS[@]}"; do label_args+=(--label "$l"); done
gh issue create --title "$title" --body-file "$body_file" "${label_args[@]}"
echo "Task issue created."
