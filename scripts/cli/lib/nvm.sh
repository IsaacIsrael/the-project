# nvm check: sets nvm_version, nvm_emoji, nvm_msg, nvm_footer, nvm_configured_emoji, nvm_configured_msg,
# nvm_zshhook_emoji, nvm_zshhook_msg. "Configured" = profile has NVM_DIR + source nvm.sh.
# Auto load config = load-nvmrc + add-zsh-hook chpwd load-nvmrc in ~/.zshrc (auto nvm use from .nvmrc).
check_nvm() {
  nvm_version=""
  if [[ -n "${NVM_DIR:-}" ]] && [[ -s "${NVM_DIR}/nvm.sh" ]]; then
    nvm_version=$( (source "${NVM_DIR}/nvm.sh" 2>/dev/null && nvm --version) 2>/dev/null || echo "")
  fi
  nvm_footer=0
  if [[ -n "$nvm_version" ]]; then
    nvm_emoji="✅"
    nvm_msg="$nvm_version"
  else
    nvm_emoji="❌"
    nvm_msg="FAIL"
    nvm_footer=1
    nvm_configured_emoji="—"
    nvm_configured_msg="(nvm not installed)"
    nvm_zshhook_emoji="—"
    nvm_zshhook_msg="(nvm not installed)"
    return
  fi

  # Check ~/.bashrc, ~/.profile, ~/.zshrc (nvm docs: "you may have to add to more than one")
  local profiles=("$HOME/.bashrc" "$HOME/.profile" "$HOME/.zshrc")
  local configured_in=()
  local f
  for f in "${profiles[@]}"; do
    if [[ -f "$f" ]]; then
      if grep -qE 'NVM_DIR=.*(\.nvm|XDG_CONFIG_HOME)' "$f" 2>/dev/null && grep -qE '(\.|source).*nvm\.sh' "$f" 2>/dev/null; then
        local display_path="$f"
        [[ "$f" == "$HOME"/* ]] && display_path="~/${f#$HOME/}"
        configured_in+=("$display_path")
      fi
    fi
  done

  if [[ ${#configured_in[@]} -gt 0 ]]; then
    nvm_configured_emoji="✅"
    nvm_configured_msg="OK (${configured_in[*]})"
  else
    nvm_configured_emoji="❌"
    nvm_configured_msg="FAIL (add nvm block to ~/.bashrc, ~/.profile, or ~/.zshrc — you may need more than one)"
  fi

  # Zsh .nvmrc auto-use hook (nvm README: "Calling nvm use automatically in a directory with a .nvmrc file")
  if [[ "${SHELL:-}" != *zsh* ]]; then
    nvm_zshhook_emoji="—"
    nvm_zshhook_msg="n/a (not zsh)"
  elif [[ -f "$HOME/.zshrc" ]] && grep -qE 'add-zsh-hook\s+chpwd\s+load-nvmrc' "$HOME/.zshrc" 2>/dev/null && grep -qE 'load-nvmrc\s*\(\)' "$HOME/.zshrc" 2>/dev/null; then
    nvm_zshhook_emoji="✅"
    nvm_zshhook_msg="OK (~/.zshrc)"
  else
    nvm_zshhook_emoji="⚠️"
    nvm_zshhook_msg="optional (add nvm auto load config to ~/.zshrc)"
  fi
}

# Ensure nvm is installed and loaded in this shell. If not installed, runs the official install script.
# Sets NVM_DIR and sources nvm.sh. Used by CLI install.
NVM_INSTALL_URL="${NVM_INSTALL_URL:-https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh}"

ensure_nvm() {
  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s "$nvm_dir/nvm.sh" ]]; then
    export NVM_DIR="$nvm_dir"
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh"
    echo "  ✅  nvm already installed ($(nvm --version))"
    return 0
  fi

  echo "  Installing nvm..."
  if ! command -v curl &>/dev/null; then
    echo "  ❌  curl is required to install nvm. Install curl and try again."
    return 1
  fi
  if ! curl -o- "$NVM_INSTALL_URL" | bash; then
    echo "  ❌  nvm install failed."
    return 1
  fi
  export NVM_DIR="$nvm_dir"
  # shellcheck source=/dev/null
  source "$NVM_DIR/nvm.sh"
  echo "  ✅  nvm installed ($(nvm --version))"
}

# Ensure nvm is in shell profile so it loads on login. Appends the standard block to
# ~/.bashrc, ~/.profile, ~/.zshrc if missing. Call after ensure_nvm. Used by CLI install.
ensure_nvm_config() {
  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  if [[ ! -s "$nvm_dir/nvm.sh" ]]; then
    echo "  ❌  nvm not installed. Run ensure_nvm first."
    return 1
  fi

  local profiles=("$HOME/.bashrc" "$HOME/.profile" "$HOME/.zshrc")
  local added=()
  local f
  for f in "${profiles[@]}"; do
    if [[ -f "$f" ]]; then
      if ! grep -qE 'NVM_DIR=.*(\.nvm|XDG_CONFIG_HOME)' "$f" 2>/dev/null || ! grep -qE '(\.|source).*nvm\.sh' "$f" 2>/dev/null; then
        {
          echo ""
          echo "# nvm (added by the-project cli)"
          echo 'export NVM_DIR="$HOME/.nvm"'
          echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm'
          echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion'
        } >> "$f"
        [[ "$f" == "$HOME"/* ]] && added+=("~/${f#$HOME/}") || added+=("$f")
      fi
    fi
  done

  # If no profile existed, create .zshrc (common on macOS) and add the block
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
    echo "  ✅  Added nvm config to: ${added[*]}"
  else
    echo "  ✅  nvm already configured in profile(s)"
  fi
}

# Ensure zsh auto-load .nvmrc hook is in ~/.zshrc (nvm use on cd). Only for zsh. Call after ensure_nvm_config.
ensure_nvm_autoload_config() {
  if [[ "${SHELL:-}" != *zsh* ]]; then
    echo "  ⏭️  nvm auto-load .nvmrc: n/a (not zsh)"
    return 0
  fi

  local zshrc="$HOME/.zshrc"
  if [[ ! -f "$zshrc" ]]; then
    echo "  ⏭️  nvm auto-load .nvmrc: ~/.zshrc not found, skipping"
    return 0
  fi

  if grep -qE 'add-zsh-hook\s+chpwd\s+load-nvmrc' "$zshrc" 2>/dev/null && grep -qE 'load-nvmrc\s*\(\)' "$zshrc" 2>/dev/null; then
    echo "  ✅  nvm auto-load .nvmrc already in ~/.zshrc"
    return 0
  fi

  # Append block (place after nvm initialization)
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
  echo "  ✅  Added nvm auto-load .nvmrc to ~/.zshrc"
}
