#!/usr/bin/env bash
# CLI: doctor (version check) and install. Entry point. Run from repo root.
# Usage: cli [command]
#   (no args)   show options: doctor | install
#   doctor      run setup/version check (Node, npm, nvm)
#   install     set up environment (nvm → Node from .nvmrc → npm install)
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
  echo "    1) doctor   run setup/version check (Node, npm, nvm)"
  echo "    2) install  set up environment (nvm, Node, npm install)"
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
  echo "    doctor   run setup/version check (Node, npm, nvm)"
  echo "    install  set up environment (nvm, Node, npm install)"
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
  source "${SCRIPT_DIR}/lib/nvm.sh"
  source "${SCRIPT_DIR}/lib/node.sh"
  source "${SCRIPT_DIR}/lib/display.sh"

  SPINNER_MSG="Checking versions…" start_spinner &
  spinner_pid=$!
  disown $spinner_pid 2>/dev/null || true
  trap 'stop_spinner' EXIT

  check_nvm
  check_node --fatal

  stop_spinner
  trap - EXIT
  display_results

  [[ "$match" != "true" || -z "$npm_ver" ]] && exit 1
  exit 0
}

run_install() {
  [[ "$1" != "--no-banner" ]] && show_banner
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  source "${SCRIPT_DIR}/lib/spinner.sh"
  source "${SCRIPT_DIR}/lib/nvm.sh"
  source "${SCRIPT_DIR}/lib/node.sh"

  ensure_nvm || return $?
  echo ""
  ensure_nvm_config || return $?
  echo ""
  ensure_nvm_autoload_config || return $?
  echo ""
  ensure_node || return $?
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
