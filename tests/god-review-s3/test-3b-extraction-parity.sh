#!/usr/bin/env bash
# test-3b-extraction-parity.sh — god-review stage 3, Batch 3B.
#
# 9.0 P1: the scan-first classic spine (the scan-codebase skill) was removed
# (docs/superpowers/specs/2026-09-27-v9-simplification-design.md §2/§3). Every
# pin below that read that skill's surface-scan procedure is RETIRED with it:
#   ECO-1  .NET route/model rows + the Step 6/7 parity-rail fallbacks
#   ECO-2  C# / Kotlin / F# regex-fallback rows
#   SP-1   widened per-language regex rows (+ the r2 grep -E \w guard)
#   SP-5   meta-framework-before-substrate order in the Step 8.5 table
#   V8     tree-sitter-integration.md absence under the removed skill dir
#          (vacuous now: the whole skill directory is gone by design)
# The surviving symbol extractor is GROUND's ast-grep pack
# (assets/astgrep-queries/astgrep/*.yml via build-symbol-index.sh), whose
# glossary is pinned by tests/scan/test-astgrep-pack-glossary.sh.
#
# What survives here:
#   V8     the tree-sitter opt-in lane (tags-*.scm) stays removed from the
#          surviving assets/astgrep-queries/ directory (removed v7.4.0).
#
# Run: bash tests/god-review-s3/test-3b-extraction-parity.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
VM="${ROOT}/plugins/mega-sdd/assets/astgrep-queries/VERSIONS.md"
for f in "$VM"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

note "== 3B: extraction assets (9.0 survivors) =="

# ── V8 (v7.4.0 form): the tree-sitter lane stays removed ──
if ls "$ROOT/plugins/mega-sdd/assets/astgrep-queries/"tags-*.scm >/dev/null 2>&1; then
  fail "V8: tags-*.scm query files are back (tree-sitter lane removed v7.4.0)"
else
  ok "V8: no tags-*.scm query files (tree-sitter lane stays removed)"
fi

if [ "$FAILED" -eq 0 ]; then note "ALL 3B OK"; else note "3B had failures"; fi
exit $FAILED
