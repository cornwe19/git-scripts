#!/bin/bash
# Tests for git-heartbeat.

source "$(dirname "$0")/lib/common.sh"

echo "git-heartbeat"

# After setup_sandbox, advance origin/main by one commit so heartbeat has work to do
advance_main() {
    local L=$1
    local advancer
    advancer=$(mktemp -d)
    git clone -q "$REMOTE" "$advancer"
    git -C "$advancer" config user.email t@t
    git -C "$advancer" config user.name t
    echo "advance" > "$advancer/advance.txt"
    git -C "$advancer" add advance.txt
    git -C "$advancer" commit -q -m "advance main"
    git -C "$advancer" push -q origin main
    rm -rf "$advancer"
    git -C "$L" fetch -q
    # Make sure local main matches origin/main for the test
    git -C "$L" branch -f main origin/main >/dev/null 2>&1
}

start_test "missing master + cannot detect → exit 2"
setup_sandbox hb-no-master
# Remove all candidate branches: rename main to weird-name so no main/master/develop exists
git -C "$LOCAL" branch -m main weird-name
git -C "$LOCAL" remote remove origin
output=$(cd "$LOCAL" && git heartbeat 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 2 && assert_contains "$output" "could not determine master" && pass
teardown_sandbox

start_test "already on master → exit 2"
setup_sandbox hb-on-master
output=$(cd "$LOCAL" && git heartbeat main 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 2 && assert_contains "$output" "already on main" && pass
teardown_sandbox

start_test "happy path: merge master into feature"
setup_sandbox hb-happy
git -C "$LOCAL" checkout -q -b feature
echo "f" > "$LOCAL/f.txt"; git -C "$LOCAL" add f.txt; git -C "$LOCAL" commit -q -m "feature work"
git -C "$LOCAL" push -q -u origin feature
advance_main "$LOCAL"
output=$(cd "$LOCAL" && git heartbeat main 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 0 || { echo "$output"; teardown_sandbox; summary; exit 1; }
# feature should now contain advance.txt
[ -f "$LOCAL/advance.txt" ] || fail "advance.txt should be merged into feature"
assert_contains "$output" "main -> feature" && \
    [ -f "$LOCAL/advance.txt" ] && pass
teardown_sandbox

start_test "auto-detect master from origin/HEAD"
setup_sandbox hb-autodetect
git -C "$LOCAL" remote set-head origin main
git -C "$LOCAL" checkout -q -b feature
echo "f" > "$LOCAL/f.txt"; git -C "$LOCAL" add f.txt; git -C "$LOCAL" commit -q -m "feature work"
git -C "$LOCAL" push -q -u origin feature
advance_main "$LOCAL"
output=$(cd "$LOCAL" && git heartbeat 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 0 || { echo "$output"; teardown_sandbox; summary; exit 1; }
assert_contains "$output" "main -> feature" && pass
teardown_sandbox

start_test "rebase mode (-r)"
setup_sandbox hb-rebase
git -C "$LOCAL" checkout -q -b feature
echo "f" > "$LOCAL/f.txt"; git -C "$LOCAL" add f.txt; git -C "$LOCAL" commit -q -m "feature work"
git -C "$LOCAL" push -q -u origin feature
advance_main "$LOCAL"
output=$(cd "$LOCAL" && git heartbeat -r main 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 0 || { echo "$output"; teardown_sandbox; summary; exit 1; }
assert_contains "$output" "rebase" && \
    assert_contains "$output" "main -> feature" && pass
teardown_sandbox

start_test "stash mode (-s) restores untracked file"
setup_sandbox hb-stash
git -C "$LOCAL" checkout -q -b feature
echo "f" > "$LOCAL/f.txt"; git -C "$LOCAL" add f.txt; git -C "$LOCAL" commit -q -m "feature work"
git -C "$LOCAL" push -q -u origin feature
advance_main "$LOCAL"
echo "scratch" > "$LOCAL/scratch.txt"
output=$(cd "$LOCAL" && git heartbeat -s main 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 0 || { echo "$output"; teardown_sandbox; summary; exit 1; }
[ -f "$LOCAL/scratch.txt" ] || fail "scratch.txt should be restored after stash pop"
assert_contains "$output" "Stashing" && pass
teardown_sandbox

start_test "stash mode + conflict → work recoverable from stash (never stranded)"
setup_sandbox hb-conflict
echo "shared content" > "$LOCAL/conflict.txt"
git -C "$LOCAL" add conflict.txt; git -C "$LOCAL" commit -q -m "add conflict file"
git -C "$LOCAL" push -q origin main
git -C "$LOCAL" checkout -q -b feature
echo "feature edit" > "$LOCAL/conflict.txt"
git -C "$LOCAL" commit -aq -m "feature changes conflict.txt"
git -C "$LOCAL" push -q -u origin feature
# Advance main with a conflicting change
advancer=$(mktemp -d)
git clone -q "$REMOTE" "$advancer"
git -C "$advancer" config user.email t@t; git -C "$advancer" config user.name t
git -C "$advancer" checkout -q main
echo "main edit" > "$advancer/conflict.txt"
git -C "$advancer" commit -aq -m "main changes conflict.txt"
git -C "$advancer" push -q origin main
rm -rf "$advancer"
git -C "$LOCAL" fetch -q
git -C "$LOCAL" branch -f main origin/main >/dev/null 2>&1

# Add untracked work, then heartbeat with -s — expect merge to fail mid-conflict.
# After failure, the work must be recoverable: either back on disk OR in stash list.
echo "stashed-work" > "$LOCAL/uncommitted.txt"
output=$(cd "$LOCAL" && git heartbeat -s main 2>&1) && rc=0 || rc=$?
[ "$rc" -ne 0 ] || fail "expected non-zero exit on conflict (got $rc)"
recovered=0
[ -f "$LOCAL/uncommitted.txt" ] && recovered=1
git -C "$LOCAL" stash list 2>/dev/null | grep -q "heartbeat" && recovered=1
[ "$recovered" = "1" ] || fail "stashed work was lost — neither on disk nor in stash list"
pass
teardown_sandbox

start_test "--help renders docstring"
output=$(git-heartbeat --help 2>&1)
assert_contains "$output" "pull latest on current and master" && pass

summary
