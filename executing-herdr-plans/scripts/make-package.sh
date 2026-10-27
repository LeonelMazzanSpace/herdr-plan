#!/usr/bin/env bash
# Builds a worker task package from a plan written with writing-herdr-plans.
# Sections are found by heading text, so the plan must use the skill's headings.
#
# Usage:
#   bash make-package.sh --plan <plan.md> --task T-004 --model sonnet --why "<rationale>" \
#     --run-id <run-id> --reports <report-dir> --worktree <path> --branch <branch> \
#     --base <sha> --coord <COORDINATION_ROOT> --coord-branch <coordination-branch> \
#     [--vault-excerpts <file>] [--contracts "Data contract,HTTP contract"] \
#     [--deps "<text>"] [--env "<text>"] [--notes <file>] [--attempt N] \
#     [--role implement|review] [--kind code|findings|document]
#
# --kind is the task kind; it defaults to the task's **Kind:** header field, or
# code when there is none. A flag that contradicts the header is an error.
# findings and document tasks have no worktree: they take --plan --task --model
# --why --run-id --reports --coord and reject --worktree --branch --base
# --coord-branch. They read the sources the package lists and write only under
# <report-dir> (the report, evidence/<task>/ or parts/<task>.md).
#
# --role review packages a read-only code task (e.g. the cross-cutting review of
# code): no edits, no commits, findings report. It is code-only: a non-code review
# is a findings task.
# Attempt 1 writes <report-dir>/<task>.package.md and asks for <task>.md;
# attempt N > 1 writes <task>.package-aN.md and asks for <task>-aN.md, so a
# full restart never overwrites earlier files. Fix rounds use
# fix-round-template.md instead and keep attempt 1's files.
# Output mode is 600; the script prints the package path.
# Fails if a required section, a listed contract heading, or the vault
# excerpts for a task that lists vault notes are missing.
set -euo pipefail

die() { printf 'make-package: %s\n' "$1" >&2; exit 1; }

PLAN= TASK= MODEL= WHY= RUN_ID= REPORTS= WT= BRANCH= BASE= COORD= COORD_BRANCH=
VAULT= CONTRACTS= DEPS= ENV_NOTE= NOTES= ATTEMPT=1 ROLE=implement KIND_FLAG=
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || die "missing value for $1"
  case $1 in
    --plan) PLAN=$2 ;; --task) TASK=$2 ;; --model) MODEL=$2 ;; --why) WHY=$2 ;;
    --run-id) RUN_ID=$2 ;; --reports) REPORTS=$2 ;; --worktree) WT=$2 ;;
    --branch) BRANCH=$2 ;; --base) BASE=$2 ;; --coord) COORD=$2 ;;
    --coord-branch) COORD_BRANCH=$2 ;;
    --vault-excerpts) VAULT=$2 ;; --contracts) CONTRACTS=$2 ;; --deps) DEPS=$2 ;;
    --env) ENV_NOTE=$2 ;; --notes) NOTES=$2 ;; --attempt) ATTEMPT=$2 ;;
    --role) ROLE=$2 ;; --kind) KIND_FLAG=$2 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift 2
done
for v in PLAN TASK MODEL WHY RUN_ID REPORTS COORD; do
  eval "[ -n \"\${$v}\" ]" || die "missing --$(printf '%s' "$v" | tr 'A-Z_' 'a-z-')"
done
case $ROLE in implement|review) ;; *) die "--role must be implement or review" ;; esac
[ -f "$PLAN" ] || die "plan not found: $PLAN"
[ -d "$REPORTS" ] || die "report dir not found: $REPORTS"
[ -z "$NOTES" ] || [ -f "$NOTES" ] || die "notes file not found: $NOTES"
[ -z "$VAULT" ] || [ -f "$VAULT" ] || die "vault excerpts file not found: $VAULT"

