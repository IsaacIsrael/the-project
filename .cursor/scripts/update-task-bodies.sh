#!/usr/bin/env bash
# Update GitHub **task** issue body fields. Only passed fields are changed; rest stay as-is.
# Usage:
#   Use one of:
#   • CLI:  issue_num [--field value ...]   (one task only)
#   • JSON: --json '[...]'  or  --json-file path   (one or more tasks; do not mix with positional or other flags)
#   JSON format: [ {"id": 8, "description": "...", "scope": "..."}, {"id": 9, "objective": "..."} ]
#   Keys: id (required), parent, description, objective, scope, technical_notes, acceptance_criteria, references
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

usage() {
  echo "Use one of: positional (CLI) or JSON. Do not combine them." >&2
  echo "" >&2
  echo "  CLI:  $0 issue_num [--field value ...]" >&2
  echo "        Exactly one issue number; optional fields: --parent, --description, --objective," >&2
  echo "        --scope, --technical-notes, --acceptance-criteria, --references (-file for multiline)." >&2
  echo "" >&2
  echo "  JSON: $0 --json '[{\"id\":8,\"description\":\"...\"},...]'  |  $0 --json-file path" >&2
  echo "        Array of objects with \"id\" and optional: parent, description, objective, scope," >&2
  echo "        technical_notes, acceptance_criteria, references. No other args allowed with --json." >&2
  exit 1
}

# Extract section content from issue body: from "## Title" to next "---" (exclude title and ---)
get_section() {
  local body="$1" title="$2"
  echo "$body" | sed -n "/^## ${title}\$/,/^---\$/p" | sed '1d;$d'
}

get_parent() {
  local body="$1"
  echo "$body" | sed -n '/^## Parent story$/,/^---$/p' | grep 'Parent: #' | sed 's/.*#\([0-9]*\).*/\1/' | head -1
}

task_body() {
  local parent="$1" desc="$2" obj="$3" scope="$4" tech="$5" ac="$6" refs="$7"
  cat << BODY
## Parent story
Parent: #${parent}

---

## 📖 Description
${desc}

---

## 🎯 Objective
${obj}

---

## 🧩 Scope
${scope}

---

## 🛠 Technical Notes
${tech}

---

## ✅ Acceptance Criteria
${ac}

---

## 📎 References
${refs}
BODY
}

