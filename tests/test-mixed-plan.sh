#!/usr/bin/env bash
# End-to-end check: a plan written by following writing-herdr-plans for a repo
# audit (findings tasks, a consolidation document task, a cross-cutting review,
# reserved fix slots) passes the skill's self-review checks, and the scripts of
# executing-herdr-plans build every package the plan needs.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
PKG_SCRIPT="$ROOT/executing-herdr-plans/scripts/make-package.sh"
REV_SCRIPT="$ROOT/executing-herdr-plans/scripts/make-review-package.sh"
PLAN="$HERE/fixtures/mixed-plan.md"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail=0
pass() { printf 'ok %s\n' "$1"; }
bad() { printf 'FAIL %s: %s\n' "$1" "$2"; fail=1; }

# gq: grep without -q, so a pipeline writer never dies of SIGPIPE under pipefail.
gq() { grep "$@" >/dev/null; }

# check <name> <failure message> <command...>: ok when the command succeeds.
check() {
  name=$1; msg=$2; shift 2
  if "$@"; then pass "$name"; else bad "$name" "$msg"; fi
}

[ -f "$PLAN" ] || { bad plan_exists "missing $PLAN"; exit 1; }

# ---- Self-review greps (writing-herdr-plans: Self-Review Additions, kinds/*.md) ----

# One line per task: "<ID>|<header line>", the header being the first non-blank
# line under the "### Task T-0NN:" heading. Reserved-slot headings ("### Tasks")
# are not tasks.
task_headers() {
  awk '
    /^### Task T-[0-9]+:/ { id = $3; sub(/:$/, "", id); want = 1; next }
    want && NF { print id "|" $0; want = 0 }
  ' "$PLAN"
}
task_ids() { task_headers | cut -d'|' -f1; }
field_of() { task_headers | grep "^$1|" | grep -o "\*\*$2:\*\* [^·]*" | sed -e "s/^\*\*$2:\*\* //" -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
# The Kind of a task, trimmed and lower-cased as make-package.sh reads it.
kind_of() { field_of "$1" Kind | tr 'A-Z' 'a-z'; }
task_text() { sed -n "/^### Task $1:/,/^##/p" "$PLAN" | sed '$d'; }
# The plan's "## " headings, outside code fences.
headings() { awk '/^```/ { f = !f } !f && /^## / { sub(/^## /, ""); print }' "$PLAN"; }

all_kinds_valid() {
  local id k
  for id in $(task_ids); do
    k=$(kind_of "$id")
    case $k in ''|code|findings|document) ;; *) echo "$id has Kind '$k'"; return 1 ;; esac
  done
}
check kinds_valid "a task has a Kind other than code|findings|document" all_kinds_valid

# T-000 is the orchestrator's; every other task states its Kind explicitly.
worker_tasks_have_kind() {
  local id k
  for id in $(task_ids); do
    [ "$(field_of "$id" Model)" = orchestrator ] && continue
    k=$(kind_of "$id")
    case $k in code|findings|document) ;; *) echo "$id has no Kind"; return 1 ;; esac
  done
}
check worker_tasks_have_kind "a worker task has no explicit Kind" worker_tasks_have_kind

t000_is_orchestrators() { [ "$(field_of T-000 Model)" = orchestrator ]; }
check t000_is_orchestrator "T-000 must use Model: orchestrator" t000_is_orchestrators

findings_list_both_contracts() {
  local id n=0
  for id in $(task_ids); do
    [ "$(kind_of "$id")" = findings ] || continue
    n=$((n + 1))
    field_of "$id" Contracts | gq -F 'Findings format' || { echo "$id lacks Findings format"; return 1; }
    field_of "$id" Contracts | gq -F 'Severity scale' || { echo "$id lacks Severity scale"; return 1; }
  done
  [ "$n" -ge 3 ]
}
check findings_list_both_contracts "a findings task misses Findings format or Severity scale (or fewer than 3 findings tasks)" findings_list_both_contracts

