# Spinner: optional message. Use start_spinner [msg] & then stop_spinner before output.
# Set SPINNER_MSG before start_spinner to override default, or pass as first arg.
spinner_pid=""

start_spinner() {
  local msg="${1:-${SPINNER_MSG:-Checking versions…}}"
  while true; do
    for c in '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'; do
      printf '\r  %s %s  ' "$c" "$msg"
      sleep 0.08
    done
  done
}

stop_spinner() {
  [[ -n "$spinner_pid" ]] && kill "$spinner_pid" 2>/dev/null
  printf '\r%*s\r' 60 ""
}
