#!/usr/bin/env bash
# Checks that every non-blank line of an old file still exists, unchanged, in
# the new files, as many times as it appeared in the old file, or in the
# allowlist (the old lines a plan told us to change).
#
#   check-moved-text.sh --old <rev>:<path> --allow <file> <new-file>...
#
# Prints "missing: <line>" for each old line found in none of them and exits 1
# if there is any. New files and the allowlist are paths relative to the
# current directory (run it from the repo root).
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
usage() { printf 'usage: check-moved-text.sh --old <rev>:<path> --allow <file> <new-file>...\n' >&2; exit 1; }

old= allow=
while [ $# -gt 0 ]; do
  case $1 in
    --old) [ $# -ge 2 ] || usage; old=$2; shift 2 ;;
    --allow) [ $# -ge 2 ] || usage; allow=$2; shift 2 ;;
    --) shift; break ;;
    -*) usage ;;
    *) break ;;
  esac
done
[ -n "$old" ] && [ -n "$allow" ] && [ $# -ge 1 ] || usage

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
git -C "$ROOT" show "$old" > "$WORK/old" 2> "$WORK/err" || { printf 'cannot read %s: %s\n' "$old" "$(cat "$WORK/err")" >&2; exit 1; }
[ -f "$allow" ] || { printf 'allowlist not found: %s\n' "$allow" >&2; exit 1; }
for f in "$@"; do
  [ -f "$f" ] || { printf 'new file not found: %s\n' "$f" >&2; exit 1; }
done
{ cat "$allow"; printf '\n'; } > "$WORK/allow"
for f in "$@"; do cat "$f"; printf '\n'; done > "$WORK/new"

# An old line is accepted when it is allowlisted or when the new files hold it at
# least as many times as the old file did. Blank lines are skipped.
awk '
  FNR == 1 { file++ }
  file == 1 { allowed[$0] = 1; next }
  file == 2 { have[$0]++; next }
  $0 !~ /[^[:space:]]/ { next }
  { seen[$0]++ }
  !($0 in allowed) && seen[$0] > have[$0] { print "missing: " $0; bad = 1 }
  END { exit bad }
' "$WORK/allow" "$WORK/new" "$WORK/old"
