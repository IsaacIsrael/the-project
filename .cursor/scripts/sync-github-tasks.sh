#!/usr/bin/env bash
# Sync GitHub issues → .cursor/context/tasks/
# Run: bash .cursor/scripts/sync-github-tasks.sh
# Uses GitHub CLI (gh) and jq. Repo from package.json "repository" or env GITHUB_REPO.
set -e

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TASKS_DIR="$ROOT/.cursor/context/tasks"
STATE_FILE="$TASKS_DIR/state.json"
TASKS_MD="$TASKS_DIR/TASKS.md"

if ! command -v gh &>/dev/null; then
  echo "error: GitHub CLI (gh) is required. See README → Project agent dependencies." >&2
  exit 1
fi
if ! command -v jq &>/dev/null; then
  echo "error: jq is required. See README → Project agent dependencies." >&2
  exit 1
fi

# Repo: git remote origin
REPO=""
if git -C "$ROOT" rev-parse --git-dir &>/dev/null; then
  URL="$(git -C "$ROOT" remote get-url origin 2>/dev/null)" || true
  if [[ -n "$URL" ]]; then
    URL="${URL%.git}"
    REPO="$(echo "$URL" | sed -E 's#^(https?://[^/]+/|git@[^:]+:)([^/]+/[^/]+)$#\2#')"
  fi
fi
REPO="${REPO:-$GITHUB_REPO}"
if [[ -z "$REPO" ]]; then
  echo "error: could not determine repo. Run from a git clone with origin remote, or set GITHUB_REPO=owner/repo." >&2
  exit 1
fi
OWNER="${REPO%%/*}"
REPO_NAME="${REPO#*/}"

echo "Fetching issues from $REPO ..."
mkdir -p "$TASKS_DIR"

# gh api: issues (for hierarchy) + milestones (all repo milestones, including with 0 issues)
RAW="$(mktemp)"
MILESTONES_RAW="$(mktemp)"
trap 'rm -f "$RAW" "$MILESTONES_RAW"' EXIT
gh api "repos/$OWNER/$REPO_NAME/issues?state=all" --paginate | jq -s 'add' > "$RAW"
gh api "repos/$OWNER/$REPO_NAME/milestones?state=all" --paginate 2>/dev/null | jq -s 'add // []' > "$MILESTONES_RAW" || echo "[]" > "$MILESTONES_RAW"
if [[ ! -s "$RAW" ]] || [[ "$(cat "$RAW")" == "null" ]]; then
  echo "error: gh api (issues) returned no data. Check 'gh auth status' and repo access." >&2
  exit 1
fi