contracts_match_headings() {
  local id c
  for id in $(task_ids); do
    field_of "$id" Contracts | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | while read -r c; do
      case $c in ''|none) continue ;; esac
      headings | gq -xF "$c" || { echo "$id: no '## $c' heading"; exit 1; }
    done || return 1
  done
}
check contracts_match_headings "a task lists a contract with no matching heading" contracts_match_headings

one_consolidation_task() {
  local id docs=() deps
  for id in $(task_ids); do [ "$(kind_of "$id")" = document ] && docs+=("$id"); done
  [ "${#docs[@]}" = 1 ] || { echo "document tasks: ${docs[*]:-none}"; return 1; }
  deps=$(field_of "${docs[0]}" 'Depends on')
  for id in $(task_ids); do
    [ "$(kind_of "$id")" = findings ] || continue
    # the cross-cutting review runs after the consolidation, so it is not one of its parts
    field_of "$id" 'Depends on' | gq -F "${docs[0]}" && continue
    printf '%s' "$deps" | gq -F "$id" || { echo "consolidation does not depend on $id"; return 1; }
  done
  task_text "${docs[0]}" | gq -F '**Part:** the whole document'
}
check one_consolidation_task "exactly one document task, depending on every part, writing the whole document" one_consolidation_task

# Closing order: consolidation, then the cross-cutting review, then reserved fixes.
closing_order() {
  local cons review l_cons l_review l_res
  cons=T-003; review=T-004
  [ "$(kind_of $cons)" = document ] && [ "$(kind_of $review)" = findings ] || return 1
  field_of $review 'Depends on' | gq -F "$cons" || return 1
  l_cons=$(grep -n "^### Task $cons:" "$PLAN" | cut -d: -f1)
  l_review=$(grep -n "^### Task $review:" "$PLAN" | cut -d: -f1)
  l_res=$(grep -n '^### Tasks T-005 … T-007: Reserved for fixes from T-001, T-002$' "$PLAN" | cut -d: -f1)
  [ -n "$l_res" ] && [ "$l_cons" -lt "$l_review" ] && [ "$l_review" -lt "$l_res" ]
}
check closing_order "expected T-003 consolidation, T-004 findings review depending on it, then the reserved slots" closing_order

reserved_slots_have_no_header() {
  local after
  after=$(awk '/^### Tasks T-005/ { f = 1; next } f && NF { print; exit }' "$PLAN")
  case $after in '**'*) return 1 ;; esac
  ! task_ids | gq -E '^T-00[567]$'
}
check reserved_slots_are_not_tasks "reserved slots must have no header line and no task heading" reserved_slots_have_no_header

deliverable_decision_to_confirm() {
  awk '/^## Decisions recorded for this plan/ { f = 1; next } /^## / { f = 0 } f' "$PLAN" \
    | grep -i 'deliverable' | gq -F 'to confirm'
}
check deliverable_decision_to_confirm "the deliverable decision must say 'to confirm'" deliverable_decision_to_confirm

permission_mode_to_confirm() {
  awk '/^## Decisions recorded for this plan/ { f = 1; next } /^## / { f = 0 } f' "$PLAN" \
    | grep -i 'permission' | gq -F 'to confirm'
}
check permission_mode_to_confirm "the permission mode decision must say 'to confirm'" permission_mode_to_confirm

fixed_headings_present() {
  local h
  for h in 'Decisions recorded for this plan' 'Global Constraints' 'Review Focus' \
    'Orchestration (orchestrator-only section)' 'Worker environment' 'Tasks' 'Self-review'; do
    [ "$(headings | grep -cxF "$h")" = 1 ] || { echo "heading '$h' not exactly once"; return 1; }
  done
}
check fixed_headings_present "a fixed heading is missing or repeated" fixed_headings_present

# The Self-review section of the plan states these claims; assert them.
review_focus_names_tasks() {
  local items id n=0
  items=$(awk '/^## Review Focus/ { f = 1; next } /^## / { f = 0 } f && /^[0-9]+\./' "$PLAN")
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    n=$((n + 1))
    case $line in *'['T-*']'*) ;; *) echo "no task named: $line"; return 1 ;; esac
    for id in $(printf '%s' "$line" | sed -e 's/^[^[]*\[//' -e 's/\].*//' | tr -d ','); do
      task_ids | gq -xF "$id" || { echo "Review Focus names unknown task $id"; return 1; }
    done
  done <<EOF2
