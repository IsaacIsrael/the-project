#!/usr/bin/env bash
# Update GitHub **story** issue body fields. Only passed fields are changed; rest stay as-is.
# Usage:
#   Use one of:
#   • CLI:  issue_num [--field value ...]   (one story only; 1–6)
#   • JSON: --json '[...]'  or  --json-file path   (one or more stories; do not mix with positional or other flags)
#   JSON keys: id (required), description, objective, acceptance_criteria
# Uses: gh, jq (for JSON). Run from repo root.

set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

if ! command -v gh &>/dev/null || ! gh auth status &>/dev/null; then
  echo "GitHub CLI (gh) must be installed and authenticated." >&2
  exit 1
fi

STORY_IDS=(1 2 3 4 5 6)

usage() {
  echo "Use one of: positional (CLI) or JSON. Do not combine them." >&2
  echo "" >&2
  echo "  CLI:  $0 issue_num [--field value ...]" >&2
  echo "        Exactly one story number (1–6); optional fields: --description, --objective," >&2
  echo "        --acceptance-criteria (-file for multiline)." >&2
  echo "" >&2
  echo "  JSON: $0 --json '[{\"id\":1,\"description\":\"...\"},...]'  |  $0 --json-file path" >&2
  echo "        Array of objects with \"id\" and optional: description, objective, acceptance_criteria." >&2
  echo "        No other args allowed with --json." >&2
  exit 1
}

get_section() {
  local body="$1" title="$2"
  echo "$body" | sed -n "/^## ${title}\$/,/^---\$/p" | sed '1d;$d'
}

story_body() {
  local desc="$1" obj="$2" ac="${3:-- [ ] _Fill when ready_}"
  cat << BODY
## 📖 Description
${desc}

---

## 🎯 Objective
${obj}

---

## ✅ Acceptance Criteria
${ac}
BODY
}

update_one() {
  local issue="$1" d="$2" o="$3" a="$4"
  local body
  body=$(gh issue view "$issue" --json body -q .body 2>/dev/null) || { echo "Failed to fetch issue #$issue" >&2; return 1; }

  local cur_description cur_objective cur_acceptance_criteria
  cur_description=$(get_section "$body" "📖 Description")
  cur_objective=$(get_section "$body" "🎯 Objective")
  cur_acceptance_criteria=$(get_section "$body" "✅ Acceptance Criteria")

  [[ -z "$cur_description" ]] && cur_description="_None._"
  [[ -z "$cur_objective" ]] && cur_objective="_None._"
  [[ -z "$cur_acceptance_criteria" ]] && cur_acceptance_criteria="- [ ] _Fill when ready_"

  [[ -n "$d" ]] && cur_description="$d"
  [[ -n "$o" ]] && cur_objective="$o"
  [[ -n "$a" ]] && cur_acceptance_criteria="$a"

  story_body "$cur_description" "$cur_objective" "$cur_acceptance_criteria" > "$TMPDIR/$issue.md"
  gh issue edit "$issue" --body-file "$TMPDIR/$issue.md"
  echo "  #$issue updated"
}

