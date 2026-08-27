#!/usr/bin/env bash
# Prints the CHANGELOG.md section for the topmost `## x.y.z` heading — i.e.
# the most recently added version, since entries are newest-first.
#
# Used by .github/workflows/release.yml to fill in GitHub Release notes
# without duplicating them by hand. Pure awk so it behaves the same under
# BSD awk (macOS, for local testing) and GNU awk (the Ubuntu Actions runner).
set -euo pipefail

cd "$(dirname "$0")/.."

awk '
  /^## / { if (found) exit; found = 1; next }
  found {
    lines[NR] = $0
    if ($0 != "") last = NR
    if (first == 0 && $0 != "") first = NR
  }
  END {
    for (i = first; i <= last; i++) print lines[i]
  }
' CHANGELOG.md
