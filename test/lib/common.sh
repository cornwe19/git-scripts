#!/bin/bash
# Shared helpers for git script tests.
#
# Each test sources this file, calls `setup_sandbox <name>` to get a fresh
# repo + bare remote, then uses the assert_* helpers.

set -u

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../scripts" && pwd)"
export PATH="$SCRIPTS_DIR:$PATH"

PASS=0
FAIL=0
CURRENT_TEST=""

red()    { printf "\033[31m%s\033[0m" "$*"; }
green()  { printf "\033[32m%s\033[0m" "$*"; }
yellow() { printf "\033[33m%s\033[0m" "$*"; }

start_test() {
    CURRENT_TEST=$1
    printf "  %s ... " "$CURRENT_TEST"
}

pass() {
    PASS=$((PASS + 1))
    echo "$(green ok)"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "$(red FAIL): $*"
}

assert_eq() {
    if [ "$1" = "$2" ]; then return 0; fi
    fail "expected '$2', got '$1'"
    return 1
}

assert_contains() {
    if printf '%s' "$1" | grep -qF -- "$2"; then return 0; fi
    fail "expected output to contain '$2', got: $1"
    return 1
}

assert_not_contains() {
    if ! printf '%s' "$1" | grep -qF -- "$2"; then return 0; fi
    fail "expected output to NOT contain '$2', got: $1"
    return 1
}

assert_branch_exists() {
    if git -C "$1" rev-parse --verify --quiet "refs/heads/$2" >/dev/null; then return 0; fi
    fail "expected branch '$2' to exist"
    return 1
}

assert_branch_missing() {
    if ! git -C "$1" rev-parse --verify --quiet "refs/heads/$2" >/dev/null; then return 0; fi
    fail "expected branch '$2' to be gone"
    return 1
}

# setup_sandbox <name>
# Creates /tmp/<name>/ with a bare remote and a local clone with one commit on main.
# Sets the global SBX (sandbox path) and LOCAL (path to the working clone).
setup_sandbox() {
    local name=$1
    SBX="/tmp/git-script-test-$name-$$"
    rm -rf "$SBX"
    mkdir -p "$SBX"
    REMOTE="$SBX/remote.git"
    LOCAL="$SBX/local"
    git init --bare -q -b main "$REMOTE"
    git init -q -b main "$LOCAL"
    git -C "$LOCAL" config user.email test@test
    git -C "$LOCAL" config user.name test
    git -C "$LOCAL" config commit.gpgsign false
    git -C "$LOCAL" remote add origin "$REMOTE"
    echo "hello" > "$LOCAL/README.md"
    git -C "$LOCAL" add README.md
    git -C "$LOCAL" commit -q -m "initial"
    git -C "$LOCAL" push -q -u origin main
}

teardown_sandbox() {
    [ -n "${SBX:-}" ] && rm -rf "$SBX"
}

# Print pass/fail summary, return non-zero on any failures.
summary() {
    echo
    if [ "$FAIL" -eq 0 ]; then
        echo "$(green "$PASS passed"), 0 failed"
        return 0
    fi
    echo "$(green "$PASS passed"), $(red "$FAIL failed")"
    return 1
}
