#!/usr/bin/env bash
# Runs every tests/test-*.sh, then the check-moved-text invocations below, and
# prints "ok <name>" / "FAIL <name>" per test.
# Each test script prints one "ok <name>" or "FAIL <name>" line per test and
# exits non-zero when any of its tests failed. Exit 1 if anything failed.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
status=0
for t in "$HERE"/test-*.sh; do
  [ -f "$t" ] || continue
  out=$(bash "$t" 2>&1) || status=1
  printf '%s\n' "$out"
  case $out in *FAIL*) status=1 ;; esac
done

# check-moved-text <name> <args of tests/check-moved-text.sh>: code text moved
# out of a baseline skill file must still exist verbatim. Prints ok or FAIL.
check-moved-text() {
  local name=$1; shift
  local out
  if out=$(cd "$ROOT" && bash tests/check-moved-text.sh "$@" 2>&1); then
    printf 'ok check-moved-text %s\n' "$name"
  else
    printf 'FAIL check-moved-text %s\n%s\n' "$name" "$out"
    status=1
  fi
}

check-moved-text writing --old 759fd7a:writing-herdr-plans/SKILL.md --allow tests/allowed-changes/writing-SKILL.txt writing-herdr-plans/SKILL.md writing-herdr-plans/kinds/code.md

exit "$status"
