#!/usr/bin/env bash
# CLI: doctor and install. Entry point. Run from repo root.
# Usage: cli [command]
#   doctor      environment check (Node, npm, nvm, Ruby, rbenv, …)
#   install     set up environment
#   ci          Node, Ruby, CocoaPods / Gemfile check (for CI)
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
    ci)              CMD=ci ;;
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
  echo "    1) doctor   run environment check (Node, npm, nvm, Ruby, rbenv, …)"
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
  echo "    doctor   run environment check (Node, npm, nvm, Ruby, rbenv, …)"
  echo "    install  set up environment (nvm, Node, npm, Ruby from .ruby-version)"
  echo "    ci       Node, Ruby, CocoaPods / Gemfile check (for CI)"
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
  source "${SCRIPT_DIR}/lib/cocoapods.sh"

  start_spinner "Checking versions…"

  check_brew
  nvm_check
  node_check
  rbenv_check
  check_ruby
  cocoapods_check

  stop_spinner
  set_summary_from_results
  display_results

  [[ "$summary_msg" == "failed." ]] && exit 1
  exit 0
}

# CI: Node, Ruby, CocoaPods / Gemfile; display_results(ci); exit 1 if any row is ❌.
run_ci() {
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  source "${SCRIPT_DIR}/lib/display.sh"
  source "${SCRIPT_DIR}/lib/node.sh"
  source "${SCRIPT_DIR}/lib/ruby.sh"
  source "${SCRIPT_DIR}/lib/cocoapods.sh"

  node_check
  check_ruby
  cocoapods_check
  set_summary_from_results
  display_results ci
  [[ "$summary_msg" == "failed." ]] && exit 1
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
  source "${SCRIPT_DIR}/lib/cocoapods.sh"
  source "${SCRIPT_DIR}/lib/brew.sh"

  start_spinner "Setting up environment…"

  ensure_brew || { stop_spinner; return $?; }
  nvm_ensure || { stop_spinner; return $?; }
  node_ensure || { stop_spinner; return $?; }
  rbenv_ensure || { stop_spinner; return $?; }
  ensure_ruby || { stop_spinner; return $?; }
  cocoapods_ensure || { stop_spinner; return $?; }

  stop_spinner
  echo ""
  echo "  ✅  Setup done."
  echo ""
}

case "$CMD" in
  menu)   show_menu ;;
  help)   show_help ;;
  doctor) run_doctor ;;
  install) run_install ;;
  ci)     run_ci ;;
  *)      show_help; exit 1 ;;
esac
