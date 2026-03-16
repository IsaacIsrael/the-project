#!/usr/bin/env bash
# Create or update a GitHub pull request with title format: ✨ [Feature] | 🐛 [Fix] | 🚑 [Hotfix] + title.
# If a PR already exists for the current branch, updates its title and body; otherwise creates a new PR.
# Body can be provided or taken from .github/PULL_REQUEST_TEMPLATE/{feature,fix,hotfix}.md.
# With --issue N and no --body-file, reads .cursor/context/tasks/state.json (run sync-github-tasks.sh first) to add Development link and milestone.
# Usage: bash .cursor/scripts/create-or-update-pr.sh --type (feature|fix|hotfix) --title "Short description" [--base main] [--body "..."] [--body-file path] [--issue N] [--milestone "title"]
# Uses: gh, jq (for state.json when using --issue). Run from repo root.

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
  echo "Usage: $0 --type (feature|fix|hotfix) --title \"Short description\" [--base main] [--body \"...\"] [--body-file path] [--issue N] [--milestone \"title\"]" >&2
  echo "       Title will be prefixed with emoji + type (e.g. \"✨ [Feature] Short description\")." >&2
  echo "       If neither --body nor --body-file is given, body is copied from the template for that type." >&2
  echo "       --issue N: replace (issue-number) in template; if state.json exists (sync first), add Development link and use issue's milestone." >&2
  echo "       --milestone \"title\": set PR milestone (overrides issue's milestone from state)." >&2
  echo "       If a PR already exists for the current branch, it is updated instead of creating a new one." >&2
  exit 1
}

type=""
title=""
base="main"
body=""
body_file=""
issue=""
milestone=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)      type="$2";      shift 2 ;;
    --title)     title="$2";     shift 2 ;;
    --base)      base="$2";     shift 2 ;;
    --body)      body="$2";     shift 2 ;;
    --body-file) body_file="$2"; shift 2 ;;
    --issue)     issue="$2";     shift 2 ;;
    --milestone) milestone="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ -z "$type" || -z "$title" ]]; then
  echo "Missing required --type and/or --title." >&2
  usage
fi

case "$type" in
  feature) prefix="✨ [Feature]" ;;
  fix)     prefix="🐛 [Fix]"     ;;
  hotfix)  prefix="🚑 [Hotfix]"  ;;
  *)       echo "Invalid --type. Use feature, fix, or hotfix." >&2; exit 1 ;;
esac

full_title="${prefix} ${title}"

if [[ -n "$body_file" ]]; then
  if [[ ! -f "$body_file" ]]; then
    echo "Body file not found: $body_file" >&2
    exit 1
  fi
  body_to_use="$TMPDIR/body.md"
  cp "$body_file" "$body_to_use"
  # When --body-file and --issue N: inject Development + Milestone from state (if not already in body)
  state_file="$ROOT/.cursor/context/tasks/state.json"
  if [[ -n "$issue" && -f "$state_file" ]] && command -v jq &>/dev/null; then
    if [[ -z "$milestone" ]]; then
      milestone="$(jq -r --argjson n "$issue" '.issues[] | select(.number==$n) | .milestone.title // empty' "$state_file" 2>/dev/null)"
    fi
    development_url="$(jq -r --argjson n "$issue" '.issues[] | select(.number==$n) | .html_url // empty' "$state_file" 2>/dev/null)"
    if [[ -n "$development_url" ]] && ! grep -q '\*\*Development:\*\*' "$body_to_use" 2>/dev/null; then
      development_line="**Development:** [Issue #${issue}](${development_url})"
      awk -v dev="$development_line" '
        /Issue:.*#|Closes #|Relates to #/ && !done { print; print ""; print dev; done=1; next }
        { print }
      ' "$body_to_use" > "$TMPDIR/body2.md" && mv "$TMPDIR/body2.md" "$body_to_use"
    fi
    if [[ -n "$milestone" ]] && ! grep -q '\*\*Milestone:\*\*' "$body_to_use" 2>/dev/null; then
      milestone_line="**Milestone:** $milestone"
      awk -v mil="$milestone_line" '
        /^\*\*Development:\*\*/ && !done { print; print ""; print mil; done=1; next }
        /Issue:.*#|Closes #|Relates to #/ && !done { print; print ""; print mil; done=1; next }
        { print }
      ' "$body_to_use" > "$TMPDIR/body3.md" 2>/dev/null && mv "$TMPDIR/body3.md" "$body_to_use"
    fi
  fi