# Update one issue: fetch current body, merge non-empty overrides, push.
# Empty string = keep current. Args: issue_num parent desc objective scope technical_notes acceptance_criteria references
update_one() {
  local issue="$1" p="$2" d="$3" o="$4" s="$5" t="$6" a="$7" r="$8"
  local body
  body=$(gh issue view "$issue" --json body -q .body 2>/dev/null) || { echo "Failed to fetch issue #$issue" >&2; return 1; }

  local cur_parent cur_description cur_objective cur_scope cur_technical_notes cur_acceptance_criteria cur_references
  cur_parent=$(get_parent "$body")
  cur_description=$(get_section "$body" "📖 Description")
  cur_objective=$(get_section "$body" "🎯 Objective")
  cur_scope=$(get_section "$body" "🧩 Scope")
  cur_technical_notes=$(get_section "$body" "🛠 Technical Notes")
  cur_acceptance_criteria=$(get_section "$body" "✅ Acceptance Criteria")
  cur_references=$(get_section "$body" "📎 References")

  [[ -z "$cur_parent" ]] && cur_parent="1"
  [[ -z "$cur_description" ]] && cur_description="_None._"
  [[ -z "$cur_objective" ]] && cur_objective="_None._"
  [[ -z "$cur_scope" ]] && cur_scope="- [ ] _Fill when ready_"
  [[ -z "$cur_technical_notes" ]] && cur_technical_notes="_None._"
  [[ -z "$cur_acceptance_criteria" ]] && cur_acceptance_criteria="- [ ] _Fill when ready_"
  [[ -z "$cur_references" ]] && cur_references="_None._"

  [[ -n "$p" ]] && cur_parent="$p"
  [[ -n "$d" ]] && cur_description="$d"
  [[ -n "$o" ]] && cur_objective="$o"
  [[ -n "$s" ]] && cur_scope="$s"
  [[ -n "$t" ]] && cur_technical_notes="$t"
  [[ -n "$a" ]] && cur_acceptance_criteria="$a"
  [[ -n "$r" ]] && cur_references="$r"

  task_body "$cur_parent" "$cur_description" "$cur_objective" "$cur_scope" "$cur_technical_notes" "$cur_acceptance_criteria" "$cur_references" > "$TMPDIR/$issue.md"
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
    p=$(echo "$item" | jq -r '.parent // empty')
    d=$(echo "$item" | jq -r '.description // empty')
    o=$(echo "$item" | jq -r '.objective // empty')
    s=$(echo "$item" | jq -r '.scope // empty')
    t=$(echo "$item" | jq -r '.technical_notes // empty')
    a=$(echo "$item" | jq -r '.acceptance_criteria // empty')
    r=$(echo "$item" | jq -r '.references // empty')
    update_one "$id" "$p" "$d" "$o" "$s" "$t" "$a" "$r"
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
    p=$(echo "$item" | jq -r '.parent // empty')
    d=$(echo "$item" | jq -r '.description // empty')
    o=$(echo "$item" | jq -r '.objective // empty')
    s=$(echo "$item" | jq -r '.scope // empty')
    t=$(echo "$item" | jq -r '.technical_notes // empty')
    a=$(echo "$item" | jq -r '.acceptance_criteria // empty')
    r=$(echo "$item" | jq -r '.references // empty')
    update_one "$id" "$p" "$d" "$o" "$s" "$t" "$a" "$r"
  done
  echo "Done."
  exit 0
fi

# --- CLI mode (single issue only) ---
ISSUE_NUM=""
parent_set=0 description_set=0 objective_set=0 scope_set=0 technical_notes_set=0 acceptance_criteria_set=0 references_set=0
parent="" description="" objective="" scope="" technical_notes="" acceptance_criteria="" references=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent) parent="$2"; parent_set=1; shift 2 ;;
    --description) description="$2"; description_set=1; shift 2 ;;
    --description-file) description=$(cat "$2"); description_set=1; shift 2 ;;
    --objective) objective="$2"; objective_set=1; shift 2 ;;
    --objective-file) objective=$(cat "$2"); objective_set=1; shift 2 ;;
    --scope) scope="$2"; scope_set=1; shift 2 ;;
    --scope-file) scope=$(cat "$2"); scope_set=1; shift 2 ;;
    --technical-notes) technical_notes="$2"; technical_notes_set=1; shift 2 ;;
    --technical-notes-file) technical_notes=$(cat "$2"); technical_notes_set=1; shift 2 ;;
    --acceptance-criteria) acceptance_criteria="$2"; acceptance_criteria_set=1; shift 2 ;;
    --acceptance-criteria-file) acceptance_criteria=$(cat "$2"); acceptance_criteria_set=1; shift 2 ;;
    --references) references="$2"; references_set=1; shift 2 ;;
    --references-file) references=$(cat "$2"); references_set=1; shift 2 ;;
    --help|-h) usage ;;
    --json|--json-file)
      echo "Do not mix JSON with positional. Use either: issue_num --field ... (CLI) or --json '[...]' / --json-file path (JSON) only." >&2
      usage
      ;;
    [0-9]*)
      if [[ -n "$ISSUE_NUM" ]]; then
        echo "Only one issue number is allowed in CLI mode. For multiple tasks use --json or --json-file." >&2
        usage
      fi
      ISSUE_NUM="$1"; shift
      ;;
    *) echo "Unknown option or invalid issue number: $1" >&2; usage ;;
  esac
done

if [[ -z "$ISSUE_NUM" ]]; then
  echo "One issue number is required (or use --json / --json-file for multiple tasks)." >&2
  usage
fi

any_set=$(( parent_set || description_set || objective_set || scope_set || technical_notes_set || acceptance_criteria_set || references_set ))
if [[ $any_set -eq 0 ]]; then
  echo "At least one field (--description, --objective, etc.) is required." >&2
  usage
fi

p=""; (( parent_set )) && p="$parent"
d=""; (( description_set )) && d="$description"
o=""; (( objective_set )) && o="$objective"
s=""; (( scope_set )) && s="$scope"
t=""; (( technical_notes_set )) && t="$technical_notes"
a=""; (( acceptance_criteria_set )) && a="$acceptance_criteria"
r=""; (( references_set )) && r="$references"
update_one "$ISSUE_NUM" "$p" "$d" "$o" "$s" "$t" "$a" "$r"
echo "Done."
