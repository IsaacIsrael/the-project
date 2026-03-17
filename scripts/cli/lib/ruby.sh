# ruby.sh — Reusable helpers (_prefix). Public: check_ruby, ensure_ruby.

# --- Reusable (private) helpers ---

# Outputs expected version from .ruby-version (first line trimmed), or nothing if missing/empty.
_ruby_expected_version() {
  [[ ! -f .ruby-version ]] && return 0
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' .ruby-version | head -n1
}

# Outputs current Ruby version from `ruby -v`, or nothing if not installed.
_ruby_current_version() {
  ruby -v 2>/dev/null | sed -n '1s/.*ruby \([0-9][0-9.]*\).*/\1/p'
}

# Returns 0 if expected and current match (exact or major.minor). Usage: _ruby_versions_match "$expected" "$current"
_ruby_versions_match() {
  local expected="$1" current="$2"
  [[ -z "$expected" || -z "$current" ]] && return 1
  [[ "$expected" == "$current" ]] && return 0
  [[ "${expected%.*}" == "${current%.*}" ]] && return 0
  return 1
}

# Returns 0 if rbenv has the given version installed. Usage: _ruby_rbenv_has_version "3.1.6"
_ruby_rbenv_has_version() {
  local rbenv_cmd want="$1"
  rbenv_cmd=$(_rbenv_cmd_path 2>/dev/null) || true
  [[ -z "$rbenv_cmd" || -z "$want" ]] && return 1
  "$rbenv_cmd" versions --bare 2>/dev/null | sed 's/^[* ]*//;s/ *$//' | grep -q "^${want}$"
}

# Sets ruby_* display globals for doctor. Uses _ruby_expected_version, _ruby_current_version, _ruby_versions_match.
_ruby_check() {
  ruby_footer=0
  if [[ ! -f .ruby-version ]]; then
    _fatal_display "No .ruby-version found."
  fi

  expected_ruby=$(_ruby_expected_version)
  if [[ -z "$expected_ruby" ]]; then
    _fatal_display "Empty .ruby-version."
  fi

  current_ruby=$(_ruby_current_version)
  if _ruby_versions_match "$expected_ruby" "$current_ruby"; then
    ruby_match=true
  else
    ruby_match=false
  fi

  if [[ -z "$current_ruby" ]]; then
    _check_display ruby_emoji ruby_msg warn "not installed"
    ruby_footer=1
  elif [[ "$ruby_match" == "true" ]]; then
    _check_display ruby_emoji ruby_msg ok "$(ruby -v | sed 's/^ruby //;s/ .*//')"
  else
    _check_display ruby_emoji ruby_msg fail "expected" "$expected_ruby"
    ruby_footer=1
  fi
  return 0
}

# Ensure Ruby version from .ruby-version is installed via rbenv. Uses _ruby_expected_version, _ruby_rbenv_has_version.
_ruby_ensure() {
  local rbenv_cmd want
  rbenv_cmd=$(_rbenv_cmd_path 2>/dev/null) || true
  if [[ -z "$rbenv_cmd" ]]; then
    _fatal_display "Ruby: rbenv not found. Make sure rbenv is installed and in your PATH."
  fi
  want=$(_ruby_expected_version)
  if [[ -z "$want" ]]; then
    _fatal_display "Ruby: no .ruby-version or empty .ruby-version."
  fi
  if _ruby_rbenv_has_version "$want"; then
    _ensure_display ok "Ruby from .ruby-version already installed and in use"
  else
    echo "  Installing Ruby from .ruby-version: $want"
    "$rbenv_cmd" install -s || { _ensure_display fail "rbenv install failed."; return 1; }
  fi
}

# --- Public API ---

check_ruby() {
  _ruby_check
}

ensure_ruby() {
  _ruby_ensure
}
