# cocoapods.sh — Reusable helpers (_prefix). Public: cocoapods_check, cocoapods_ensure.
# Gemfile pin = Podfile.lock. Ensure: bundle install (bundle exec pod) + gem install (global pod) same version.

# --- Reusable (private) helpers ---

# Outputs cocoapods version from Gemfile (gem "cocoapods", "x.y.z"), or nothing.
# sed (not bash =~ \1) for macOS Bash 3.2 compatibility.
_cocoapods_gemfile_version() {
  local v
  [[ -f Gemfile ]] || return 0
  v=$(sed -n '/^[[:space:]]*gem[[:space:]]*"cocoapods"/s/.*,[[:space:]]*"\([^"]*\)".*/\1/p' Gemfile | head -1)
  [[ -n "$v" ]] && printf '%s\n' "$v" && return 0
  v=$(sed -n "/^[[:space:]]*gem[[:space:]]*'cocoapods'/s/.*,[[:space:]]*'\\([^']*\\)'.*/\\1/p" Gemfile | head -1)
  [[ -n "$v" ]] && printf '%s\n' "$v"
}

# Outputs expected CocoaPods version from ios/Podfile.lock (line "COCOAPODS: x.y.z"), or nothing.
_cocoapods_expected_version() {
  if [[ -f ios/Podfile.lock ]]; then
    grep -E '^COCOAPODS: [0-9]+\.[0-9]+\.[0-9]+' ios/Podfile.lock 2>/dev/null | sed -e 's/^COCOAPODS:[[:space:]]*//' -e 's/[[:space:]]*$//'
  fi
}

# Outputs CocoaPods version (pod --version) if installed, nothing otherwise.
_cocoapods_version_or_empty() {
  if command -v pod &>/dev/null; then
    pod --version 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
  fi
}

# Outputs bundle exec pod --version from repo root, nothing if bundle/pod missing.
_cocoapods_bundle_pod_version_or_empty() {
  command -v bundle &>/dev/null && [[ -f Gemfile ]] || return 0
  bundle exec pod --version 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# Doctor/ci: use bundle exec pod when bundle check passes (CI: Gemfile gems, no global pod); else pod on PATH.
_cocoapods_resolved_version_or_empty() {
  local b
  if command -v bundle &>/dev/null && [[ -f Gemfile ]] && bundle check &>/dev/null; then
    b=$(_cocoapods_bundle_pod_version_or_empty)
    [[ -n "$b" ]] && printf '%s\n' "$b" && return 0
  fi
  _cocoapods_version_or_empty
}

# Sets cocoapods_* / cocoapods_gemfile_* display globals. Requires Gemfile + Podfile.lock + pin in sync.
_cocoapods_check() {
  local expected current gf

  [[ ! -f Gemfile ]] && _fatal_display "Gemfile not found. Add Gemfile with gem \"cocoapods\" pinned to match ios/Podfile.lock (COCOAPODS: line)."

  expected=$(_cocoapods_expected_version)
  [[ -z "$expected" ]] && _fatal_display "No CocoaPods version in ios/Podfile.lock. Run pod install in ios/ or add Podfile.lock."

  current=$(_cocoapods_resolved_version_or_empty)
  cocoapods_footer=0
  if [[ -z "$current" || "$current" != "$expected" ]]; then
    _check_display cocoapods_emoji cocoapods_msg fail "expected" "$expected"
    cocoapods_footer=1
  else
    _check_display cocoapods_emoji cocoapods_msg ok "$current"
  fi

  gf=$(_cocoapods_gemfile_version)
  if [[ -z "$gf" ]]; then
    _check_display cocoapods_gemfile_emoji cocoapods_gemfile_msg fail "Gemfile missing gem \"cocoapods\", \"x.y.z\" pin"
    cocoapods_footer=1
  elif [[ "$gf" != "$expected" ]]; then
    _check_display cocoapods_gemfile_emoji cocoapods_gemfile_msg fail "Gemfile has ${gf}; Podfile.lock expects ${expected}"
    cocoapods_footer=1
  else
    _check_display cocoapods_gemfile_emoji cocoapods_gemfile_msg ok "$gf"
  fi
}

# Ensure Bundler gems (bundle exec pod) + global pod match ios/Podfile.lock.
_cocoapods_ensure() {
  local expected current bundled

  [[ ! -f Gemfile ]] && _fatal_display "Gemfile not found. Add Gemfile with gem \"cocoapods\" pinned to match ios/Podfile.lock (COCOAPODS: line)."

  expected=$(_cocoapods_expected_version)
  [[ -z "$expected" ]] && _fatal_display "No CocoaPods version in ios/Podfile.lock. Run pod install in ios/ or add Podfile.lock."

  if ! command -v gem &>/dev/null || ! command -v ruby &>/dev/null; then
    _fatal_display "CocoaPods requires Ruby. Make sure Ruby is installed and in your PATH."
  fi

  if command -v bundle &>/dev/null && bundle check &>/dev/null; then
    bundled=$(_cocoapods_bundle_pod_version_or_empty)
    current=$(_cocoapods_version_or_empty)
    if [[ "$bundled" == "$expected" && "$current" == "$expected" ]]; then
      _ensure_display ok "CocoaPods $expected (bundle exec + pod on PATH OK)"
      return 0
    fi
  fi

  if ! command -v bundle &>/dev/null; then
    if ! gem install bundler; then
      _fatal_display "Bundler install failed. Make sure Ruby gems are installable (e.g. rbenv, PATH)."
    fi
    _ensure_display ok "Bundler installed"
  fi

  if ! bundle check &>/dev/null; then
    if ! bundle install; then
      _fatal_display "bundle install failed."
    fi
    _ensure_display ok "bundle install OK (Gemfile.lock)"
  fi

  bundled=$(_cocoapods_bundle_pod_version_or_empty)
  if [[ -z "$bundled" || "$bundled" != "$expected" ]]; then
    _fatal_display "bundle exec pod is ${bundled:-not runnable}, expected $expected. Align Gemfile/Gemfile.lock with Podfile.lock, then bundle update cocoapods."
  fi
  _ensure_display ok "bundle exec pod $expected"

  current=$(_cocoapods_version_or_empty)
  if [[ -z "$current" || "$current" != "$expected" ]]; then
    if ! gem install cocoapods -v "$expected"; then
      _fatal_display "CocoaPods $expected global install failed."
    fi
    _ensure_display ok "pod on PATH $expected (gem install)"
  else
    _ensure_display ok "pod on PATH already $expected"
  fi
}

# --- Public API ---

cocoapods_check() {
  _cocoapods_check
}

cocoapods_ensure() {
  _cocoapods_ensure
}