# Prints the first section at heading level $2 whose text is exactly $1, or $1
# followed by " (…)"; a $1 ending in ":" matches as a prefix ("Task T-004:").
# Stops at the next heading of the same or higher level. Headings inside code
# fences are ignored; CRLF line endings are tolerated.
section() {
  awk -v want="$1" -v lvl="$2" '
    function heading_level(line) { return match(line, /^#+ /) ? RLENGTH - 1 : 0 }
    function matches(text) {
      sub(/[[:space:]]+$/, "", text)
      if (text == want || index(text, want " (") == 1) return 1
      return substr(want, length(want)) == ":" && index(text, want) == 1
    }
    {
      fence = match($0, /^(`{3,}|~{3,})/) ? RLENGTH : 0
      h = (!infence && !fence) ? heading_level($0) : 0
      if (on && h > 0 && h <= lvl) on = 0
      if (!on && !done && h == lvl && matches(substr($0, lvl + 2))) { on = 1; done = 1 }
      if (on) buf[++n] = $0
      if (fence && !infence) { infence = fence }
      else if (fence && infence && fence >= infence && $0 ~ /^(`+|~+)[[:space:]]*$/) { infence = 0 }
    }
    END {
      while (n > 0 && (buf[n] ~ /^[[:space:]]*$/ || buf[n] == "---")) n--
      for (i = 1; i <= n; i++) print buf[i]
    }' "$PLAN"
}

required() {
  out=$(section "$1" "$2")
  [ -n "$out" ] || die "section not found in plan: '$1'"
  printf '%s\n\n' "$out"
}

is_none() {
  case $(printf '%s' "$1" | tr 'A-Z' 'a-z') in ''|none|-|–|—|n/a) return 0 ;; esac
  return 1
}

TASK_TEXT=$(section "Task $TASK:" 3)
[ -n "$TASK_TEXT" ] || die "task heading not found: '### Task $TASK:' (append the task to the plan first)"

# The task header is the first non-blank line under the heading when it starts
# with **; its fields are read from there only, never from the task body. A task
# with no such line reads its fields from the whole task text, as the baseline
# did, except Kind, which never falls back (no header line means code). awk
# reads all its input (no early exit), so a large task section cannot SIGPIPE
# printf.
TASK_HEADER=$(printf '%s\n' "$TASK_TEXT" | awk 'NR > 1 && NF && !seen { seen = 1; if ($0 ~ /^\*\*/) print }')
HEADER_SRC=${TASK_HEADER:-$TASK_TEXT}
header_field() {
  printf '%s\n' "${2-$HEADER_SRC}" | grep -m1 -o "\*\*$1:\*\* [^·]*" | sed -e "s/^\*\*$1:\*\* //" -e 's/[[:space:]]*$//' || true
}
trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
lower() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }
valid_kind() { case $1 in code|findings|document) return 0 ;; esac; return 1; }

KIND_RAW=$(trim "$(header_field Kind "$TASK_HEADER")")
KIND_HEADER=$(lower "$KIND_RAW")
KIND_FLAG=$(lower "$(trim "$KIND_FLAG")")
[ -z "$KIND_HEADER" ] || valid_kind "$KIND_HEADER" \
  || die "invalid Kind '$KIND_RAW' in $TASK (expected code, findings or document)"
[ -z "$KIND_FLAG" ] || valid_kind "$KIND_FLAG" \
  || die "invalid --kind '$KIND_FLAG' (expected code, findings or document)"
[ -z "$KIND_HEADER" ] || [ -z "$KIND_FLAG" ] || [ "$KIND_HEADER" = "$KIND_FLAG" ] \
  || die "--kind $KIND_FLAG contradicts Kind $KIND_HEADER in $TASK"
KIND=${KIND_HEADER:-${KIND_FLAG:-code}}

if [ "$KIND" = code ]; then
  for v in WT BRANCH BASE COORD_BRANCH; do
    eval "[ -n \"\${$v}\" ]" || die "missing --$(printf '%s' "$v" | sed 's/^WT$/WORKTREE/' | tr 'A-Z_' 'a-z-')"
  done
else
  [ "$ROLE" = implement ] || die "--role review is only for code tasks"
  for pair in "worktree:$WT" "branch:$BRANCH" "base:$BASE" "coord-branch:$COORD_BRANCH"; do
    [ -z "${pair#*:}" ] || die "--${pair%%:*} is only for code tasks"
  done
fi

