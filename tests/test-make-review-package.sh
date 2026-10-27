#!/usr/bin/env bash
# Tests for executing-herdr-plans/scripts/make-review-package.sh task kinds.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
PKG_SCRIPT="$ROOT/executing-herdr-plans/scripts/make-package.sh"
SCRIPT="$ROOT/executing-herdr-plans/scripts/make-review-package.sh"
PLAN="$HERE/fixtures/plan.md"
BASELINE_COMMIT=759fd7a

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
git -C "$ROOT" show "$BASELINE_COMMIT:executing-herdr-plans/scripts/make-review-package.sh" > "$WORK/baseline.sh"

fail=0
pass() { printf 'ok %s\n' "$1"; }
bad() { printf 'FAIL %s: %s\n' "$1" "$2"; fail=1; }

# Builds the task package and a stub implementer report for <task> in a fresh
# report dir. Sets REPORTS. Extra arguments go to make-package.sh.
prepare() {
  task=$1; shift
  REPORTS=$(mktemp -d "$WORK/reports.XXXXXX")
  bash "$PKG_SCRIPT" --plan "$PLAN" --model sonnet --why test --run-id run-1 --coord /coord \
    --reports "$REPORTS" --task "$task" "$@" > /dev/null 2>&1 || { bad "prepare $task" "make-package failed"; return 1; }
  printf 'stub implementer report\n' > "$REPORTS/$task.md"
}

# Runs the review script on the prepared REPORTS. Sets RC, ERR.
review() {
  RC=0
  bash "$SCRIPT" --model opus --run-id run-1 --reports "$REPORTS" "$@" > "$WORK/stdout" 2> "$WORK/stderr" || RC=$?
  ERR=$(cat "$WORK/stderr")
}

has() { grep -qF -- "$2" "$1"; }

test_review_code_identical_to_baseline() {
  n=$1; shift
  prepare T-001 --worktree /wt --branch feature/x --base abc123 --coord-branch coord || return
  args=(--task T-001 --model opus --run-id run-1 --reports "$REPORTS" --worktree /wt --branch feature/x --base abc123)
  bash "$WORK/baseline.sh" "${args[@]}" > /dev/null 2>&1 || { bad "$n" "baseline failed"; return; }
  cp "$REPORTS/T-001.review-package.md" "$WORK/baseline.out"
  rm -f "$REPORTS/T-001.review-package.md"
  bash "$SCRIPT" "${args[@]}" "$@" > /dev/null 2>&1 || { bad "$n" "current script failed"; return; }
  if cmp -s "$WORK/baseline.out" "$REPORTS/T-001.review-package.md"; then pass "$n"; else bad "$n" "output differs from baseline"; fi
}

test_review_code_identical_to_baseline review_code_identical_to_baseline
test_review_code_identical_to_baseline review_explicit_code_kind_identical --kind code

prepare T-002 && {
  review --task T-002 --kind findings
  P="$REPORTS/T-002.review-package.md"
  if [ "$RC" = 0 ] && has "$P" 'confirmed' && has "$P" 'not reproduced' && has "$P" 'inaccurate' \
    && has "$P" 'plus max(3, ceil(20% of the Minor findings)) Minor findings, or all the Minor findings when there are fewer than 3' \
    && has "$P" 'evidence/T-002-review/' \
    && has "$P" "Verdict is CHANGES_REQUIRED when a finding lacks its evidence fields, an area of the task's scope was not covered, or a Critical/Important finding is inaccurate; otherwise APPROVED" \
    && ! has "$P" 'git -C'; then pass review_findings
  else bad review_findings "rc=$RC $ERR"; fi
}

prepare T-003 && {
  mkdir -p "$WORK/integrated"
  review --task T-003 --kind document --integrated "$WORK/integrated"
  P="$REPORTS/T-003.review-package.md"
  if [ "$RC" = 0 ] && has "$P" 'parts/T-003.md' && has "$P" "$WORK/integrated" \
    && has "$P" 'List each claim without a source' && has "$P" 'List every statement that would contradict an integrated part' \
    && has "$P" 'Verdict is CHANGES_REQUIRED when a Critical/Important claim has no source, the part would contradict an integrated part, or a section of the outline is missing; otherwise APPROVED' \
    && has "$P" 'the author wrote only its part and its report under the report dir' \
    && has "$P" "The author report lists the sources consulted" \
    && ! has "$P" 'git -C'; then pass review_document
  else bad review_document "rc=$RC $ERR"; fi

  review --task T-003 --kind document
  P="$REPORTS/T-003.review-package.md"
  if [ "$RC" = 0 ] && has "$P" 'Parts already integrated: none given' \
    && has "$P" 'skip the comparison with other parts and say so in the review' && ! has "$P" "$WORK/integrated"; then pass review_document_without_integrated
  else bad review_document_without_integrated "rc=$RC $ERR"; fi
}

prepare T-002 && {
  review --task T-002 --kind findings --integrated "$WORK/integrated"
  if [ "$RC" = 1 ] && printf '%s' "$ERR" | grep -qF -- '--integrated is only for document'; then pass review_integrated_only_for_document
  else bad review_integrated_only_for_document "rc=$RC stderr=$ERR"; fi

  review --task T-002 --kind findings --worktree /wt
  if [ "$RC" = 1 ] && printf '%s' "$ERR" | grep -qF -- '--worktree'; then pass review_worktree_rejected_for_findings
  else bad review_worktree_rejected_for_findings "rc=$RC stderr=$ERR"; fi

  review --task T-002 --kind audit
  if [ "$RC" = 1 ] && printf '%s' "$ERR" | grep -qF -- "invalid --kind 'audit'"; then pass review_kind_invalid
  else bad review_kind_invalid "rc=$RC stderr=$ERR"; fi
}

exit "$fail"
