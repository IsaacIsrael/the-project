# Spinner: start_spinner "msg" (background); stop_spinner when done.
# Uses CPR to pin the spinner to one row; ensure lines (install) print below.
# If CPR/tty is unavailable, no spinner runs (install still prints normally).

spinner_pid=""

_spinner_tty_out() {
  if [[ -w /dev/tty ]]; then
    printf '%b' "$@" > /dev/tty
  else
    printf '%b' "$@"
  fi
}

# 1-based cursor row, or empty if unavailable.
_spinner_read_row() {
  [[ -r /dev/tty && -w /dev/tty ]] || return 1
  local pos
  printf '\033[6n' > /dev/tty
  IFS=';' read -rsdR pos < /dev/tty 2>/dev/null || return 1
  pos=${pos#*[}
  [[ "$pos" =~ ^[0-9]+ ]] || return 1
  printf '%s' "${pos%%;*}"
}

_display_spinner_coord() {
  local msg="${1:-$SPINNER_MSG}"
  local row="${SPINNER_ROW:?}"
  while true; do
    for c in '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'; do
      _spinner_tty_out "$(printf '\033[%d;1H\033[K  %s %s  ' "$row" "$c" "$msg")"
      sleep 0.08
    done
  done
}

start_spinner() {
  local msg="${1:-${SPINNER_MSG:-Checking versions…}}"
  SPINNER_MSG="$msg"
  SPINNER_COORD_MODE=
  echo ""
  local row
  row=$(_spinner_read_row) || row=
  if [[ -n "$row" ]]; then
    export SPINNER_ROW="$row"
    SPINNER_NEXT_ROW=$((row + 1))
    export SPINNER_COORD_MODE=1
    resume_spinner
    trap 'stop_spinner' EXIT
  else
    spinner_pid=
    trap 'stop_spinner' EXIT
  fi
}

resume_spinner() {
  [[ -n "${SPINNER_COORD_MODE:-}" ]] || return 0
  _display_spinner_coord "$SPINNER_MSG" &
  spinner_pid=$!
  disown "$spinner_pid" 2>/dev/null || true
}

pause_spinner() {
  [[ -n "$spinner_pid" ]] && kill "$spinner_pid" 2>/dev/null
  spinner_pid=
  if [[ -n "${SPINNER_COORD_MODE:-}" && -n "${SPINNER_ROW:-}" ]]; then
    _spinner_tty_out "$(printf '\033[%d;1H\033[K' "$SPINNER_ROW")"
  fi
}

stop_spinner() {
  pause_spinner
  unset SPINNER_COORD_MODE SPINNER_ROW SPINNER_NEXT_ROW 2>/dev/null || true
  trap - EXIT 2>/dev/null || true
}
