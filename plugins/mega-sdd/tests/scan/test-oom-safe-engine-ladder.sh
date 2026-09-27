#!/usr/bin/env bash
# test-oom-safe-engine-ladder.sh — T1 + D2 (specs 2026-08-02-oom-safe-ast-engine-ladder.md
# + 2026-08-02-reuse-first-grounding-index.md §D2; v7.4.0 Fase 5 №4 removed the
# --engine=tree-sitter opt-in lane entirely).
# 9.0 P1b deleted the ladder's resolver (scripts/probe-scan-engine.sh, whose only
# executor was the removed scan-codebase Step 0) and the map deriver
# (scripts/derive-codebase-map.sh). The resolver arms (forced engines, ladder
# resolution, B1-B8, A5, the D2 tree-sitter-free grep) retired with them. What
# stays pinned is the substrate the survivors consume: the tier-2 rule packs
# (build-symbol-index.sh and _lib/code_enum.py), the live concatenated-pack
# extraction that IS the symbol-index pass, the removed-lane absence pins, and
# the tested ast-grep version.
# CI-safe: bash + python3; the live arm self-skips without a real ast-grep.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../../.." && pwd)"
PLUG="${ROOT}/plugins/mega-sdd"
FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

# fixture repo for the live extraction arm (one js + one py definition)
mkdir -p "$W/repo"
printf 'def handle(req):\n    return req\n' > "$W/repo/b.py"
printf 'export function login(u) { return u }\n' > "$W/repo/a.js"

echo "== tier-2 rule packs: present, multi-doc, kind-based =="
PACKS=(typescript tsx javascript php python rust go ruby java csharp \
       kotlin swift scala c cpp dart elixir lua bash haskell)
MISS=0
for L in "${PACKS[@]}"; do
  [ -f "$PLUG/assets/astgrep-queries/astgrep/$L.yml" ] || { fail "missing pack $L.yml"; MISS=1; }
done
[ "$MISS" = "0" ] && ok "all ${#PACKS[@]} rule packs shipped (glossary)"
# Lane law (the tsx regression class): tsx has its OWN pack — ast-grep treats tsx
# as its own language, so rules parked in typescript.yml never match a .tsx file.
grep -q "language: tsx" "$PLUG/assets/astgrep-queries/astgrep/tsx.yml" \
  && ! grep -q "language: tsx" "$PLUG/assets/astgrep-queries/astgrep/typescript.yml" \
  && ok "tsx rules live in tsx.yml only (lane law)" || fail "tsx lane law broken"
for L in "${PACKS[@]}"; do
  grep -q "^id: " "$PLUG/assets/astgrep-queries/astgrep/$L.yml" && \
  grep -q "kind: " "$PLUG/assets/astgrep-queries/astgrep/$L.yml" || fail "pack $L.yml not kind-based"
done
ok "packs are id'd kind-based rules"

echo "== live tier-2 extraction (SKIPPED unless a real ast-grep is installed) =="
if command -v ast-grep >/dev/null 2>&1; then
  N=$(cd "$W/repo" && ast-grep scan --inline-rules "$(awk 'FNR==1 && NR!=1 {print "---"} {print}' "$PLUG"/assets/astgrep-queries/astgrep/*.yml)" --json=compact . 2>/dev/null | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
  [ "${N:-0}" -ge 2 ] && ok "one-spawn concatenated-pack scan extracted $N definitions (js+py fixtures)" \
    || fail "live extraction found $N (<2)"
else
  ok "(skipped — ast-grep not on this runner; the structural pack pins above hold)"
fi

echo "== removed-lane absence + version pins =="
# 9.0 P1 removed the scan-codebase skill (and its consumer pins); 9.0 P1b removed
# the probe and the deriver. The absence pins below outlive both.
if [ -e "$PLUG/skills/scan-codebase/references/tree-sitter-integration.md" ]; then
  fail "tree-sitter-integration.md is back (removed v7.4.0 with its lane)"
else
  ok "tree-sitter-integration.md stays removed (v7.4.0)"
fi
if [ -e "$PLUG/skills/generate-units/references/pagerank-targeting.md" ]; then
  fail "pagerank-targeting.md resurrected (removed 5.29.0 §D1)"
else
  ok "D1: pagerank-targeting.md stays removed; reuse rides the dispatch symbol_slice"
fi
grep -qF "ast-grep 0.42.3" "$PLUG/assets/astgrep-queries/VERSIONS.md" \
  && ok "VERSIONS.md pins the tested ast-grep" || fail "VERSIONS pin missing"

[ "$FAILED" = "0" ] && echo "ALL OOM-SAFE-LADDER PROOFS OK" || echo "OOM-safe-ladder proofs FAILED"
exit $FAILED