# --- JSON mode ---
if [[ "$1" == "--json" ]]; then
  if [[ -z "${2:-}" ]]; then
    echo "Missing value for --json." >&2
    usage
  fi
  JSON_STR="$2"
  shift 2
  if [[ $# -gt 0 ]]; then
    echo "Do not use --json with a positional issue number or other options. Use either: issue_num --field ..., or --json '[...]' alone." >&2
    usage
  fi
  if ! command -v jq &>/dev/null; then
    echo "jq is required for --json. Install from https://jqlang.github.io/jq/download/" >&2
    exit 1
  fi
  if ! echo "$JSON_STR" | jq -e '. | type == "array"' &>/dev/null; then
    echo "JSON must be an array of objects with \"id\" and optional fields." >&2
    exit 1
  fi
  count=$(echo "$JSON_STR" | jq 'length')
  for i in $(seq 0 $(( count - 1 )) ); do
    item=$(echo "$JSON_STR" | jq -c ".[$i]")
    id=$(echo "$item" | jq -r '.id')
    if [[ -z "$id" || "$id" == "null" ]]; then
      echo "Entry $i: missing \"id\"." >&2
      exit 1
    fi
    if [[ ! " ${STORY_IDS[*]} " =~ " ${id} " ]]; then
      echo "Entry $i: invalid story id $id (allowed: ${STORY_IDS[*]})." >&2
      exit 1
    fi
    d=$(echo "$item" | jq -r '.description // empty')
    o=$(echo "$item" | jq -r '.objective // empty')
    a=$(echo "$item" | jq -r '.acceptance_criteria // empty')
    update_one "$id" "$d" "$o" "$a"
  done
  echo "Done."
  exit 0
fi

if [[ "$1" == "--json-file" ]]; then
  if [[ -z "${2:-}" || ! -f "${2:-}" ]]; then
    echo "Missing or invalid file for --json-file." >&2
    usage
  fi
  JSON_STR=$(cat "$2")
  shift 2
  if [[ $# -gt 0 ]]; then
    echo "Do not use --json-file with a positional issue number or other options. Use either: issue_num --field ..., or --json-file path alone." >&2
    usage
  fi
  if ! command -v jq &>/dev/null; then
    echo "jq is required for --json-file. Install from https://jqlang.github.io/jq/download/" >&2
    exit 1
  fi
  if ! echo "$JSON_STR" | jq -e '. | type == "array"' &>/dev/null; then
    echo "JSON file must contain an array of objects with \"id\" and optional fields." >&2
    exit 1
  fi
  count=$(echo "$JSON_STR" | jq 'length')
  for i in $(seq 0 $(( count - 1 )) ); do
    item=$(echo "$JSON_STR" | jq -c ".[$i]")
    id=$(echo "$item" | jq -r '.id')
    if [[ -z "$id" || "$id" == "null" ]]; then
      echo "Entry $i: missing \"id\"." >&2
      exit 1
    fi
    if [[ ! " ${STORY_IDS[*]} " =~ " ${id} " ]]; then
      echo "Entry $i: invalid story id $id (allowed: ${STORY_IDS[*]})." >&2
      exit 1
    fi
    d=$(echo "$item" | jq -r '.description // empty')
    o=$(echo "$item" | jq -r '.objective // empty')
    a=$(echo "$item" | jq -r '.acceptance_criteria // empty')
    update_one "$id" "$d" "$o" "$a"
  done
  echo "Done."
  exit 0
fi

# --- CLI mode (single story only) ---
ISSUE_NUM=""
description_set=0 objective_set=0 acceptance_criteria_set=0
description="" objective="" acceptance_criteria=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --description) description="$2"; description_set=1; shift 2 ;;
    --description-file) description=$(cat "$2"); description_set=1; shift 2 ;;
    --objective) objective="$2"; objective_set=1; shift 2 ;;
    --objective-file) objective=$(cat "$2"); objective_set=1; shift 2 ;;
    --acceptance-criteria) acceptance_criteria="$2"; acceptance_criteria_set=1; shift 2 ;;
    --acceptance-criteria-file) acceptance_criteria=$(cat "$2"); acceptance_criteria_set=1; shift 2 ;;
    --help|-h) usage ;;
    --json|--json-file)
      echo "Do not mix JSON with positional. Use either: issue_num --field ... (CLI) or --json '[...]' / --json-file path (JSON) only." >&2
      usage
      ;;
    [0-9]*)
      if [[ -n "$ISSUE_NUM" ]]; then
        echo "Only one story number is allowed in CLI mode. For multiple stories use --json or --json-file." >&2
        usage
      fi
      if [[ ! " ${STORY_IDS[*]} " =~ " ${1} " ]]; then
        echo "Invalid story ID: $1 (allowed: ${STORY_IDS[*]})" >&2
        usage
      fi
      ISSUE_NUM="$1"; shift
      ;;
    *) echo "Unknown option or invalid story number: $1" >&2; usage ;;
  esac
done

if [[ -z "$ISSUE_NUM" ]]; then
  echo "One story number (1–6) is required (or use --json / --json-file for multiple stories)." >&2
  usage
fi

any_set=$(( description_set || objective_set || acceptance_criteria_set ))
if [[ $any_set -eq 0 ]]; then
  echo "At least one field (--description, --objective, --acceptance-criteria) is required." >&2
  usage
fi

d=""; (( description_set )) && d="$description"
o=""; (( objective_set )) && o="$objective"
a=""; (( acceptance_criteria_set )) && a="$acceptance_criteria"
update_one "$ISSUE_NUM" "$d" "$o" "$a"
echo "Done."
