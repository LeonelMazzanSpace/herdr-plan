#!/usr/bin/env bash
# Tests for tests/check-moved-text.sh.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
SCRIPT="$HERE/check-moved-text.sh"
OLD=759fd7a:writing-herdr-plans/SKILL.md

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
git -C "$ROOT" show "$OLD" > "$WORK/full.md"

fail=0
pass() { printf 'ok %s\n' "$1"; }
bad() { printf 'FAIL %s: %s\n' "$1" "$2"; fail=1; }

# Runs the script. Sets RC, OUT.
check() {
  RC=0
  OUT=$(bash "$SCRIPT" "$@" 2>&1) || RC=$?
}

: > "$WORK/empty.txt"
LINE='- **Test isolation per worker.**'
grep -vF -- "$LINE" "$WORK/full.md" > "$WORK/less.md"
grep -F -- "$LINE" "$WORK/full.md" > "$WORK/line.txt"

check --old "$OLD" --allow "$WORK/empty.txt" "$WORK/full.md"
if [ "$RC" = 0 ] && [ -z "$OUT" ]; then pass check_identical_copy_passes
else bad check_identical_copy_passes "rc=$RC out=$OUT"; fi

check --old "$OLD" --allow "$WORK/empty.txt" "$WORK/less.md"
if [ "$RC" = 1 ] && printf '%s' "$OUT" | grep -qF -- 'missing: - **Test isolation per worker.**'; then pass check_removed_line_reported
else bad check_removed_line_reported "rc=$RC out=$OUT"; fi

check --old "$OLD" --allow "$WORK/line.txt" "$WORK/less.md"
if [ "$RC" = 0 ]; then pass check_allowlisted_line_accepted
else bad check_allowlisted_line_accepted "rc=$RC out=$OUT"; fi

# The same text split across two files counts as present.
grep -F -- "$LINE" "$WORK/full.md" > "$WORK/moved.md"
check --old "$OLD" --allow "$WORK/empty.txt" "$WORK/less.md" "$WORK/moved.md"
if [ "$RC" = 0 ]; then pass check_line_moved_to_second_file
else bad check_line_moved_to_second_file "rc=$RC out=$OUT"; fi

# A reworded line is not the old line.
sed 's/Test isolation per worker/Test isolation per worker (reworded)/' "$WORK/full.md" > "$WORK/reworded.md"
check --old "$OLD" --allow "$WORK/empty.txt" "$WORK/reworded.md"
if [ "$RC" = 1 ] && printf '%s' "$OUT" | grep -qF -- 'missing:'; then pass check_reworded_line_reported
else bad check_reworded_line_reported "rc=$RC out=$OUT"; fi

# A line that appears twice in the old file must appear twice in the new files.
DUP='|---|---|'
awk -v dup="$DUP" '$0 == dup && !skipped { skipped = 1; next } { print }' "$WORK/full.md" > "$WORK/once.md"
check --old "$OLD" --allow "$WORK/empty.txt" "$WORK/once.md"
if [ "$RC" = 1 ] && printf '%s' "$OUT" | grep -qF -- "missing: $DUP"; then pass check_repeated_line_needs_every_occurrence
else bad check_repeated_line_needs_every_occurrence "rc=$RC out=$OUT"; fi

# Two files holding one occurrence each count as two.
printf '%s\n' "$DUP" > "$WORK/dup.md"
check --old "$OLD" --allow "$WORK/empty.txt" "$WORK/once.md" "$WORK/dup.md"
if [ "$RC" = 0 ]; then pass check_repeated_line_counted_across_files
else bad check_repeated_line_counted_across_files "rc=$RC out=$OUT"; fi

# An allowlisted line is accepted whatever its count.
printf '%s\n' "$DUP" > "$WORK/dup.txt"
check --old "$OLD" --allow "$WORK/dup.txt" "$WORK/once.md"
if [ "$RC" = 0 ]; then pass check_repeated_allowlisted_line_accepted
else bad check_repeated_allowlisted_line_accepted "rc=$RC out=$OUT"; fi

check --old "$OLD" "$WORK/full.md"
if [ "$RC" = 1 ] && printf '%s' "$OUT" | grep -qF -- 'usage'; then pass check_usage_without_allow
else bad check_usage_without_allow "rc=$RC out=$OUT"; fi

exit "$fail"
