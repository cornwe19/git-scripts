#!/bin/bash
# Tests for git-amend-old.

source "$(dirname "$0")/lib/common.sh"

echo "git-amend-old"

# Build a 3-commit history: initial -> A -> B (HEAD on main)
build_history() {
    local L=$1
    echo "a" > "$L/a.txt"; git -C "$L" add a.txt; git -C "$L" commit -q -m "add A"
    echo "b" > "$L/b.txt"; git -C "$L" add b.txt; git -C "$L" commit -q -m "add B"
}

start_test "missing arg → exit 2 with usage hint"
setup_sandbox ao-missing
output=$(cd "$LOCAL" && git amend-old 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 2 && assert_contains "$output" "missing target commit" && pass
teardown_sandbox

start_test "invalid ref → exit 2 with clear error"
setup_sandbox ao-bad-ref
build_history "$LOCAL"
output=$(cd "$LOCAL" && git amend-old does-not-exist 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 2 && assert_contains "$output" "is not a valid commit" && pass
teardown_sandbox

start_test "no staged changes → exit 2"
setup_sandbox ao-nothing-staged
build_history "$LOCAL"
target=$(git -C "$LOCAL" rev-parse HEAD~1)
output=$(cd "$LOCAL" && git amend-old "$target" 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 2 && assert_contains "$output" "no staged changes" && pass
teardown_sandbox

start_test "detached HEAD → exit 2"
setup_sandbox ao-detached
build_history "$LOCAL"
target=$(git -C "$LOCAL" rev-parse HEAD~1)
git -C "$LOCAL" checkout -q --detach HEAD
echo "x" > "$LOCAL/x.txt"; git -C "$LOCAL" add x.txt
output=$(cd "$LOCAL" && git amend-old "$target" 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 2 && assert_contains "$output" "detached HEAD" && pass
teardown_sandbox

start_test "target not ancestor of HEAD → exit 2"
setup_sandbox ao-not-ancestor
build_history "$LOCAL"
git -C "$LOCAL" checkout -q -b sibling main
echo "s" > "$LOCAL/s.txt"; git -C "$LOCAL" add s.txt
git -C "$LOCAL" commit -q -m "sibling commit"
sibling_sha=$(git -C "$LOCAL" rev-parse HEAD)
git -C "$LOCAL" checkout -q main
echo "staged" >> "$LOCAL/a.txt"; git -C "$LOCAL" add a.txt
output=$(cd "$LOCAL" && git amend-old "$sibling_sha" 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 2 && assert_contains "$output" "is not an ancestor of HEAD" && pass
teardown_sandbox

start_test "happy path: stage edit, fold into A, B preserved"
setup_sandbox ao-happy
build_history "$LOCAL"
target=$(git -C "$LOCAL" rev-parse HEAD~1)
echo "more" >> "$LOCAL/a.txt"
git -C "$LOCAL" add a.txt
output=$(cd "$LOCAL" && git amend-old "$target" 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 0 || { echo "$output"; teardown_sandbox; summary; exit 1; }
# After amend-old: A's commit should now contain both lines, B should still exist
a_at_target=$(git -C "$LOCAL" show "HEAD~1:a.txt")
b_at_head=$(git -C "$LOCAL" show "HEAD:b.txt")
assert_eq "$a_at_target" "a
more" && assert_eq "$b_at_head" "b" && \
    assert_contains "$output" "Folded staged changes" && pass
teardown_sandbox

start_test "happy path with extra dirty file → stash + restore"
setup_sandbox ao-dirty
build_history "$LOCAL"
target=$(git -C "$LOCAL" rev-parse HEAD~1)
echo "staged-edit" >> "$LOCAL/a.txt"
git -C "$LOCAL" add a.txt
echo "dirty-unstaged" > "$LOCAL/scratch.txt"
output=$(cd "$LOCAL" && git amend-old "$target" 2>&1) && rc=0 || rc=$?
assert_eq "$rc" 0 || { echo "$output"; teardown_sandbox; summary; exit 1; }
[ -f "$LOCAL/scratch.txt" ] || fail "untracked file should be restored"
assert_contains "$output" "Folded staged changes" && pass
teardown_sandbox

start_test "--help renders docstring"
output=$(git-amend-old --help 2>&1)
assert_contains "$output" "fold staged changes into an older commit" && pass

summary
