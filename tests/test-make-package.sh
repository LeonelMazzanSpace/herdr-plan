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

if grep '^Allowed writes:' "$P" | grep -qF 'parts/T-003.html'; then pass document_html_write_allowed
else bad document_html_write_allowed "html part not in the allowed writes"; fi

run "$SCRIPT" "${COMMON[@]}" --task T-007
if [ "$RC" = 0 ] && ! grep '^Allowed writes:' "$REPORTS/T-007.package.md" | grep -qF '.html'; then pass document_md_no_html_write
else bad document_md_no_html_write "rc=$RC or html path present for an md deliverable"; fi

run "$SCRIPT" "${COMMON[@]}" --task T-008
if [ "$RC" = 0 ] && ! grep '^Allowed writes:' "$REPORTS/T-008.package.md" | grep -qF '.html'; then pass document_html_word_alone_no_html_write
else bad document_html_word_alone_no_html_write "rc=$RC or html path present when the task only mentions html"; fi

run "$SCRIPT" "${COMMON[@]}" --task T-009
if [ "$RC" = 0 ] && grep '^Allowed writes:' "$REPORTS/T-009.package.md" | grep -qF 'parts/T-009.html'; then pass document_format_html_write_allowed
else bad document_format_html_write_allowed "rc=$RC or html path missing for a format: html task"; fi

run "$SCRIPT" "${COMMON[@]}" "${CODE_ARGS[@]}" --task T-010
if [ "$RC" = 0 ] && pkg_has "$REPORTS/T-010.package.md" 'implement_worker'; then pass kind_read_only_from_header_line
else bad kind_read_only_from_header_line "rc=$RC $ERR"; fi

# A task section larger than the pipe buffer must not kill the script (SIGPIPE).
BIG_PLAN="$WORK/big-plan.md"
{
  cat "$PLAN"
  printf '\n### Task T-011: Write a very large section\n\n**Kind:** document · **Model:** sonnet · **Depends on:** T-002 · **Contracts:** Document outline, Sources · **Vault:** none\n\n**Deliverable format:** html.\n\n'
  awk 'BEGIN { for (i = 0; i < 1500; i++) printf "Filler line %d of the large task section, padded to make the section exceed the pipe buffer by a wide margin.\n", i }'
} > "$BIG_PLAN"
run "$SCRIPT" --plan "$BIG_PLAN" --model sonnet --why test --run-id run-1 --coord /coord --task T-011
if [ "$(awk '/^### Task T-011:/ { f = 1 } f' "$BIG_PLAN" | wc -c)" -gt 140000 ] \
  && [ "$RC" = 0 ] && pkg_has "$REPORTS/T-011.package.md" 'document_worker' \
  && grep '^Allowed writes:' "$REPORTS/T-011.package.md" | grep -qF 'parts/T-011.html'; then pass large_task_section_builds
else bad large_task_section_builds "rc=$RC $ERR"; fi

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

run "$SCRIPT" "${COMMON[@]}" --task T-002 --branch b
expect_fail branch_rejected_for_findings "--branch is only for code tasks"

run "$SCRIPT" "${COMMON[@]}" --task T-002 --base abc123
expect_fail base_rejected_for_findings "--base is only for code tasks"

run "$SCRIPT" "${COMMON[@]}" --task T-002 --coord-branch coord
expect_fail coord_branch_rejected_for_findings "--coord-branch is only for code tasks"

run "$SCRIPT" "${COMMON[@]}" --task T-002 --role review
expect_fail role_review_rejected_for_findings "--role review is only for code tasks"

run "$SCRIPT" "${COMMON[@]}" --task T-003 --role review
expect_fail role_review_rejected_for_document "--role review is only for code tasks"

run "$SCRIPT" "${COMMON[@]}" --task T-001 --branch feature/x --base abc123 --coord-branch coord
expect_fail code_requires_worktree "missing --worktree"

run "$SCRIPT" "${COMMON[@]}" --task T-006
expect_fail vault_required_for_findings "pass --vault-excerpts"

# A code task with a prose line before its header line has no header line: the
# header fields (here Contracts) come from the whole task text, as in the baseline.
PROSE_PLAN="$WORK/prose-plan.md"
{
  cat "$PLAN"
  printf '\n### Task T-012: Build the order model with a lead-in\n\nThis task builds on the order model decided above.\n\n**Model:** sonnet · **Depends on:** none · **Contracts:** Data contract · **Vault:** none\n\n- [ ] **Step 1:** write the model.\n'
} > "$PROSE_PLAN"
prose_args=(--plan "$PROSE_PLAN" --model sonnet --why test --run-id run-1 --coord /coord --task T-012 "${CODE_ARGS[@]}")
REPORTS=$(mktemp -d "$WORK/reports.XXXXXX")
if bash "$WORK/baseline.sh" "${prose_args[@]}" --reports "$REPORTS" > /dev/null 2>&1; then
  cp "$REPORTS/T-012.package.md" "$WORK/baseline.out"
  rm -f "$REPORTS/T-012.package.md"
  if bash "$SCRIPT" "${prose_args[@]}" --reports "$REPORTS" > /dev/null 2>&1 \
    && cmp -s "$WORK/baseline.out" "$REPORTS/T-012.package.md" && grep -qF 'Order` has `id`' "$REPORTS/T-012.package.md"; then
    pass headerless_task_identical_to_baseline
  else bad headerless_task_identical_to_baseline "output differs from baseline or contract missing"; fi
else bad headerless_task_identical_to_baseline "baseline failed"; fi

# --kind findings on a task with no Kind header makes it a findings task.
run "$SCRIPT" "${COMMON[@]}" --task T-001 --kind findings
if [ "$RC" = 0 ] && pkg_has "$REPORTS/T-001.package.md" 'findings_worker'; then pass kind_flag_on_headerless_task
else bad kind_flag_on_headerless_task "rc=$RC $ERR"; fi

exit "$fail"
