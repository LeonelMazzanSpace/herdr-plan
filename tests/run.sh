#!/usr/bin/env bash
# Runs every tests/test-*.sh and prints "ok <name>" / "FAIL <name>" per test.
# Each test script prints one "ok <name>" or "FAIL <name>" line per test and
# exits non-zero when any of its tests failed. Exit 1 if anything failed.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
status=0
for t in "$HERE"/test-*.sh; do
  [ -f "$t" ] || continue
  out=$(bash "$t" 2>&1) || status=1
  printf '%s\n' "$out"
  case $out in *FAIL*) status=1 ;; esac
done
exit "$status"
