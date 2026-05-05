#!/bin/bash
# Run every test-*.sh in this directory and aggregate results.

set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
total_pass=0
total_fail=0
failed_files=()

for t in "$DIR"/test-*.sh; do
    bash "$t"
    rc=$?
    # Each test's `summary` returns non-zero on failure; we just track it.
    if [ "$rc" -ne 0 ]; then
        failed_files+=("$(basename "$t")")
    fi
done

echo
echo "==========================================="
if [ "${#failed_files[@]}" -eq 0 ]; then
    echo "All test files passed."
    exit 0
fi
echo "Failed test files:"
for f in "${failed_files[@]}"; do
    echo "  - $f"
done
exit 1
