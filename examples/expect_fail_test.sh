#!/bin/bash
# Negative-case wrapper: runs an inner ordeal_check gate that MUST fail
# (its fixture decides `sat`), and passes iff the inner gate fails for
# exactly that reason. This proves the rule actually gates on the verdict.
set -u

inner="$1"
echo "Running inner gate (expected to FAIL): $inner"

out="$("./$inner" 2>&1)"
status=$?
printf '%s\n' "$out"

if [ $status -eq 0 ]; then
    echo "ERROR: inner ordeal_check PASSED on a sat query — the gate is not gating"
    exit 1
fi

case "$out" in
    *"expected verdict 'unsat', got 'sat'"*)
        echo "OK: sat query correctly failed the ordeal_check gate"
        exit 0
        ;;
    *)
        echo "ERROR: inner gate failed, but not with the expected sat-verdict message"
        exit 1
        ;;
esac