SYNCED_AT="$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"
jq -n \
  --argjson raw "$(cat "$RAW")" \
  --argjson rawMilestones "$(cat "$MILESTONES_RAW")" \
  --arg syncedAt "$SYNCED_AT" \
  --arg repo "$REPO" \
  '[$raw[] | select(.pull_request == null) | {
    number, title, state,
    body: (.body // null),
    labels: [.labels[]?.name // empty],
    parent_issue_url: (.parent_issue_url // null),
    html_url, created_at, updated_at,
    milestone: (if .milestone then {number: .milestone.number, title: .milestone.title} else null end),
    sub_issues_summary: (.sub_issues_summary // null)
  }] as $issues |
  ([$issues[] | select(.parent_issue_url == null) | .number] | sort) as $roots |
  ([$issues[] | . as $cur | { key: ($cur.number | tostring), value: {
    number: $cur.number, title: $cur.title, state: $cur.state,
    children: [$issues[] | select(.parent_issue_url != null and ((.parent_issue_url / "/" | .[-1] | tonumber) == $cur.number)) | .number]
  }}] | from_entries) as $byNumber |
  ([$rawMilestones[]? | {number: .number, title: .title, issue_count: ((.open_issues // 0) + (.closed_issues // 0)), state: .state}] | sort_by(.number)) as $milestones |
  { "syncedAt": $syncedAt, "repo": $repo, "issues": $issues, "milestones": $milestones, "hierarchy": { "roots": $roots, "byNumber": $byNumber } }
  ' > "$STATE_FILE.tmp"

if [[ ! -s "$STATE_FILE.tmp" ]]; then
  echo "jq state build failed" >&2
  exit 1
fi
mv "$STATE_FILE.tmp" "$STATE_FILE"

# TASKS.md from state.json
MILESTONE_COUNT="$(jq '.milestones | length' "$STATE_FILE")"
ISSUE_COUNT="$(jq '.issues | length' "$STATE_FILE")"
echo "# Project tasks (synced from GitHub)" > "$TASKS_MD"
echo "" >> "$TASKS_MD"
echo "Repo: **$OWNER/$REPO_NAME** · Last sync: $SYNCED_AT · **$MILESTONE_COUNT** milestones · **$ISSUE_COUNT** issues" >> "$TASKS_MD"
echo "" >> "$TASKS_MD"
echo "---" >> "$TASKS_MD"
echo "" >> "$TASKS_MD"

emit_issue() {
  local num="$1"
  local depth="${2:-0}"
  local indent
  indent="$(printf '%*s' "$((depth * 2))" '')"
  local title state url
  title="$(jq -r --argjson n "$num" '.issues[] | select(.number == $n) | .title' "$STATE_FILE")"
  state="$(jq -r --argjson n "$num" '.issues[] | select(.number == $n) | .state' "$STATE_FILE")"
  url="$(jq -r --argjson n "$num" '.issues[] | select(.number == $n) | .html_url' "$STATE_FILE")"
  local icon="⬜"
  case "$state" in closed|CLOSED) icon="✅";; esac
  echo "${indent}- $icon [#$num]($url) **$title** $state" >> "$TASKS_MD"
  while read -r child; do
    [[ -z "$child" ]] && continue
    emit_issue "$child" "$((depth + 1))"
  done < <(jq -r --argjson n "$num" '.hierarchy.byNumber["\($n)"]?.children[]? // empty' "$STATE_FILE" 2>/dev/null)
}

# For each milestone: heading + issues that belong to it (with hierarchy)
while IFS= read -r line; do
  m_num="$(echo "$line" | cut -d$'\t' -f1)"
  m_count="$(echo "$line" | cut -d$'\t' -f3)"
  m_title="$(echo "$line" | cut -d$'\t' -f2)"
  [[ -z "$m_num" ]] && continue
  echo "## $m_title · $m_count issue(s) · [view](https://github.com/$OWNER/$REPO_NAME/milestone/$m_num)" >> "$TASKS_MD"
  echo "" >> "$TASKS_MD"
  roots="$(jq -r --argjson M "$m_num" '[.hierarchy.roots[] as $r | .issues[] | select(.number == $r and .milestone != null and .milestone.number == $M) | .number][]' "$STATE_FILE" 2>/dev/null)"
  for r in $roots; do
    [[ -n "$r" ]] && emit_issue "$r"
  done
  echo "" >> "$TASKS_MD"
done < <(jq -r '.milestones[]? | "\(.number)\t\(.title)\t\(.issue_count)"' "$STATE_FILE" 2>/dev/null)

# Issues without milestone
no_milestone_roots="$(jq -r '[.hierarchy.roots[] as $r | .issues[] | select(.number == $r and .milestone == null) | .number][]' "$STATE_FILE" 2>/dev/null)"
if [[ -n "$no_milestone_roots" ]]; then
  echo "## No milestone" >> "$TASKS_MD"
  echo "" >> "$TASKS_MD"
  for r in $no_milestone_roots; do
    [[ -n "$r" ]] && emit_issue "$r"
  done
  echo "" >> "$TASKS_MD"
fi

echo "" >> "$TASKS_MD"
echo "---" >> "$TASKS_MD"
echo "" >> "$TASKS_MD"
echo "Run \`bash .cursor/scripts/sync-github-tasks.sh\` to refresh." >> "$TASKS_MD"

MILESTONE_COUNT="$(jq '.milestones | length' "$STATE_FILE")"
ISSUE_COUNT="$(jq '.issues | length' "$STATE_FILE")"
echo "Wrote $STATE_FILE"
echo "Wrote $TASKS_MD"
echo "Milestones: $MILESTONE_COUNT · Issues: $ISSUE_COUNT"
