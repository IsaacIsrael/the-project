# brew.sh — Reusable helpers (_prefix). Public: check_brew, ensure_brew.

# --- Reusable (private) helpers ---

# Outputs Homebrew version if installed, nothing otherwise.
_brew_version_or_empty() {
  if command -v brew &>/dev/null; then
    brew --version 2>/dev/null | sed -n '1s/.*Homebrew[[:space:]]*//p'
  fi
}

# Sets brew_* display globals for doctor. Uses _brew_version_or_empty and _check_display.
_brew_check() {
  brew_version=$(_brew_version_or_empty)
  brew_footer=0
  if [[ -n "$brew_version" ]]; then
    _check_display brew_emoji brew_msg ok "$brew_version"
  else
    _check_display brew_emoji brew_msg warn "not installed"
    brew_footer=1
  fi
}

# Ensure Homebrew is installed. Uses _brew_version_or_empty. After install, adds brew to PATH for this run.
HOMEBREW_INSTALL_URL="${HOMEBREW_INSTALL_URL:-https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh}"

_brew_ensure() {
  local ver
  ver=$(_brew_version_or_empty)
  if [[ -n "$ver" ]]; then
    _ensure_display ok "Homebrew already installed ($ver)"
    return 0
  fi

  echo "  Installing Homebrew..."
  if ! command -v curl &>/dev/null; then
    _fatal_display "curl is required to install Homebrew. Install Xcode Command Line Tools or curl and try again."
  fi
  if ! NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "$HOMEBREW_INSTALL_URL")"; then
    _fatal_display "Homebrew install failed."
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  _ensure_display ok "Homebrew installed ($(_brew_version_or_empty))"
}

# --- Public API ---

check_brew() {
  _brew_check
}

ensure_brew() {
  _brew_ensure
}
