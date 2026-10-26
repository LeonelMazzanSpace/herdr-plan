#!/usr/bin/env bash
# Builds the read-only review package for one task.
#
# Usage:
#   bash make-review-package.sh --task T-004 --model opus --run-id <run-id> \
#     --reports <report-dir> --worktree <path> --branch <branch> --base <sha> \
#     [--notes <file>] [--attempt N] [--kind code]
#   bash make-review-package.sh --task T-002 --model opus --run-id <run-id> \
#     --reports <report-dir> --kind findings|document [--integrated <dir>] \
#     [--notes <file>] [--attempt N]
#
# --kind: code (default), findings or document. It does not read the plan, so pass the
# same kind the task has. Code requires --worktree --branch --base. findings and document
# require only --task --model --run-id --reports, reject --worktree --branch --base and
# produce a checklist without git diff.
# --integrated <dir> (document only): the dir of parts already integrated; the reviewer
# compares the part against them.
# --base: use the merge-base, git -C <worktree> merge-base <coordination-branch> HEAD,
# because the coordination branch may have been merged into the task branch.
# --notes holds orchestrator notes: deviations to judge, task-specific risks,
# finding classes already seen in earlier reviews.
# Writes <report-dir>/<task>.review-package.md (attempt 1) or
# <task>.review-package-a<N>.md (attempt N), mode 600, and prints its path.
# The reviewer writes <task>.review.md or <task>.review-a<N>.md, so earlier reviews are kept.
set -euo pipefail

die() { printf 'make-review-package: %s\n' "$1" >&2; exit 1; }

TASK= MODEL= RUN_ID= REPORTS= WT= BRANCH= BASE= NOTES= ATTEMPT=1 KIND=code INTEGRATED=
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || die "missing value for $1"
  case $1 in
    --task) TASK=$2 ;; --model) MODEL=$2 ;; --run-id) RUN_ID=$2 ;;
    --reports) REPORTS=$2 ;; --worktree) WT=$2 ;; --branch) BRANCH=$2 ;;
    --base) BASE=$2 ;; --notes) NOTES=$2 ;; --attempt) ATTEMPT=$2 ;;
    --kind) KIND=$2 ;; --integrated) INTEGRATED=$2 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift 2
done
case $KIND in code|findings|document) ;; *) die "invalid --kind '$KIND' (use code, findings or document)" ;; esac
[ -z "$INTEGRATED" ] || [ "$KIND" = document ] || die "--integrated is only for document tasks"
[ -z "$INTEGRATED" ] || [ -d "$INTEGRATED" ] || die "integrated dir not found: $INTEGRATED"
if [ "$KIND" = code ]; then REQUIRED="TASK MODEL RUN_ID REPORTS WT BRANCH BASE"
else
  [ -z "$WT$BRANCH$BASE" ] || die "--worktree, --branch and --base are only for code tasks"
  REQUIRED="TASK MODEL RUN_ID REPORTS"
fi
for v in $REQUIRED; do
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
if [ "$KIND" = code ]; then
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
elif [ "$KIND" = findings ]; then
cat <<EOF
# Review package — $TASK (review attempt $ATTEMPT)

