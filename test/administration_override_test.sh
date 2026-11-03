#!/usr/bin/env bash
# Tests for the --administration override: requests must use the overridden
# administration's session, not the current one
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

# Isolated config dir with two sessions, "111" being current
MONEYBIRD_CONFIG_DIR="$(mktemp -d)"
export MONEYBIRD_CONFIG_DIR
trap 'rm -rf "$MONEYBIRD_CONFIG_DIR"' EXIT

OPT_DEV=""
OPT_ADMINISTRATION=""
source "$SCRIPT_DIR/lib/config.sh"

config_init
sessions_store "222" "Second B.V." '{"access_token":"token-222","token_type":"bearer","expires_at":2000000000}'
sessions_store "111" "First B.V." '{"access_token":"token-111","token_type":"bearer","expires_at":0}'

assert_eq() {
  local label="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    echo "    expected: $expected"
    echo "    got: $actual"
    FAIL=$((FAIL + 1))
  fi
}

echo "Without override"
assert_eq "active id is current" "$(sessions_active_id)" "111"
assert_eq "token is current's" "$(sessions_get_token)" "token-111"
assert_eq "expiry is current's" "$(sessions_get_expires_at)" "0"

echo "With --administration 222"
OPT_ADMINISTRATION="222"
assert_eq "active id is override" "$(sessions_active_id)" "222"
assert_eq "admin id is override" "$(config_get_admin_id)" "222"
assert_eq "token is override's" "$(sessions_get_token)" "token-222"
assert_eq "expiry is override's" "$(sessions_get_expires_at)" "2000000000"

sessions_update_token '{"access_token":"token-222-refreshed","expires_at":2100000000}'
assert_eq "refresh updates override's session" "$(sessions_get_token)" "token-222-refreshed"
OPT_ADMINISTRATION=""
assert_eq "refresh leaves current's session" "$(sessions_get_token)" "token-111"
assert_eq "current is unchanged" "$(sessions_current_id)" "111"

echo "With --administration for an unknown administration"
OPT_ADMINISTRATION="333"
assert_eq "no token" "$(sessions_get_token)" ""

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
