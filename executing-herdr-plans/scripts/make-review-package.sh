#!/usr/bin/env bash
# Builds the read-only review package for one task.
#
# Usage:
#   bash make-review-package.sh --task T-004 --model opus --run-id <run-id> \
#     --reports <report-dir> --worktree <path> --branch <branch> --base <sha> \
#     [--notes <file>] [--attempt N]
#
# --base: use the merge-base, git -C <worktree> merge-base <coordination-branch> HEAD,
# because the coordination branch may have been merged into the task branch.
# --notes holds orchestrator notes: deviations to judge, task-specific risks,
# finding classes already seen in earlier reviews.
# Writes <report-dir>/<task>.review-package.md (attempt 1) or
# <task>.review-package-a<N>.md (attempt N), mode 600, and prints its path.
# The reviewer writes <task>.review.md or <task>.review-a<N>.md, so earlier reviews are kept.
set -euo pipefail

die() { printf 'make-review-package: %s\n' "$1" >&2; exit 1; }

TASK= MODEL= RUN_ID= REPORTS= WT= BRANCH= BASE= NOTES= ATTEMPT=1
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || die "missing value for $1"
  case $1 in
    --task) TASK=$2 ;; --model) MODEL=$2 ;; --run-id) RUN_ID=$2 ;;
    --reports) REPORTS=$2 ;; --worktree) WT=$2 ;; --branch) BRANCH=$2 ;;
    --base) BASE=$2 ;; --notes) NOTES=$2 ;; --attempt) ATTEMPT=$2 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift 2
done
for v in TASK MODEL RUN_ID REPORTS WT BRANCH BASE; do
  eval "[ -n \"\${$v}\" ]" || die "missing --$(printf '%s' "$v" | tr 'A-Z_' 'a-z-')"
done
[ -f "$REPORTS/$TASK.package.md" ] || die "task package not found: $REPORTS/$TASK.package.md"
[ -f "$REPORTS/$TASK.md" ] || die "implementer report not found: $REPORTS/$TASK.md"
[ -z "$NOTES" ] || [ -f "$NOTES" ] || die "notes file not found: $NOTES"

SUFFIX=; [ "$ATTEMPT" = 1 ] || SUFFIX="-a$ATTEMPT"
OUT="$REPORTS/$TASK.review-package$SUFFIX.md"
REVIEW="$REPORTS/$TASK.review$SUFFIX.md"
trap 'rm -f "$OUT.tmp"' EXIT
{
cat <<EOF
# Review package — $TASK (review attempt $ATTEMPT)

RUN_ID / TASK_ID / ATTEMPT_ID: $RUN_ID / $TASK-review / $TASK-review-a$ATTEMPT
Role and requested model: review_worker (read-only, independent of the implementer) · model \`$MODEL\`
Objective: review the implementation of $TASK for spec/plan compliance and code quality, and report findings. **Do not edit any file and do not commit.**
Inputs:
- Task package given to the implementer (requirements, contracts, constraints, vault excerpts): \`$REPORTS/$TASK.package.md\`
- Implementer report: \`$REPORTS/$TASK.md\`
- Code: worktree \`$WT\`, branch \`$BRANCH\`; diff to review: \`git -C $WT diff $BASE...HEAD\` (and \`git -C $WT log $BASE..HEAD\`).
What to check:
1. Every acceptance criterion and step of the task is met. The changed files are only those the task allows; list any extra file.
2. The contracts in the package are followed exactly. Flag any deviation, and judge each deviation the implementer reported.
3. The Global Constraints in the package hold: typing, layering, validation at the edge (trim, NUL, bounds, ids), transactions, no secrets or PII in logs, UI copy rules.
4. The Review Focus items owned by this task are pinned by tests.
5. Security and correctness bugs; tests that do not test what they claim; extreme inputs that reach the database and return 500 instead of 400.
6. Run the task's verification commands yourself (lint, unit tests, e2e with the env already exported in your shell, build) and record the observed results. Do not start long-running servers.
Severity: Critical (security, data loss, broken contract or acceptance) · Important (spec deviation, missing test of a required case, layering violation) · Minor (style, naming).
Output: write \`$REVIEW\` with: verdict (APPROVED if there are no Critical or Important findings, else CHANGES_REQUIRED), the model you ran as, commands run with observed results, and findings (severity, file:line, problem, concrete failure scenario, suggested fix). No secrets in the report.
End your final message with \`STATUS: PASS\` (review completed, whatever the verdict) or \`STATUS: BLOCKED\`/\`FAIL\`, and \`REPORT: $REVIEW\`.
Do not edit files, the global scratchpad or Obsidian. Do not delegate to other Herdr agents.
EOF
if [ -n "$NOTES" ]; then
  printf '\n## Orchestrator notes\n\n'; cat "$NOTES"
fi
} > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
chmod 600 "$OUT"
printf '%s\n' "$OUT"
