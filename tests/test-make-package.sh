#!/usr/bin/env bash
# Tests for executing-herdr-plans/scripts/make-package.sh task kinds.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
SCRIPT="$ROOT/executing-herdr-plans/scripts/make-package.sh"
PLAN="$HERE/fixtures/plan.md"
BASELINE_COMMIT=759fd7a

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
git -C "$ROOT" show "$BASELINE_COMMIT:executing-herdr-plans/scripts/make-package.sh" > "$WORK/baseline.sh"

fail=0
pass() { printf 'ok %s\n' "$1"; }
bad() { printf 'FAIL %s: %s\n' "$1" "$2"; fail=1; }

# Runs a script into a fresh report dir. Sets REPORTS, RC, ERR.
run() {
  script=$1; shift
  REPORTS=$(mktemp -d "$WORK/reports.XXXXXX")
  RC=0
  bash "$script" --reports "$REPORTS" "$@" > "$WORK/stdout" 2> "$WORK/stderr" || RC=$?
  ERR=$(cat "$WORK/stderr")
}

COMMON=(--plan "$PLAN" --model sonnet --why test --run-id run-1 --coord /coord)
CODE_ARGS=(--worktree /wt --branch feature/x --base abc123 --coord-branch coord)

test_code_identical_to_baseline() {
  n=$1; shift
  REPORTS=$(mktemp -d "$WORK/reports.XXXXXX")
  args=("${COMMON[@]}" --task T-001 "${CODE_ARGS[@]}" --reports "$REPORTS")
  bash "$WORK/baseline.sh" "${args[@]}" > /dev/null 2>&1 || { bad "$n" "baseline failed"; return; }
  cp "$REPORTS/T-001.package.md" "$WORK/baseline.out"
  rm -f "$REPORTS/T-001.package.md"
  bash "$SCRIPT" "${args[@]}" "$@" > /dev/null 2>&1 || { bad "$n" "current script failed"; return; }
  if cmp -s "$WORK/baseline.out" "$REPORTS/T-001.package.md"; then pass "$n"; else bad "$n" "output differs from baseline"; fi
}

test_code_identical_to_baseline code_identical_to_baseline
test_code_identical_to_baseline explicit_code_kind_identical --kind code

# Asserts on the last run. check_contains <name> <file> <text...>
pkg_has() { grep -qF -- "$2" "$1"; }

run "$SCRIPT" "${COMMON[@]}" --task T-002
P="$REPORTS/T-002.package.md"
if [ "$RC" = 0 ] && pkg_has "$P" 'findings_worker (read-only on sources' && pkg_has "$P" 'T-002-F' \
  && pkg_has "$P" 'evidence/T-002/' && pkg_has "$P" '## Findings format' && pkg_has "$P" '## Severity scale' \
  && ! grep -qiE 'branch|merge-base' "$P"; then pass findings_package
else bad findings_package "rc=$RC $ERR"; fi

run "$SCRIPT" "${COMMON[@]}" --task T-003
P="$REPORTS/T-003.package.md"
if [ "$RC" = 0 ] && pkg_has "$P" 'document_worker' && pkg_has "$P" 'parts/T-003.md' \
  && pkg_has "$P" '## Document outline' && ! grep -qiE 'branch|merge-base' "$P"; then pass document_package
else bad document_package "rc=$RC $ERR"; fi

run "$SCRIPT" "${COMMON[@]}" --task T-004
if [ "$RC" = 0 ] && pkg_has "$REPORTS/T-004.package.md" 'findings_worker'; then pass kind_normalized
else bad kind_normalized "rc=$RC $ERR"; fi

expect_fail() {
  name=$1; text=$2
  if [ "$RC" = 1 ] && printf '%s' "$ERR" | grep -qF -- "$text"; then pass "$name"
  else bad "$name" "rc=$RC stderr=$ERR"; fi
}

run "$SCRIPT" "${COMMON[@]}" --task T-005
expect_fail kind_invalid "invalid Kind 'audit' in T-005"

run "$SCRIPT" "${COMMON[@]}" --task T-002 --kind document
expect_fail kind_flag_conflict "--kind document contradicts Kind findings in T-002"

run "$SCRIPT" "${COMMON[@]}" --task T-002 --worktree /x
expect_fail worktree_rejected_for_findings "--worktree is only for code tasks"

run "$SCRIPT" "${COMMON[@]}" --task T-006
expect_fail vault_required_for_findings "pass --vault-excerpts"

exit "$fail"
