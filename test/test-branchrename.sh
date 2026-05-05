#!/bin/bash
# Tests for git-branchrename.

source "$(dirname "$0")/lib/common.sh"

echo "git-branchrename"

start_test "missing arg → exit 2"
setup_sandbox br-missing
output=$(cd "$LOCAL" && git branchrename 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 2 && assert_contains "$output" "missing new branch name" && pass
teardown_sandbox

start_test "detached HEAD → exit 2"
setup_sandbox br-detached
echo "a" > "$LOCAL/a.txt"; git -C "$LOCAL" add a.txt; git -C "$LOCAL" commit -q -m "A"
git -C "$LOCAL" checkout -q --detach HEAD
output=$(cd "$LOCAL" && git branchrename foo 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 2 && assert_contains "$output" "detached HEAD" && pass
teardown_sandbox

start_test "same name → exit 2"
setup_sandbox br-same
output=$(cd "$LOCAL" && git branchrename main 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 2 && assert_contains "$output" "same as the current branch" && pass
teardown_sandbox

start_test "happy path with upstream: local + remote rename"
setup_sandbox br-happy
git -C "$LOCAL" checkout -q -b old-name
echo "x" > "$LOCAL/x.txt"; git -C "$LOCAL" add x.txt; git -C "$LOCAL" commit -q -m "x"
git -C "$LOCAL" push -q -u origin old-name
output=$(cd "$LOCAL" && git branchrename new-name 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 0 || { echo "$output"; teardown_sandbox; summary; exit 1; }
assert_branch_exists "$LOCAL" new-name
assert_branch_missing "$LOCAL" old-name
git -C "$REMOTE" rev-parse --verify --quiet refs/heads/new-name >/dev/null || fail "remote new-name missing"
git -C "$REMOTE" rev-parse --verify --quiet refs/heads/old-name >/dev/null && fail "remote old-name should be gone"
pass
teardown_sandbox

start_test "no upstream: local rename only, no remote ops"
setup_sandbox br-no-upstream
git -C "$LOCAL" checkout -q -b local-only
echo "x" > "$LOCAL/x.txt"; git -C "$LOCAL" add x.txt; git -C "$LOCAL" commit -q -m "x"
output=$(cd "$LOCAL" && git branchrename renamed 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 0 || { echo "$output"; teardown_sandbox; summary; exit 1; }
assert_branch_exists "$LOCAL" renamed
assert_contains "$output" "No upstream"
pass
teardown_sandbox

start_test "--help renders docstring"
output=$(git-branchrename --help 2>&1)
assert_contains "$output" "rename the current branch" && pass

summary