elif [[ -n "$body" ]]; then
  body_to_use="$TMPDIR/body.md"
  echo "$body" > "$body_to_use"
else
  template="$ROOT/.github/PULL_REQUEST_TEMPLATE/${type}.md"
  if [[ ! -f "$template" ]]; then
    echo "Template not found: $template" >&2
    exit 1
  fi
  body_to_use="$TMPDIR/body.md"
  sed "s/(issue-number)/${issue:-}/g" "$template" > "$body_to_use"

  # When --issue N and state.json exists: add Development link and get milestone
  state_file="$ROOT/.cursor/context/tasks/state.json"
  development_line=""
  if [[ -n "$issue" && -f "$state_file" ]] && command -v jq &>/dev/null; then
    development_url=""
    if [[ -z "$milestone" ]]; then
      milestone="$(jq -r --argjson n "$issue" '.issues[] | select(.number==$n) | .milestone.title // empty' "$state_file" 2>/dev/null)"
    fi
    development_url="$(jq -r --argjson n "$issue" '.issues[] | select(.number==$n) | .html_url // empty' "$state_file" 2>/dev/null)"
    if [[ -n "$development_url" ]]; then
      development_line="**Development:** [Issue #${issue}](${development_url})"
      # Insert after the first line that contains Issue: and # (e.g. Closes #7)
      awk -v dev="$development_line" '
        /Issue:.*#/ && !done { print; print ""; print dev; done=1; next }
        { print }
      ' "$body_to_use" > "$TMPDIR/body2.md" && mv "$TMPDIR/body2.md" "$body_to_use"
    fi
  fi
fi

# If we have milestone and used template (not body-file), add Milestone line to body (for visibility)
if [[ -z "$body_file" && -z "$body" && -n "$milestone" ]]; then
  milestone_line="**Milestone:** $milestone"
  awk -v mil="$milestone_line" '
    /^\*\*Development:\*\*/ && !done { print; print ""; print mil; done=1; next }
    /Issue:.*#/ && !done { print; print ""; print mil; done=1; next }
    { print }
  ' "$body_to_use" > "$TMPDIR/body3.md" 2>/dev/null && mv "$TMPDIR/body3.md" "$body_to_use"
fi

# When --issue N: ensure body contains a closing keyword so GitHub fills the Development sidebar (create and update)
if [[ -n "$issue" ]]; then
  state_file="$ROOT/.cursor/context/tasks/state.json"
  [[ -z "$milestone" && -f "$state_file" ]] && command -v jq &>/dev/null && milestone="$(jq -r --argjson n "$issue" '.issues[] | select(.number==$n) | .milestone.title // empty' "$state_file" 2>/dev/null)"
  if ! grep -qE '(Closes|Fixes|Resolves) #'"$issue"'\b' "$body_to_use" 2>/dev/null; then
    case "$type" in
      feature) close_keyword="Closes" ;;
      fix|hotfix) close_keyword="Fixes" ;;
      *) close_keyword="Closes" ;;
    esac
    printf '%s #%s\n\n' "$close_keyword" "$issue" | cat - "$body_to_use" > "$TMPDIR/body-close.md" && mv "$TMPDIR/body-close.md" "$body_to_use"
  fi
fi

# Push current branch to origin and set upstream so the PR has the latest commits (and branch exists on remote when creating)
branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$branch" != "HEAD" ]] && git remote get-url origin &>/dev/null; then
  if ! git push -u origin HEAD; then
    echo "Push failed. If your branch history was rewritten, run: git push -u origin $branch --force-with-lease" >&2
    exit 1
  fi
fi

# Create or update: if a PR already exists for the current branch, update it; otherwise create
existing_pr=""
existing_pr=$(gh pr view --json number -q '.number' 2>/dev/null) || true

if [[ -n "$existing_pr" ]]; then
  gh pr edit "$existing_pr" --title "$full_title" --body-file "$body_to_use"
  [[ -n "$milestone" ]] && gh pr edit "$existing_pr" --milestone "$milestone"
  echo "PR #${existing_pr} updated: $full_title"
else
  gh_args=(--base "$base" --title "$full_title" --body-file "$body_to_use")
  [[ -n "$milestone" ]] && gh_args+=(--milestone "$milestone")
  gh pr create "${gh_args[@]}"
  echo "PR created: $full_title"
fi
gh pr view --web