$items
EOF2
  [ "$n" -ge 1 ]
}
check review_focus_names_tasks "a Review Focus item names no task, or a task that does not exist" review_focus_names_tasks

decision_statuses() {
  local d status
  for d in D1 D2 D3 D4; do
    awk -F'|' -v d="$d" '$2 ~ "^ *" d " *$" { print $5 }' "$PLAN" | gq -F 'to confirm' || { echo "$d is not 'to confirm'"; return 1; }
  done
  for d in D5 D6; do
    status=$(awk -F'|' -v d="$d" '$2 ~ "^ *" d " *$" { print $5 }' "$PLAN")
    printf '%s' "$status" | gq -F 'adopted by' || { echo "$d is not routine ('adopted by ...')"; return 1; }
  done
}
check decision_statuses "D1 to D4 must be 'to confirm' and D5, D6 'adopted by ...'" decision_statuses

# T-000 records a baseline for every file a findings task's Verify compares against.
t000_records_baselines() {
  local id b
  for id in $(task_ids); do
    [ "$(kind_of "$id")" = findings ] || continue
    for b in $(task_text "$id" | grep -o 'baseline-[A-Za-z0-9.-]*' | sort -u); do
      task_text T-000 | gq -F "$b" || { echo "T-000 does not record $b ($id)"; return 1; }
    done
  done
}
check t000_records_baselines "a findings task compares against a baseline T-000 does not record" t000_records_baselines

# Findings tasks in one wave examine disjoint scopes: the backticked paths of
# the two Scope lines share no path and none is inside another.
disjoint_scopes() {
  local a b pa pb
  a=$(task_text T-001 | grep '^\*\*Scope:\*\*' | grep -o '`/[^`]*`' | tr -d '`')
  b=$(task_text T-002 | grep '^\*\*Scope:\*\*' | grep -o '`/[^`]*`' | tr -d '`')
  [ -n "$a" ] && [ -n "$b" ] || return 1
  for pa in $a; do for pb in $b; do
    case $pa in "$pb"*) return 1 ;; esac
    case $pb in "$pa"*) return 1 ;; esac
  done; done
}
check disjoint_scopes "T-001 and T-002 scopes overlap or are missing" disjoint_scopes

findings_verify_checks_ids_cells_evidence() {
  local id
  for id in T-001 T-002 T-004; do
    task_text "$id" | gq -F "grep -c '^| $id-F" || return 1
    task_text "$id" | gq -F 'cells ok' || return 1
    task_text "$id" | gq -F "evidence/$id/" || return 1
  done
}
check findings_verify_steps "a findings task's Verify does not check the ID prefix, the cells and the evidence files" findings_verify_checks_ids_cells_evidence

consolidation_html_check() {
  task_text T-003 | gq -F '<script|<link[^>]*href="https?:|src="https?:'
}
check consolidation_html_check "the consolidation's Verify must run the html grep check" consolidation_html_check

no_clickup_in_worker_text() {
  ! { awk '/^## Worker environment/ { f = 1; next } /^## / { f = 0 } f' "$PLAN"; sed -n '/^## Tasks/,/^## Self-review/p' "$PLAN"; } | gq -i clickup
}
check no_clickup_in_worker_text "no task or the Worker environment may mention ClickUp" no_clickup_in_worker_text

no_unfilled_placeholders() {
  # <report-dir> and <run-id> are known only at execution, and F<NN> is the finding number; nothing else may stay as <...> in tasks.
  sed -n '/^## Tasks/,/^## Self-review/p' "$PLAN" | grep -oE '<[A-Za-z][A-Za-z -]*>' | sort -u | grep -vxE '<report-dir>|<run-id>|<NN>' | gq . && return 1
  return 0
}
check no_unfilled_placeholders "a task keeps a <...> placeholder that is not known only at execution" no_unfilled_placeholders

# ---- Packages build for the worker tasks, review packages for T-001 and T-003 ----