[ -n "$CONTRACTS" ] || CONTRACTS=$(header_field Contracts)
[ -n "$DEPS" ] || DEPS=$(header_field 'Depends on')
VAULT_NOTES=$(header_field Vault)
if ! is_none "$VAULT_NOTES" && [ -z "$VAULT" ]; then
  die "task lists vault notes ($VAULT_NOTES): pass --vault-excerpts"
fi

SUFFIX=; [ "$ATTEMPT" = 1 ] || SUFFIX="-a$ATTEMPT"
OUT="$REPORTS/$TASK.package$SUFFIX.md"
REPORT="$REPORTS/$TASK$SUFFIX.md"
trap 'rm -f "$OUT.tmp"' EXIT
DIFF_BASE=; [ "$KIND" != code ] || DIFF_BASE="\$(git merge-base $COORD_BRANCH HEAD)"

LOCATION_LINE="Checkout/worktree, branch, and base commit: \`$WT\` · branch \`$BRANCH\` · base \`$BASE\` (coordination branch \`$COORD_BRANCH\`)."
ALLOWED_LINE="Allowed files and scope boundaries: exactly the \"Files\" list of your task. Do not touch dependency manifests or lockfiles (need a dependency → BLOCKED). Do not touch other worktrees, other databases or the coordination checkout."
CHECKS_LINE="Required tests/checks: the \"Verify\" step(s) of your task, run from your worktree root, all green before committing."
if [ "$KIND" != code ]; then
  LOCATION_LINE="Working directory and sources (read-only): \`$COORD\` and the sources your task and Worker environment list."
  CHECKS_LINE="Required tests/checks: the \"Verify\" step(s) of your task, all green before writing the report."
  GIT_LINE="Git: read-only. No commits, no edits to the sources, no push/merge/rebase."
fi
if [ "$KIND" = findings ]; then
  ROLE_LINE="findings_worker (read-only on sources, single task, no orchestration)"
  OBJECTIVE="perform **only** the survey in the task section \"$TASK\" quoted at the end, verify every finding, and write the report. **Do not edit the sources and do not commit.**"
  ALLOWED_LINE="Allowed writes: only \`$REPORT\` and \`$REPORTS/evidence/$TASK/\` (create the folder if missing). Everything else is read-only: do not edit, create or delete anything in the sources or the coordination checkout, and do not touch dependency manifests or lockfiles (need a dependency → BLOCKED)."
  OUTPUT="Output: write \`$REPORT\` with: Task, Attempt, Status (PASS|FAIL|BLOCKED), the model you ran as (from your session/status line if visible, else \"not verified\"), the scope covered and not covered, commands run with observed results, and findings in the \"Findings format\" contract, each with the ID \`$TASK-F<NN>\` (F01, F02, ...) and its evidence saved under \`$REPORTS/evidence/$TASK/\`. No secrets, tokens, passwords or hashes in the report or the evidence."
elif [ "$KIND" = document ]; then
  HTML_PART=
  if printf '%s\n' "$TASK_TEXT" | grep -iE '\.html|format:\*{0,2}[[:space:]]+html' > /dev/null; then
    HTML_PART=" and \`$REPORTS/parts/$TASK.html\`"
  fi
  ROLE_LINE="document_worker (single task, no orchestration)"
  OBJECTIVE="write **only** the document part of the task section \"$TASK\" quoted at the end to \`$REPORTS/parts/$TASK.md\`, following the \"Document outline\" contract and citing a \"Sources\" entry for every claim, and write the report. **Do not edit the sources and do not commit.**"
  ALLOWED_LINE="Allowed writes: only \`$REPORT\` and \`$REPORTS/parts/$TASK.md\`$HTML_PART (create the folder if missing). Everything else is read-only: do not edit, create or delete anything in the sources or the coordination checkout, and do not touch dependency manifests or lockfiles (need a dependency → BLOCKED)."
  OUTPUT="Output: write \`$REPORT\` with: Task, Attempt, Status (PASS|FAIL|BLOCKED), the model you ran as (from your session/status line if visible, else \"not verified\"), the sources consulted, and open questions. The part itself goes in \`$REPORTS/parts/$TASK.md\`. No secrets, tokens, passwords or hashes in the report or the part."
