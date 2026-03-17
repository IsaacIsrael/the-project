# nvm.sh — Reusable helpers (_prefix). Public: nvm_check, nvm_ensure.

# --- Reusable (private) helpers ---

# Outputs nvm version if installed (sources nvm.sh and runs nvm --version), nothing otherwise.
_nvm_version_or_empty() {
  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s "$nvm_dir/nvm.sh" ]]; then
    ( source "$nvm_dir/nvm.sh" 2>/dev/null && nvm --version ) 2>/dev/null || true
  fi
}

# Returns 0 if the given file contains nvm init (NVM_DIR + source nvm.sh).
_nvm_profile_has_init() {
  [[ -f "$1" ]] || return 1
  grep -qE 'NVM_DIR=.*(\.nvm|XDG_CONFIG_HOME)' "$1" 2>/dev/null && grep -qE '(\.|source).*nvm\.sh' "$1" 2>/dev/null
}

# Outputs space-separated list of profile paths (with ~ for HOME) that have nvm init.
_nvm_configured_profile_list() {
  local profiles=("$HOME/.bashrc" "$HOME/.profile" "$HOME/.zshrc")
  local configured_in=()
  local f
  for f in "${profiles[@]}"; do
    if _nvm_profile_has_init "$f"; then
      [[ "$f" == "$HOME"/* ]] && configured_in+=("~/${f#$HOME/}") || configured_in+=("$f")
    fi
  done
  echo "${configured_in[*]}"
}

# Returns 0 if ~/.zshrc has the nvm auto-load .nvmrc hook.
_nvm_zshrc_has_autoload() {
  [[ -f "$HOME/.zshrc" ]] || return 1
  grep -qE 'add-zsh-hook\s+chpwd\s+load-nvmrc' "$HOME/.zshrc" 2>/dev/null && grep -qE 'load-nvmrc\s*\(\)' "$HOME/.zshrc" 2>/dev/null
}

_nvm_check_installed() {
  nvm_version=$(_nvm_version_or_empty)
  nvm_footer=0
  if [[ -n "$nvm_version" ]]; then
    _check_display nvm_emoji nvm_msg ok "$nvm_version"
  else
    _check_display nvm_emoji nvm_msg warn "not installed"
    nvm_footer=1
    _check_display nvm_configured_emoji nvm_configured_msg skip "(nvm not installed)"
    _check_display nvm_zshhook_emoji nvm_zshhook_msg skip "(nvm not installed)"
    return
  fi
}

_nvm_check_configuration() {
  [[ -n "$nvm_version" ]] || return
  local list
  list=$(_nvm_configured_profile_list)
  if [[ -n "$list" ]]; then
    _check_display nvm_configured_emoji nvm_configured_msg ok "OK ($list)"
  else
    _check_display nvm_configured_emoji nvm_configured_msg fail "FAIL (add nvm block to ~/.bashrc, ~/.profile, or ~/.zshrc — you may need more than one)"
  fi
}

_nvm_check_zshhook() {
  [[ -n "$nvm_version" ]] || return
  if [[ "${SHELL:-}" != *zsh* ]]; then
    _check_display nvm_zshhook_emoji nvm_zshhook_msg skip "n/a (not zsh)"
  elif _nvm_zshrc_has_autoload; then
    _check_display nvm_zshhook_emoji nvm_zshhook_msg ok "OK (~/.zshrc)"
  else
    _check_display nvm_zshhook_emoji nvm_zshhook_msg warn "optional (add nvm auto load config to ~/.zshrc)"
  fi
}

NVM_INSTALL_URL="${NVM_INSTALL_URL:-https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh}"

_nvm_ensure_installed() {
  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s "$nvm_dir/nvm.sh" ]]; then
    export NVM_DIR="$nvm_dir"
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh"
    _ensure_display ok "nvm already installed ($(nvm --version))"
    return 0
  fi
  echo "  Installing nvm..."
  if ! command -v curl &>/dev/null; then
    _fatal_display "curl is required to install nvm. Install curl and try again."
  fi
  if ! curl -o- "$NVM_INSTALL_URL" | bash; then
    _fatal_display "nvm install failed."
  fi
  export NVM_DIR="$nvm_dir"
  # shellcheck source=/dev/null
  source "$NVM_DIR/nvm.sh"
  _ensure_display ok "nvm installed ($(nvm --version))"
}

_nvm_ensure_config() {
  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  if [[ ! -s "$nvm_dir/nvm.sh" ]]; then
    _fatal_display "nvm not installed. Make sure nvm is installed."
  fi
  local profiles=("$HOME/.bashrc" "$HOME/.profile" "$HOME/.zshrc")
  local added=()
  local f
  for f in "${profiles[@]}"; do
    if [[ -f "$f" ]] && ! _nvm_profile_has_init "$f"; then
      {
        echo ""
        echo "# nvm (added by the-project cli)"
        echo 'export NVM_DIR="$HOME/.nvm"'
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm'
        echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion'
      } >> "$f"
      [[ "$f" == "$HOME"/* ]] && added+=("~/${f#$HOME/}") || added+=("$f")
    fi
  done
  if [[ ${#added[@]} -eq 0 ]] && [[ ! -f "$HOME/.bashrc" && ! -f "$HOME/.profile" && ! -f "$HOME/.zshrc" ]]; then
    touch "$HOME/.zshrc"
    {
      echo "# nvm (added by the-project cli)"
      echo 'export NVM_DIR="$HOME/.nvm"'
      echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm'
      echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion'
    } >> "$HOME/.zshrc"
    added+=("~/.zshrc")
  fi
  if [[ ${#added[@]} -gt 0 ]]; then
    _ensure_display ok "Added nvm config to: ${added[*]}"
  else
    _ensure_display ok "nvm already configured in profile(s)"
  fi
}

_nvm_ensure_autoload_config() {
  if [[ "${SHELL:-}" != *zsh* ]]; then
    _ensure_display skip "nvm auto-load .nvmrc: n/a (not zsh)"
    return 0
  fi
  local zshrc="$HOME/.zshrc"
  if [[ ! -f "$zshrc" ]]; then
    _ensure_display skip "nvm auto-load .nvmrc: ~/.zshrc not found, skipping"
    return 0
  fi
  if _nvm_zshrc_has_autoload; then
    _ensure_display ok "nvm auto-load .nvmrc already in ~/.zshrc"
    return 0
  fi
  {
    echo ""
    echo "# nvm auto-load .nvmrc (added by the-project cli) — place after nvm initialization!"
    echo "autoload -U add-zsh-hook"
    echo ""
    echo "load-nvmrc() {"
    echo "  local nvmrc_path"
    echo '  nvmrc_path="$(nvm_find_nvmrc)"'
    echo ""
    echo '  if [ -n "$nvmrc_path" ]; then'
    echo "    local nvmrc_node_version"
    echo '    nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")'
    echo ""
    echo '    if [ "$nvmrc_node_version" = "N/A" ]; then'
    echo "      nvm install"
    echo '    elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then'
    echo "      nvm use"
    echo "    fi"
    echo '  elif [ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then'
    echo '    echo "Reverting to nvm default version"'
    echo "    nvm use default"
    echo "  fi"
    echo "}"
    echo ""
    echo "add-zsh-hook chpwd load-nvmrc"
    echo "load-nvmrc"
  } >> "$zshrc"
  _ensure_display ok "Added nvm auto-load .nvmrc to ~/.zshrc"
}

# --- Public API ---

# Run all nvm checks for doctor. Sets nvm_* display globals.
nvm_check() {
  _nvm_check_installed
  _nvm_check_configuration
  _nvm_check_zshhook
}

# Ensure nvm is installed, configured in shell profile, and (if zsh) auto-load .nvmrc hook. Used by CLI install.
nvm_ensure() {
  _nvm_ensure_installed || return $?
  echo ""
  _nvm_ensure_config || return $?
  echo ""
  _nvm_ensure_autoload_config
}