REPORTS="$WORK/reports"; mkdir -p "$REPORTS/parts" "$REPORTS/evidence"
build() { # build <task> [args...] -> RC, ERR
  local task=$1; shift
  RC=0
  bash "$PKG_SCRIPT" --plan "$PLAN" --task "$task" --model sonnet --why test --run-id run-1 \
    --reports "$REPORTS" --coord /coord "$@" > "$WORK/stdout" 2> "$WORK/stderr" || RC=$?
  ERR=$(cat "$WORK/stderr")
}
has() { grep -qF -- "$2" "$1"; }
# The package's header block: the lines before the first "---" separator.
pkg_header() { awk '/^---$/ { exit } { print }' "$1"; }

for t in T-001 T-002; do
  build $t; P="$REPORTS/$t.package.md"
  if [ "$RC" = 0 ] && has "$P" 'findings_worker (read-only on sources' && has "$P" "$t-F" \
    && has "$P" "evidence/$t/" && has "$P" '## Findings format' && has "$P" '## Severity scale' \
    && has "$P" '## Decisions recorded for this plan' && has "$P" '## Global Constraints' \
    && has "$P" '## Review Focus' && has "$P" '## Worker environment' && has "$P" "### Task $t:" \
    && ! pkg_header "$P" | gq -iE 'branch|merge-base|worktree'; then pass "package_$t"
  else bad "package_$t" "rc=$RC $ERR"; fi
done

build T-003; P="$REPORTS/T-003.package.md"
if [ "$RC" = 0 ] && has "$P" 'document_worker' && has "$P" 'parts/T-003.md' \
  && has "$P" '## Document outline' && has "$P" '## Style guide' \
  && grep '^Allowed writes:' "$P" | gq -F 'parts/T-003.html' \
  && ! pkg_header "$P" | gq -iE 'branch|merge-base|worktree'; then pass package_T-003
else bad package_T-003 "rc=$RC $ERR"; fi

build T-004; P="$REPORTS/T-004.package.md"
if [ "$RC" = 0 ] && has "$P" 'findings_worker' && has "$P" '### Task T-004:' && ! has "$P" 'Reserved for fixes'; then pass package_T-004
else bad package_T-004 "rc=$RC $ERR"; fi

build T-005
if [ "$RC" = 1 ] && printf '%s' "$ERR" | gq -F "task heading not found: '### Task T-005:'"; then pass reserved_slot_has_no_package
else bad reserved_slot_has_no_package "rc=$RC $ERR"; fi

review() { # review <task> <kind> [args...] -> RC, ERR
  local task=$1 kind=$2; shift 2
  printf 'stub author report\n' > "$REPORTS/$task.md"
  RC=0
  bash "$REV_SCRIPT" --task "$task" --kind "$kind" --model opus --run-id run-1 --reports "$REPORTS" "$@" \
    > "$WORK/stdout" 2> "$WORK/stderr" || RC=$?
  ERR=$(cat "$WORK/stderr")
}

review T-001 findings; P="$REPORTS/T-001.review-package.md"
if [ "$RC" = 0 ] && has "$P" 'confirmed' && has "$P" 'not reproduced' \
  && has "$P" 'plus max(3, ceil(20% of the Minor findings)) Minor findings, or all the Minor findings when there are fewer than 3' \
  && has "$P" 'evidence/T-001-review/' && ! has "$P" 'git -C'; then pass review_package_T-001
else bad review_package_T-001 "rc=$RC $ERR"; fi

mkdir -p "$WORK/integrated"
review T-003 document --integrated "$WORK/integrated"; P="$REPORTS/T-003.review-package.md"
if [ "$RC" = 0 ] && has "$P" 'parts/T-003.md' && has "$P" "$WORK/integrated" && has "$P" 'List each claim without a source' \
  && has "$P" 'Verdict is CHANGES_REQUIRED when a Critical/Important claim has no source, the part would contradict an integrated part, or a section of the outline is missing' \
  && ! has "$P" 'git -C'; then pass review_package_T-003
else bad review_package_T-003 "rc=$RC $ERR"; fi

exit "$fail"
