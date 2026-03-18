# cocoapods.sh — Reusable helpers (_prefix). Public: cocoapods_check, cocoapods_ensure.
# Expected version from ios/Podfile.lock (COCOAPODS: x.y.z). Check/ensure use it when present.

# --- Reusable (private) helpers ---

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

# Sets cocoapods_* display globals for doctor. Requires expected version in ios/Podfile.lock (fatal otherwise).
_cocoapods_check() {
  local expected current
  expected=$(_cocoapods_expected_version)
  [[ -z "$expected" ]] && _fatal_display "No CocoaPods version in ios/Podfile.lock. Run pod install in ios/ or add Podfile.lock."

  current=$(_cocoapods_version_or_empty)
  cocoapods_footer=0
  if [[ -z "$current" || "$current" != "$expected" ]]; then
    _check_display cocoapods_emoji cocoapods_msg fail "expected" "$expected"
    cocoapods_footer=1
  else
    _check_display cocoapods_emoji cocoapods_msg ok "$current"
  fi
}

# Ensure CocoaPods is installed at version from ios/Podfile.lock. Requires Ruby and expected version (fatal otherwise).
_cocoapods_ensure() {
  local expected current
  expected=$(_cocoapods_expected_version)
  [[ -z "$expected" ]] && _fatal_display "No CocoaPods version in ios/Podfile.lock. Run pod install in ios/ or add Podfile.lock."

  if ! command -v gem &>/dev/null || ! command -v ruby &>/dev/null; then
    _fatal_display "CocoaPods requires Ruby. Make sure Ruby is installed and in your PATH."
  fi

  current=$(_cocoapods_version_or_empty)
  if [[ -n "$current" && "$current" == "$expected" ]]; then
    _ensure_display ok "CocoaPods already installed ($current, from Podfile.lock)"
    return 0
  fi

  if ! gem install cocoapods -v "$expected"; then
    _fatal_display "CocoaPods $expected install failed."
  fi
  _ensure_display ok "CocoaPods installed ($expected)"
}

# --- Public API ---

cocoapods_check() {
  _cocoapods_check
}

cocoapods_ensure() {
  _cocoapods_ensure
}
