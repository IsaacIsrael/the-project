# Single file for all CLI display: check/ensure helpers and doctor results.
# Sourced by main.sh; provides _check_display, _ensure_display, _fatal_display, display_results.

# --- Helpers (used by brew, nvm, node, rbenv, ruby) ---

# Set emoji + message variables for a check result. Used by doctor.
# Usage: _check_display <emoji_var> <msg_var> <status> [message_or_key] [optional_arg]
#   status: ok | fail | warn | skip
#   message: any text, or for fail: "not_installed" → "not installed"; "expected" → "expected <optional_arg>"
_check_display() {
  local emoji_var="$1" msg_var="$2" status="$3" msg="${4:-}" arg="${5:-}"
  local e m
  case "$status" in
    ok)   e="✅"; m="$msg" ;;
    fail)
      e="❌"
      case "$msg" in
        not_installed) m="not installed" ;;
        expected)      m="expected ${arg}" ;;
        *)             m="$msg" ;;
      esac
      ;;
    warn) e="⚠️"; m="$msg" ;;
    skip) e="⏭️"; m="$msg" ;;
    *)    e="⏭️"; m="$msg" ;;
  esac
  printf -v "$emoji_var" '%s' "$e"
  printf -v "$msg_var" '%s' "$m"
}

# Echo one ensure line: "  <emoji>  <message>". Same status/message rules as _check_display.
# Usage: _ensure_display <status> [message_or_key] [optional_arg]
_ensure_display() {
  local status="$1" msg="${2:-}" arg="${3:-}"
  local e m
  case "$status" in
    ok)   e="✅"; m="$msg" ;;
    fail)
      e="❌"
      case "$msg" in
        not_installed) m="not installed" ;;
        expected)      m="expected ${arg}" ;;
        *)             m="$msg" ;;
      esac
      ;;
    warn) e="⚠️"; m="$msg" ;;
    skip) e="⏭️"; m="$msg" ;;
    *)    e="⏭️"; m="$msg" ;;
  esac
  echo "  $e  $m"
}

# Stop spinner (if any), print fail line, then exit 1. Use for unrecoverable errors.
# Usage: _fatal_display <message>
_fatal_display() {
  type stop_spinner &>/dev/null && stop_spinner
  echo ""
  _ensure_display fail "${1:-Failed.}"
  echo ""
  exit 1
}

# --- Doctor output (data-driven: add rows to DISPLAY_RESULT_ROWS to extend) ---

# Row format: "Label · sublabel|emoji_var|msg_var|msg_default". msg_default used when msg_var is unset.
DISPLAY_RESULT_ROWS=(
  "Homebrew · installed|brew_emoji|brew_msg|—"
  "nvm · installed|nvm_emoji|nvm_msg|"
  "nvm · configured|nvm_configured_emoji|nvm_configured_msg|(nvm not installed)"
  "nvm · auto load config|nvm_zshhook_emoji|nvm_zshhook_msg|n/a"
  "Node · version|node_emoji|node_msg|"
  "Node · npm|npm_emoji|npm_msg|"
  "rbenv · installed|rbenv_emoji|rbenv_msg|—"
  "rbenv · configured|rbenv_configured_emoji|rbenv_configured_msg|—"
  "Ruby · version|ruby_emoji|ruby_msg|—"
)

# Footer is shown when any of these globals is 1.
DISPLAY_FOOTER_VARS=( brew_footer node_footer nvm_footer rbenv_footer ruby_footer )

# Set summary_emoji and summary_msg from DISPLAY_RESULT_ROWS: if any row here has ❌, summary = failed; else passed.
# Call before display_results so the summary line reflects all checks (doctor) or only run checks (ci).
set_summary_from_results() {
  local line label emoji_var msg_var msg_default e
  for line in "${DISPLAY_RESULT_ROWS[@]}"; do
    IFS='|' read -r label emoji_var msg_var msg_default <<< "$line"
    e="${!emoji_var:-—}"
    if [[ "$e" == "❌" ]]; then
      _check_display summary_emoji summary_msg fail "failed."
      return
    fi
  done
  _check_display summary_emoji summary_msg ok "passed."
}

# Print doctor check results. Uses DISPLAY_RESULT_ROWS and DISPLAY_FOOTER_VARS.
# Optional first arg: "ci" or "compact" — only print rows that were set (emoji != —), no footer.
display_results() {
  local compact=
  [[ "$1" == "ci" || "$1" == "compact" ]] && compact=1
  echo ""
  local line label emoji_var msg_var msg_default e m
  for line in "${DISPLAY_RESULT_ROWS[@]}"; do
    IFS='|' read -r label emoji_var msg_var msg_default <<< "$line"
    e="${!emoji_var:-—}"
    [[ -n "$compact" && "$e" == "—" ]] && continue
    m="${!msg_var:-$msg_default}"
    printf "  %s  %-24s  %s\n" "$e" "$label" "$m"
  done
  echo ""
  echo "  ${summary_emoji:-—}  Setup and version check ${summary_msg:-—}"
  if [[ -z "$compact" ]]; then
    local show_footer=0 v
    for v in "${DISPLAY_FOOTER_VARS[@]}"; do
      [[ "${!v:-0}" -eq 1 ]] && show_footer=1 && break
    done
    if [[ "$show_footer" -eq 1 ]]; then
      echo ""
      echo "  💡  Make sure the environment is set up (e.g. npm run cli -- install)"
    fi
  fi
  echo ""
}
