# Node checks: sets expected, current, match, node_available, npm_ver, node_emoji, node_msg, node_footer,
# npm_emoji, npm_msg, summary_emoji, summary_msg. Returns 1 if engines.node unreadable.
# With --fatal: on failure stops spinner (if loaded), prints message, exits 1. Call from repo root.
get_expected_node() {
  if command -v node &>/dev/null && [[ -f package.json ]]; then
    node -e "const e=require('./package.json').engines; console.log(e&&e.node?e.node.trim():'')" 2>/dev/null || true
  elif command -v jq &>/dev/null && [[ -f package.json ]]; then
    jq -r '.engines.node // empty' package.json 2>/dev/null || true
  fi
}

check_node() {
  local fatal=
  [[ "$1" == "--fatal" ]] && fatal=1

  expected=$(get_expected_node)
  if [[ -z "$expected" ]]; then
    if [[ -n "$fatal" ]]; then
      type stop_spinner &>/dev/null && stop_spinner
      echo ""
      echo "  ❌  Node · read engines.node   FAIL"
      echo ""
      exit 1
    fi
    return 1
  fi
  current=$(node -v 2>/dev/null | sed 's/^v//')
  node_available=1
  [[ -n "$current" ]] && node_available=0

  match=false
  if [[ -n "$current" ]]; then
    if [[ "$expected" == "$current" ]]; then
      match=true
    else
      node -e "
        const e=require('./package.json').engines.node;
        const c=process.version.replace(/^v/,'');
        if (e===c){ process.exit(0); }
        try { const semver=require('semver'); process.exit(semver.satisfies(c,e)?0:1); } catch(_){ process.exit(1); }
      " 2>/dev/null && match=true
    fi
  fi

  npm_ver=$(npm -v 2>/dev/null || echo "")

  node_footer=0
  if [[ $node_available -ne 0 ]]; then
    node_emoji="⚠️"
    node_msg="FAIL (not installed)"
    node_footer=1
  elif [[ "$match" == "true" ]]; then
    node_emoji="✅"
    node_msg="$(node -v)"
  else
    node_emoji="❌"
    node_msg="FAIL (expected $expected)"
  fi
  if [[ -n "$npm_ver" ]]; then
    npm_emoji="✅"
    npm_msg="$npm_ver"
  else
    npm_emoji="❌"
    npm_msg="FAIL"
  fi
  if [[ "$match" == "true" && -n "$npm_ver" ]]; then
    summary_emoji="✅"
    summary_msg="passed."
  else
    summary_emoji="❌"
    summary_msg="failed."
  fi
  return 0
}

# Ensure Node version from .nvmrc is installed and in use. Requires nvm to be loaded. Used by CLI install.
ensure_node() {
  if ! command -v nvm &>/dev/null; then
    echo "  ❌  nvm not loaded. Run ensure_nvm first."
    return 1
  fi
  if [[ ! -f .nvmrc ]]; then
    echo "  ⚠️  No .nvmrc found. Using default Node."
    nvm use default 2>/dev/null || nvm alias default node 2>/dev/null || true
    return 0
  fi
  local want
  want=$(cat .nvmrc | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  if [[ -z "$want" ]]; then
    return 0
  fi

  if nvm use "$want" &>/dev/null; then
    echo "  ✅  Node from .nvmrc already installed and in use"
  else
    echo "  Installing Node from .nvmrc: $want"
    nvm install "$want"
    nvm use "$want"
  fi
}
