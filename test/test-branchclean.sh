#!/bin/bash
# Tests for git-branchclean.

source "$(dirname "$0")/lib/common.sh"

echo "git-branchclean"

# ---------- Helpers specific to this test ----------

# make_branch <local-dir> <name> <file> <content>
make_branch() {
    local L=$1 name=$2 file=$3 content=$4
    git -C "$L" checkout -q main
    git -C "$L" checkout -q -b "$name"
    echo "$content" > "$L/$file"
    git -C "$L" add "$file"
    git -C "$L" commit -q -m "work on $name"
    git -C "$L" push -q -u origin "$name"
    git -C "$L" checkout -q main  # leave caller on main so branchclean can act
}

squash_into_main() {
    local L=$1 name=$2
    git -C "$L" checkout -q main
    git -C "$L" merge -q --squash "$name" >/dev/null
    git -C "$L" commit -q -m "squash-merge $name"
    git -C "$L" push -q origin main
}

# Run branchclean and answer all prompts with the given char (n or y).
# Uses expect's exact-match (-ex) to avoid shell/regex escaping headaches with
# the literal "[y/N]" prompt suffix.
run_with_answer() {
    local L=$1 answer=$2
    expect <<EOF >/dev/null 2>&1
log_user 0
spawn -noecho sh -c "cd '$L' && git branchclean"
set timeout 30
expect {
    -ex "y/N] " { send "$answer\r"; exp_continue }
    eof
}
EOF
}

# ---------- Tests ----------

start_test "no [gone] branches → no-op"
setup_sandbox bc-noop
output=$(cd "$LOCAL" && git branchclean 2>&1)
assert_not_contains "$output" "Deleted branch" && \
    assert_not_contains "$output" "Removing worktree" && \
    pass
teardown_sandbox

start_test "regular-merged [gone] branch deletes silently"
setup_sandbox bc-merged
make_branch "$LOCAL" feature-merged c.txt "C"
git -C "$LOCAL" merge -q --no-ff feature-merged -m "merge feature-merged"
git -C "$LOCAL" push -q origin main
git -C "$REMOTE" branch -D feature-merged >/dev/null 2>&1
output=$(cd "$LOCAL" && git branchclean 2>&1)
assert_branch_missing "$LOCAL" feature-merged && \
    assert_contains "$output" "Deleted branch feature-merged" && \
    pass
teardown_sandbox

start_test "squash-merged [gone] branch deletes silently (no prompt)"
setup_sandbox bc-squash
make_branch "$LOCAL" feature-squashed e.txt "E"
squash_into_main "$LOCAL" feature-squashed
git -C "$REMOTE" branch -D feature-squashed >/dev/null 2>&1
output=$(cd "$LOCAL" && git branchclean </dev/null 2>&1)
assert_branch_missing "$LOCAL" feature-squashed && \
    assert_not_contains "$output" "Force-delete" && \
    pass
teardown_sandbox

start_test "truly unmerged [gone] branch + answer N → branch kept"
setup_sandbox bc-unmerged-skip
make_branch "$LOCAL" feature-unmerged d.txt "D"
git -C "$REMOTE" branch -D feature-unmerged >/dev/null 2>&1
run_with_answer "$LOCAL" n
assert_branch_exists "$LOCAL" feature-unmerged && pass
teardown_sandbox

start_test "truly unmerged [gone] branch + answer Y → branch force-deleted"
setup_sandbox bc-unmerged-yes
make_branch "$LOCAL" feature-unmerged d.txt "D"
git -C "$REMOTE" branch -D feature-unmerged >/dev/null 2>&1
run_with_answer "$LOCAL" y
assert_branch_missing "$LOCAL" feature-unmerged && pass
teardown_sandbox

start_test "clean worktree on squash-merged branch removed silently"
setup_sandbox bc-clean-wt
make_branch "$LOCAL" feature-real e.txt "E"
squash_into_main "$LOCAL" feature-real
git -C "$LOCAL" worktree add -q "$LOCAL/wt-real" feature-real
git -C "$REMOTE" branch -D feature-real >/dev/null 2>&1
output=$(cd "$LOCAL" && git branchclean </dev/null 2>&1)
assert_branch_missing "$LOCAL" feature-real && \
    assert_contains "$output" "Removing worktree" && \
    [ ! -d "$LOCAL/wt-real" ] || fail "worktree dir should be gone"
pass
teardown_sandbox

start_test "dirty worktree + answer N → worktree + branch preserved"
setup_sandbox bc-dirty-skip
make_branch "$LOCAL" feature-dirty b.txt "B"
squash_into_main "$LOCAL" feature-dirty
git -C "$LOCAL" worktree add -q "$LOCAL/wt-dirty" feature-dirty
echo "edit" >> "$LOCAL/wt-dirty/b.txt"
echo "scratch" > "$LOCAL/wt-dirty/notes.txt"
git -C "$REMOTE" branch -D feature-dirty >/dev/null 2>&1
run_with_answer "$LOCAL" n
[ -d "$LOCAL/wt-dirty" ] || fail "worktree should still be there"
assert_branch_exists "$LOCAL" feature-dirty && pass
teardown_sandbox

start_test "dirty worktree + answer Y → worktree + branch removed"
setup_sandbox bc-dirty-yes
make_branch "$LOCAL" feature-dirty b.txt "B"
squash_into_main "$LOCAL" feature-dirty
git -C "$LOCAL" worktree add -q "$LOCAL/wt-dirty" feature-dirty
echo "edit" >> "$LOCAL/wt-dirty/b.txt"
git -C "$REMOTE" branch -D feature-dirty >/dev/null 2>&1
run_with_answer "$LOCAL" y
[ ! -d "$LOCAL/wt-dirty" ] || fail "worktree should be removed"
assert_branch_missing "$LOCAL" feature-dirty && pass
teardown_sandbox

start_test "currently on the [gone] branch in main worktree → helpful skip"
setup_sandbox bc-on-gone
make_branch "$LOCAL" feature-on-it x.txt "X"
git -C "$LOCAL" checkout -q feature-on-it
git -C "$REMOTE" branch -D feature-on-it >/dev/null 2>&1
output=$(cd "$LOCAL" && git branchclean </dev/null 2>&1)
assert_contains "$output" "checked out in the main worktree" && \
    assert_branch_exists "$LOCAL" feature-on-it && pass
teardown_sandbox

start_test "--help renders docstring"
output=$(git-branchclean --help 2>&1)
assert_contains "$output" "prune local branches whose upstream is gone" && pass

summary