RUN_ID / TASK_ID / ATTEMPT_ID: $RUN_ID / $TASK-review / $TASK-review-a$ATTEMPT
Role and requested model: review_worker (read-only, independent of the author of the findings) · model \`$MODEL\`
Objective: re-check the findings of $TASK and give a verdict on each one. **Do not edit any source or the author's files and do not commit.**
Inputs:
- Task package given to the author (scope, sources, contracts, constraints, vault excerpts): \`$REPORTS/$TASK.package.md\`
- Author report with the findings: \`$REPORTS/$TASK.md\`
- Author evidence: \`$REPORTS/evidence/$TASK/\`
Allowed writes: only \`$REVIEW\` and \`$REPORTS/evidence/$TASK-review/\` (create the folder if missing). Everything else is read-only.
Sample: re-check every Critical and Important finding, plus max(3, ceil(20% of the Minor findings)) Minor findings, or all the Minor findings when there are fewer than 3. State which Minor findings you sampled.
What to check:
1. Re-check each finding in the sample yourself, from the sources and not from the author's evidence alone: repeat its command, open its file:line or URL, look at its capture. Save what you observe under \`$REPORTS/evidence/$TASK-review/\`.
2. Give each finding in the sample one verdict, one line each: \`ID · verdict (confirmed | not reproduced | inaccurate) · how it was re-checked\`. confirmed: you reproduced it as described. not reproduced: you could not reproduce it. inaccurate: it exists but its severity or description is wrong; say what is right.
3. Every finding has the evidence fields of the "Findings format" contract in the package, and its ID is \`$TASK-F<NN>\`. List each finding that lacks them.
4. Every area of the task's scope is covered by the report, or its gap is stated. List each area not covered.
5. The Global Constraints and the Worker environment in the package held: no secrets, tokens, passwords or hashes in the report or the evidence; the author wrote only in the report dir.
6. Run the task's verification commands yourself and record the observed results.
Severity: Critical · Important · Minor, as defined by the "Severity scale" contract in the package.
Output: write \`$REVIEW\` with: verdict, the model you ran as, the sample, the per-finding verdicts, commands run with observed results, and other problems (severity, where, problem, suggested fix). Verdict is CHANGES_REQUIRED when a finding lacks its evidence fields, an area of the task's scope was not covered, or a Critical/Important finding is inaccurate; otherwise APPROVED. A not reproduced finding does not by itself require changes: the orchestrator moves it to the false positives. No secrets in the report.
End your final message with \`STATUS: PASS\` (review completed, whatever the verdict) or \`STATUS: BLOCKED\`/\`FAIL\`, and \`REPORT: $REVIEW\`.
Do not edit the sources, the global scratchpad or Obsidian. Do not delegate to other Herdr agents.
EOF
else
if [ -n "$INTEGRATED" ]; then
  INTEGRATED_LINE="- Parts already integrated: \`$INTEGRATED\` (compare the part against them)"
  INTEGRATED_CHECK="Compare the part with the parts in \`$INTEGRATED\`. List every statement that would contradict an integrated part, quoting both."
else
  INTEGRATED_LINE="- Parts already integrated: none given, so no part to compare against"
  INTEGRATED_CHECK="No integrated parts were given: skip the comparison with other parts and say so in the review."
fi
cat <<EOF
# Review package — $TASK (review attempt $ATTEMPT)

RUN_ID / TASK_ID / ATTEMPT_ID: $RUN_ID / $TASK-review / $TASK-review-a$ATTEMPT
Role and requested model: review_worker (read-only, independent of the author of the part) · model \`$MODEL\`
Objective: review the part written for $TASK against its sources, the outline and the integrated parts, and report findings. **Do not edit any source or the author's files and do not commit.**
Inputs:
- Task package given to the author (outline, sources, style, contracts, constraints, vault excerpts): \`$REPORTS/$TASK.package.md\`
- Author report: \`$REPORTS/$TASK.md\`
- Part to review: \`$REPORTS/parts/$TASK.md\`
$INTEGRATED_LINE
Allowed writes: only \`$REVIEW\`. Everything else is read-only.
What to check:
1. Every section of the "Document outline" contract in the package is present. List each section that is missing.
2. Every claim has a source cited from the "Sources" contract or the task, and the source says it. Open the sources and check them. List each claim without a source (state its severity), and each claim the source does not support.
3. $INTEGRATED_CHECK
4. The Global Constraints and the style rules in the package hold: no secrets, tokens, passwords or hashes in the part.
5. Run the task's verification commands yourself and record the observed results.
Severity: Critical · Important · Minor, as in the package.
Output: write \`$REVIEW\` with: verdict, the model you ran as, commands run with observed results, and findings (severity, location in the part, problem, why it matters, suggested fix). Verdict is CHANGES_REQUIRED when a Critical/Important claim has no source, the part would contradict an integrated part, or a section of the outline is missing; otherwise APPROVED. Minor findings are notes and do not by themselves require changes. No secrets in the report.
End your final message with \`STATUS: PASS\` (review completed, whatever the verdict) or \`STATUS: BLOCKED\`/\`FAIL\`, and \`REPORT: $REVIEW\`.
Do not edit the sources, the global scratchpad or Obsidian. Do not delegate to other Herdr agents.
EOF
fi
if [ -n "$NOTES" ]; then
  printf '\n## Orchestrator notes\n\n'; cat "$NOTES"
fi
} > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
chmod 600 "$OUT"
printf '%s\n' "$OUT"
