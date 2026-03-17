# node.sh — Reusable helpers (_prefix). Public: node_check, node_ensure.

# --- Reusable (private) helpers ---

# Outputs expected Node version from package.json engines.node, or nothing.
_node_expected_version() {
  if command -v node &>/dev/null && [[ -f package.json ]]; then
    node -e "const e=require('./package.json').engines; console.log(e&&e.node?e.node.trim():'')" 2>/dev/null || true
  elif command -v jq &>/dev/null && [[ -f package.json ]]; then
    jq -r '.engines.node // empty' package.json 2>/dev/null || true
  fi
}

# Outputs current Node version from node -v (without leading v), or nothing.
_node_current_version() {
  node -v 2>/dev/null | sed 's/^v//'
}

# Returns 0 if current Node satisfies package.json engines.node (exact or semver). Requires node and package.json.
_node_versions_match() {
  [[ -f package.json ]] || return 1
  node -e "
    const e=require('./package.json').engines.node;
    const c=process.version.replace(/^v/,'');
    if (!e||!c){ process.exit(1); }
    if (e===c){ process.exit(0); }
    try { const semver=require('semver'); process.exit(semver.satisfies(c,e)?0:1); } catch(_){ process.exit(1); }
  " 2>/dev/null
}

# Outputs npm version or nothing.
_node_npm_version() {
  npm -v 2>/dev/null || true
}

# Outputs version from .nvmrc (first line trimmed), or nothing.
_node_nvmrc_version() {
  [[ ! -f .nvmrc ]] && return 0
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' .nvmrc | head -n1
}

# Sets node_* and npm_* display globals. Exits 1 if engines.node unreadable. Uses _node_* helpers.
_node_check() {
  expected=$(_node_expected_version)
  if [[ -z "$expected" ]]; then
    _fatal_display "Node · read engines.node   FAIL"
  fi

  current=$(_node_current_version)
  node_available=1
  [[ -n "$current" ]] && node_available=0

  match=false
  if [[ -n "$current" ]]; then
    [[ "$expected" == "$current" ]] && match=true
    [[ "$match" != "true" ]] && _node_versions_match && match=true
  fi

  npm_ver=$(_node_npm_version)

  node_footer=0
  if [[ $node_available -ne 0 ]]; then
    _check_display node_emoji node_msg warn "not installed"
    node_footer=1
  elif [[ "$match" == "true" ]]; then
    _check_display node_emoji node_msg ok "$(node -v)"
  else
    _check_display node_emoji node_msg fail "expected" "$expected"
    node_footer=1
  fi

  if [[ -n "$npm_ver" ]]; then
    _check_display npm_emoji npm_msg ok "$npm_ver"
  else
    _check_display npm_emoji npm_msg warn "not installed"
  fi
  return 0
}

# Ensure Node version from .nvmrc is installed and in use. Requires nvm to be loaded. Uses _node_nvmrc_version.
_node_ensure() {
  if ! command -v nvm &>/dev/null; then
    _fatal_display "nvm not loaded. Make sure nvm is installed and loaded in your shell."
  fi
  if [[ ! -f .nvmrc ]]; then
    _fatal_display "No .nvmrc found. Failed."
  fi
  local want
  want=$(_node_nvmrc_version)
  if [[ -z "$want" ]]; then
    return 0
  fi
  if nvm use "$want" &>/dev/null; then
    _ensure_display ok "Node from .nvmrc already installed and in use"
  else
    echo "  Installing Node from .nvmrc: $want"
    nvm install "$want"
    nvm use "$want"
  fi
}

# --- Public API ---

# Run Node/npm check for doctor. Sets node_*, npm_* globals. Exits 1 if engines.node unreadable.
node_check() {
  _node_check "$@"
}

# Ensure Node version from .nvmrc is installed and in use. Used by CLI install.
node_ensure() {
  _node_ensure
}