elif [ "$ROLE" = review ]; then
  ROLE_LINE="review_worker (read-only, single task, no orchestration)"
  OBJECTIVE="perform **only** the read-only work in the task section \"$TASK\" quoted at the end and write the findings report. **Do not edit any file and do not commit.**"
  GIT_LINE="Git: read-only. No commits, no edits, no push/merge/rebase."
  OUTPUT="Output: write \`$REPORT\` with: Task, Attempt, Status (PASS|FAIL|BLOCKED; PASS means the review was completed, whatever it found), the model you ran as (from your session/status line if visible, else \"not verified\"), commands run with observed results, and findings ranked Critical / Important / Minor, each with file:line, a concrete failure scenario and a suggested fix. No secrets, tokens, passwords or hashes in the report."
else
  ROLE_LINE="implement_worker (single task, no orchestration)"
  OBJECTIVE="implement **only** the task section \"$TASK\" quoted at the end, following its steps (TDD where it says so), commit on your branch, and write the report."
  GIT_LINE="Git: commit only on your branch, conventional commits, explicit paths, no push/merge/rebase/amend."
  OUTPUT="Output: write \`$REPORT\` with: Task, Attempt, Status (PASS|FAIL|BLOCKED), the model you ran as (from your session/status line if visible, else \"not verified\"), summary, commits (hash + subject), files changed (\`git diff --stat $DIFF_BASE...HEAD\`), tests run with observed results (counts), noncompliance with the plan (and why), blockers, and suggested Obsidian changes (facts only). No secrets, tokens, passwords or hashes in the report."
fi
if is_none "$VAULT_NOTES"; then
  VAULT_LINE="none for this task."
else
  VAULT_LINE="$VAULT_NOTES. Excerpts are quoted below by the orchestrator; you have no vault access and do not need it."
fi

{
cat <<EOF
# Task package — $TASK (attempt $ATTEMPT)

RUN_ID / TASK_ID / ATTEMPT_ID: $RUN_ID / $TASK / $TASK-a$ATTEMPT
Role and requested model: $ROLE_LINE · model \`$MODEL\` ($WHY)
Objective and expected result: $OBJECTIVE
Acceptance criteria: the acceptance criteria and verification steps inside the task section, plus Global Constraints. All required checks green.
Relevant context and current decisions: "Decisions recorded for this plan", "Global Constraints" and "Review Focus" below.
Obsidian notes consulted: $VAULT_LINE
Dependencies and agreed contracts: ${DEPS:-none}. The contract sections below are fixed: do not change them. If a contract is wrong or impossible, stop and report BLOCKED with the exact problem.
$LOCATION_LINE
$ALLOWED_LINE
COORDINATION_ROOT and global scratchpad (read-only): \`$COORD\` · \`$COORD/SCRATCHPAD.md\` — do not edit either.
EOF
[ -z "$ENV_NOTE" ] || printf 'Environment: %s\n' "$ENV_NOTE"
cat <<EOF
$CHECKS_LINE
$GIT_LINE
$OUTPUT
End your final chat message with \`STATUS: PASS|FAIL|BLOCKED\` and \`REPORT: $REPORT\`. The report is authoritative.
Do not edit the global scratchpad or Obsidian. Do not delegate to other Herdr agents. You may use internal subagents for focused analysis only.

---

EOF
if [ -n "$NOTES" ]; then
  printf '## Orchestrator notes\n\n'; cat "$NOTES"; printf '\n---\n\n'
fi
if [ -n "$VAULT" ]; then
  printf '## Vault excerpts (quoted by the orchestrator)\n\n'; cat "$VAULT"; printf '\n---\n\n'
fi
required 'Decisions recorded for this plan' 2
required 'Global Constraints' 2
required 'Review Focus' 2
required 'Worker environment' 2
if [ -n "$CONTRACTS" ]; then
  OLD_IFS=$IFS; IFS=','
  for c in $CONTRACTS; do
    c=$(printf '%s' "$c" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    is_none "$c" || required "$c" 2
  done
  IFS=$OLD_IFS
fi
printf -- '---\n\n## Your task (verbatim from the plan)\n\n%s\n' "$TASK_TEXT"
} > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
chmod 600 "$OUT"
printf '%s (%s lines)\n' "$OUT" "$(wc -l < "$OUT" | tr -d ' ')"
