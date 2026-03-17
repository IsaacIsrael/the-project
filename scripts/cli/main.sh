#!/usr/bin/env bash
# CLI: doctor (version check) and install. Entry point. Run from repo root.
# Usage: cli [command]
#   (no args)   show options: doctor | install
#   doctor      run setup/version check (Node, npm, nvm, Ruby, rbenv)
#   install     set up environment (nvm, Node, npm, rbenv Ruby from .ruby-version)
#   help, -h    show help
#   --no-banner skip banner (for agents/CI)

set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CLI_NO_BANNER=
while [[ "${1:-}" == "--no-banner" ]]; do
  CLI_NO_BANNER=1
  shift
done

CMD="${1:-}"
if [[ -z "$CMD" ]]; then
  CMD=menu
else
  case "$CMD" in
    -h|--help|help)   CMD=help ;;
    doctor|check|setup) CMD=doctor ;;
    install)         CMD=install ;;
    *)               CMD=help ;;
  esac
fi

show_banner() {
  [[ -n "$CLI_NO_BANNER" ]] && return
  echo ""
  echo '████████╗██╗  ██╗███████╗    ██████╗ ██████╗  ██████╗      ██╗███████╗ ██████╗████████╗     ██████╗██╗     ██╗'
  echo '╚══██╔══╝██║  ██║██╔════╝    ██╔══██╗██╔══██╗██╔═══██╗     ██║██╔════╝██╔════╝╚══██╔══╝    ██╔════╝██║     ██║'
  echo '   ██║   ███████║█████╗      ██████╔╝██████╔╝██║   ██║     ██║█████╗  ██║        ██║       ██║     ██║     ██║'
  echo '   ██║   ██╔══██║██╔══╝      ██╔═══╝ ██╔══██╗██║   ██║██   ██║██╔══╝  ██║        ██║       ██║     ██║     ██║'
  echo '   ██║   ██║  ██║███████╗    ██║     ██║  ██║╚██████╔╝╚█████╔╝███████╗╚██████╗   ██║       ╚██████╗███████╗██║'
  echo '   ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚════╝ ╚══════╝ ╚═════╝   ╚═╝        ╚═════╝╚══════╝╚═╝'
  echo ""
}

show_menu() {
  show_banner
  echo "  Options:"
  echo ""
  echo "    1) doctor   run setup/version check (Node, npm, nvm, Ruby, rbenv)"
  echo "    2) install  set up environment (nvm, Node, npm, Ruby from .ruby-version)"
  echo ""
  printf "  Choose [1/2]: "
  read -r choice
  echo ""
  case "$(echo "$choice" | tr '[:upper:]' '[:lower:]')" in
    1|doctor)  run_doctor --no-banner ;;
    2|install) run_install --no-banner ;;
    *)
      echo "  Invalid choice. Run  npm run cli -- doctor  or  npm run cli -- install"
      echo ""
      exit 1
      ;;
  esac
}

show_help() {
  echo ""
  echo "  Usage: cli [command]"
  echo ""
  echo "  Commands:"
  echo "    doctor   run setup/version check (Node, npm, nvm, Ruby, rbenv)"
  echo "    install  set up environment (nvm, Node, npm, Ruby from .ruby-version)"
  echo "    help     show this help"
  echo ""
  echo "  Options:"
  echo "    --no-banner  skip banner (for agents/CI)"
  echo ""
  echo "  Run  npm run cli  with no args to see options."
  echo ""
}

run_doctor() {
  [[ "$1" != "--no-banner" ]] && show_banner

  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  source "${SCRIPT_DIR}/lib/spinner.sh"
  source "${SCRIPT_DIR}/lib/display.sh"
  source "${SCRIPT_DIR}/lib/brew.sh"
  source "${SCRIPT_DIR}/lib/nvm.sh"
  source "${SCRIPT_DIR}/lib/node.sh"
  source "${SCRIPT_DIR}/lib/rbenv.sh"
  source "${SCRIPT_DIR}/lib/ruby.sh"

  SPINNER_MSG="Checking versions…" start_spinner &
  spinner_pid=$!
  disown $spinner_pid 2>/dev/null || true
  trap 'stop_spinner' EXIT

  check_brew
  nvm_check
  node_check
  rbenv_check
  check_ruby

  stop_spinner
  trap - EXIT
  set_summary_from_results
  display_results

  [[ "$summary_msg" == "failed." ]] && exit 1
  exit 0
}

  exit 0
}

run_install() {
  [[ "$1" != "--no-banner" ]] && show_banner
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  source "${SCRIPT_DIR}/lib/spinner.sh"
  source "${SCRIPT_DIR}/lib/display.sh"
  source "${SCRIPT_DIR}/lib/nvm.sh"
  source "${SCRIPT_DIR}/lib/node.sh"
  source "${SCRIPT_DIR}/lib/rbenv.sh"
  source "${SCRIPT_DIR}/lib/ruby.sh"
  source "${SCRIPT_DIR}/lib/brew.sh"

  ensure_brew || return $?
  echo ""
  nvm_ensure || return $?
  echo ""
  node_ensure || return $?
  echo ""
  rbenv_ensure || return $?
  echo ""
  ensure_ruby || return $?
  echo ""

  SPINNER_MSG="Installing dependencies…" start_spinner &
  spinner_pid=$!
  disown $spinner_pid 2>/dev/null || true
  trap 'stop_spinner' EXIT
  stop_spinner
  trap - EXIT
  echo ""
  echo "  ✅  Setup done."
  echo ""
}

case "$CMD" in
  menu)   show_menu ;;
  help)   show_help ;;
  doctor) run_doctor ;;
  install) run_install ;;
  *)      show_help; exit 1 ;;
esac
