# rbenv.sh — Public API: rbenv_check, rbenv_ensure. All other functions are private (_prefix).

# --- Private helpers ---

_rbenv_cmd_path() {
  local rbenv_cmd
  rbenv_cmd=$(command -v rbenv 2>/dev/null) || true
  if [[ -z "$rbenv_cmd" ]]; then
    if [[ -x "$HOME/.rbenv/bin/rbenv" ]]; then
      rbenv_cmd="$HOME/.rbenv/bin/rbenv"
    elif [[ -x /opt/homebrew/bin/rbenv ]]; then
      rbenv_cmd="/opt/homebrew/bin/rbenv"
    elif [[ -x /usr/local/bin/rbenv ]]; then
      rbenv_cmd="/usr/local/bin/rbenv"
    fi
  fi
  echo "${rbenv_cmd:-}"
}

_rbenv_version_or_empty() {
  local rbenv_cmd
  rbenv_cmd=$(_rbenv_cmd_path)
  if [[ -n "$rbenv_cmd" ]]; then
    "$rbenv_cmd" --version 2>/dev/null | sed -n '1s/.*rbenv[[:space:]]*//p'
  fi
}

_rbenv_profile_has_init() {
  [[ -f "$1" ]] && grep -qE 'rbenv init' "$1" 2>/dev/null
}

_rbenv_configured_profile_list() {
  local profiles=("$HOME/.bashrc" "$HOME/.profile" "$HOME/.zshrc")
  local configured_in=()
  local f
  for f in "${profiles[@]}"; do
    if _rbenv_profile_has_init "$f"; then
      [[ "$f" == "$HOME"/* ]] && configured_in+=("~/${f#$HOME/}") || configured_in+=("$f")
    fi
  done
  echo "${configured_in[*]}"
}

_rbenv_check_installed() {
  rbenv_version=$(_rbenv_version_or_empty)
  rbenv_footer=0
  if [[ -n "$rbenv_version" ]]; then
    _check_display rbenv_emoji rbenv_msg ok "$rbenv_version"
  else
    _check_display rbenv_emoji rbenv_msg warn "not installed"
    rbenv_footer=1
  fi
}

_rbenv_check_configuration() {
  if [[ -z "$(_rbenv_version_or_empty)" ]]; then
    _check_display rbenv_configured_emoji rbenv_configured_msg skip "(rbenv not installed)"
    return
  fi
  local list
  list=$(_rbenv_configured_profile_list)
  if [[ -n "$list" ]]; then
    _check_display rbenv_configured_emoji rbenv_configured_msg ok "OK ($list)"
  else
    _check_display rbenv_configured_emoji rbenv_configured_msg warn "optional (add 'eval \"\$(rbenv init -)\"' to shell profile)"
  fi
}

_rbenv_ensure_installed() {
  local ver
  ver=$(_rbenv_version_or_empty)
  if [[ -n "$ver" ]]; then
    _ensure_display ok "rbenv already installed ($ver)"
    return 0
  fi
  if ! command -v brew &>/dev/null; then
    _fatal_display "rbenv not found and Homebrew is not installed. Install Homebrew (https://brew.sh) or rbenv manually."
  fi
  echo "  Installing rbenv and ruby-build via Homebrew..."
  if brew install rbenv ruby-build; then
    export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-}"
    _ensure_display ok "rbenv installed ($(_rbenv_version_or_empty))"
    return 0
  fi
  _ensure_display fail "rbenv install failed."
  return 1
}

_rbenv_ensure_config() {
  if [[ -z "$(_rbenv_cmd_path)" ]]; then
    _ensure_display skip "rbenv not installed, skipping profile config"
    return 0
  fi
  local profiles=("$HOME/.bashrc" "$HOME/.profile" "$HOME/.zshrc")
  local added=()
  local f
  for f in "${profiles[@]}"; do
    if [[ -f "$f" ]] && ! _rbenv_profile_has_init "$f"; then
      {
        echo ""
        echo "# rbenv (added by the-project cli)"
        echo 'eval "$(rbenv init -)"'
      } >> "$f"
      [[ "$f" == "$HOME"/* ]] && added+=("~/${f#$HOME/}") || added+=("$f")
    fi
  done
  if [[ ${#added[@]} -eq 0 ]] && [[ ! -f "$HOME/.bashrc" && ! -f "$HOME/.profile" && ! -f "$HOME/.zshrc" ]]; then
    touch "$HOME/.zshrc"
    {
      echo ""
      echo "# rbenv (added by the-project cli)"
      echo 'eval "$(rbenv init -)"'
    } >> "$HOME/.zshrc"
    added+=("~/.zshrc")
  fi
  if [[ ${#added[@]} -gt 0 ]]; then
    _ensure_display ok "Added rbenv config to: ${added[*]}"
  else
    _ensure_display ok "rbenv already configured in profile(s)"
  fi
}

# --- Public API ---

# Run all rbenv checks for doctor. Sets rbenv_* display globals.
rbenv_check() {
  _rbenv_check_installed
  _rbenv_check_configuration
}

# Ensure rbenv is installed and configured in shell profile. Used by CLI install.
rbenv_ensure() {
  _rbenv_ensure_installed || return $?
  echo ""
  _rbenv_ensure_config
}
