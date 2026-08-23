#!/usr/bin/env bash
# test-oom-safe-engine-ladder.sh — T1 + D2 (specs 2026-08-02-oom-safe-ast-engine-ladder.md
# + 2026-08-02-reuse-first-grounding-index.md §D2; v7.4.0 Fase 5 №4 removed the
# --engine=tree-sitter opt-in lane entirely).
# Proves the ladder: ast-grep → regex, with tree-sitter not merely un-invoked but
# STRUCTURALLY ABSENT from the resolver (the clang-OOM class cannot exist); forced
# engines halt dep_missing instead of falling through; --engine=tree-sitter is a
# USAGE ERROR (rc 2), never a silent alias; and the doc/consumer wiring is pinned.
# All engine arms run through PATH shims — no real ast-grep needed.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../../.." && pwd)"
PLUG="${ROOT}/plugins/mega-sdd"
PROBE="${PLUG}/scripts/probe-scan-engine.sh"
[ -f "$PROBE" ] || { echo "missing probe-scan-engine.sh"; exit 1; }
FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

# fixture repo + PATH sandbox (python3 + core utils only, no real AST tooling)
mkdir -p "$W/repo" "$W/shim"
printf 'def handle(req):\n    return req\n' > "$W/repo/b.py"
printf 'export function login(u) { return u }\n' > "$W/repo/a.js"
# a PRIVATE python3 bindir — pointing PATH at python3's real dir would leak that
# dir's OTHER binaries (on brew boxes /opt/homebrew/bin also ships the real
# tree-sitter + ast-grep, defeating the sandbox)
mkdir -p "$W/pybin"; ln -s "$(command -v python3)" "$W/pybin/python3"
SANDBOX_PATH="$W/shim:$W/pybin:/usr/bin:/bin"
# the sandbox keeps /usr/bin:/bin for coreutils — if a distro-installed AST
# binary lives THERE (apt can ship tree-sitter-cli), the absence arms are
# unprovable on this box: skip them honestly instead of failing
SANDBOX_CLEAN=1
for b in tree-sitter tree-sitter-cli ast-grep; do
  PATH="/usr/bin:/bin" command -v "$b" >/dev/null 2>&1 && SANDBOX_CLEAN=0
done

jq_get() { python3 -c "import json,sys; d=json.load(sys.stdin); print(d$1)"; }
run_probe() { PATH="$SANDBOX_PATH" bash "$PROBE" "$@" 2>/dev/null; }

mk_astgrep() { # a fake tier-2 binary that answers --version
  printf '#!/bin/sh\n[ "$1" = "--version" ] && { echo "ast-grep 0.42.3"; exit 0; }\nexit 0\n' > "$W/shim/ast-grep"
  chmod +x "$W/shim/ast-grep"
}
rm_shims() { rm -f "$W/shim/ast-grep" "$W/shim/tree-sitter" "$W/shim/tree-sitter-cli"; }

echo "== forced engines: dep_missing halts, never silent fall-through =="
rm_shims
if [ "$SANDBOX_CLEAN" = "0" ]; then
  ok "(absence arms skipped — a real AST binary lives in /usr/bin:/bin on this box)"
fi
# v7.4.0: --engine=tree-sitter is a USAGE error, not an engine — on every box
run_probe --cwd="$W/repo" --engine=tree-sitter --lang=python:b.py >/dev/null 2>&1; RC=$?
[ "$RC" = "2" ] && ok "--engine=tree-sitter -> rc 2 usage (the lane is REMOVED, never silently aliased)" \
  || fail "--engine=tree-sitter accepted (rc=$RC) — the removed lane leaked back"
if [ "$SANDBOX_CLEAN" = "1" ]; then
OUT=$(run_probe --cwd="$W/repo" --engine=ast-grep --lang=python:b.py); RC=$?
[ "$RC" = "3" ] && printf '%s' "$OUT" | grep -q '"required_binary":"ast-grep"' \
  && ok "forced ast-grep absent -> rc 3 dep_missing(ast-grep) — parity, no silent regex" \
  || fail "forced ast-grep arm: rc=$RC out=$OUT"
fi
OUT=$(run_probe --cwd="$W/repo" --engine=regex --lang=python:b.py); RC=$?
[ "$RC" = "0" ] && printf '%s' "$OUT" | grep -q '"engine":"regex"' \
  && ok "forced regex -> rc 0, engine regex" || fail "forced regex arm: rc=$RC out=$OUT"

# (The clang-OOM / probe_timeout / serial-lock arms died with the tree-sitter
# smoke-test lane in v7.4.0 — no grammar compile step exists to classify.)

echo "== ladder resolution arms =="
if [ "$SANDBOX_CLEAN" = "1" ]; then
rm_shims  # nothing installed at all
OUT=$(run_probe --cwd="$W/repo" --lang=python:b.py)
printf '%s' "$OUT" | grep -q '"engine":"regex"' && printf '%s' "$OUT" | grep -q '"reason":"astgrep_absent"' \
  && ok "no ast-grep -> regex with the astgrep_absent reason (D2 auto)" || fail "bare arm: $OUT"
mk_astgrep  # ast-grep only (the locked-down-laptop shape: scoop static binary, no cargo/brew)
OUT=$(run_probe --cwd="$W/repo" --lang=python:b.py --lang=javascript:a.js)
printf '%s' "$OUT" | grep -q '"engine":"ast-grep"' \
  && printf '%s' "$OUT" | grep -q '"astgrep_version":"0.42.3"' \
  && ok "D2: ast-grep alone IS tier 1 (engine + version captured)" || fail "ag-only arm: $OUT"
fi
# scaffold-only language: skipped, never failed
OUT=$(run_probe --cwd="$W/repo" --lang=go)
printf '%s' "$OUT" | grep -q '"reason":"no_source_file"' && printf '%s' "$OUT" | grep -q '"engine":"ast-grep"' \
  && ok "scaffold-only lang skipped; the ast-grep claim holds per binary presence (D2)" || fail "scaffold arm: $OUT"

echo "== round regression arms (dual-blind 2026-08-02, folded; retargeted v7.4.0) =="
# B1: non-UTF-8 --version output must not crash the resolver — digest on every path
printf '#!/bin/sh\n[ "$1" = "--version" ] && { head -c 64 /dev/urandom; exit 0; }\nexit 0\n' > "$W/shim/ast-grep"
chmod +x "$W/shim/ast-grep"
OUT=$(run_probe --cwd="$W/repo" --lang=python:b.py); RC=$?
[ "$RC" = "0" ] && printf '%s' "$OUT" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null \
  && ok "B1: raw-bytes --version -> rc 0, valid JSON digest (errors=replace)" \
  || fail "B1: rc=$RC out=$OUT"
# B4: version token = first X.Y match, not the trailing "(sha)"
printf '#!/bin/sh\n[ "$1" = "--version" ] && { echo "ast-grep 0.42.3 (2a835ee029dca1c325e6f1c01dbce40396f6123e)"; exit 0; }\nexit 0\n' > "$W/shim/ast-grep"
chmod +x "$W/shim/ast-grep"
OUT=$(run_probe --cwd="$W/repo" --lang=python:b.py)
printf '%s' "$OUT" | grep -q '"astgrep_version":"0.42.3"' \
  && ok "B4: sha-suffixed --version parses to 0.42.3" || fail "B4: $OUT"
mk_astgrep
# B2: a no-pack language must NOT inflate engine/precision to ast.
# (kotlin gained a pack in the v5.33.0 glossary — fortran stays a real
# ast-grep-supported-nowhere language, so the unpacked lane keeps a live arm.)
printf 'program hello\nend program hello\n' > "$W/repo/h.f90"
OUT=$(run_probe --cwd="$W/repo" --lang=fortran:h.f90)
printf '%s' "$OUT" | grep -q '"engine":"regex"' && printf '%s' "$OUT" | grep -q '"reason":"no_astgrep_pack"' \
  && ok "B2/D2: fortran-only (no pack) -> regex engine + no_astgrep_pack, never a fake ast stamp" \
  || fail "B2: $OUT"
# A5: scaffold skip holds on the tier-2 path too (tree-sitter absent locally is
# emulated by --engine=ast-grep forcing past tier 1)
OUT=$(run_probe --cwd="$W/repo" --engine=ast-grep --lang=go)
printf '%s' "$OUT" | grep -q '"tier":"skipped"' \
  && ok "A5: zero-source language is a SKIP on the non-tier-1 path too" || fail "A5: $OUT"
# B3/B7: malformed inputs are usage errors (rc 2), not tracebacks
run_probe --cwd="$W/repo" --timeout=abc --lang=python:b.py >/dev/null 2>&1; [ "$?" = "2" ] \
  && ok "B3: --timeout=abc -> rc 2 usage" || fail "B3: non-numeric timeout not rejected"
run_probe --cwd="$W/repo" --lang=python: >/dev/null 2>&1; [ "$?" = "2" ] \
  && ok "B7: --lang=python: (empty sample) -> rc 2 usage" || fail "B7: trailing colon accepted"
run_probe --cwd="$W/repo" "--lang=../../x:f" >/dev/null 2>&1; [ "$?" = "2" ] \
  && ok "B8: path-traversal language name rejected" || fail "B8: hostile lang accepted"
# B6: duplicate --lang args deduped in the digest
OUT=$(run_probe --cwd="$W/repo" --engine=ast-grep --lang=python:b.py --lang=python:b.py)
N=$(printf '%s' "$OUT" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['astgrep_langs']))")
[ "$N" = "1" ] && ok "B6: duplicate --lang deduped" || fail "B6: astgrep_langs count=$N"
rm_shims

# v7.4.0: tree-sitter is STRUCTURALLY absent from the resolver — the canary
# shim is obsolete; a static grep is the stronger pin (no code path exists).
if grep -qi "tree.sitter" "$PROBE"; then
  # the only tolerated mention is the removal note in the usage error / comments
  N_BAD=$(grep -ci "tree.sitter" "$PROBE")
  N_NOTE=$(grep -c "removed v7.4.0\|removed in v7" "$PROBE")
  [ "$N_NOTE" -ge 1 ] && [ "$N_BAD" -le 4 ] \
    && ok "D2: probe mentions tree-sitter only in removal notes ($N_BAD mentions, $N_NOTE removal-note lines)" \
    || fail "D2: probe carries tree-sitter code again ($N_BAD mentions)"
else
  ok "D2: probe is tree-sitter-free"
fi
if [ "$SANDBOX_CLEAN" = "1" ]; then
rm -f "$W/shim/ast-grep"
OUT=$(run_probe --cwd="$W/repo" --lang=python:b.py); RC=$?
if [ "$RC" = "0" ] && printf '%s' "$OUT" | grep -q '"reason":"astgrep_absent"'; then
  ok "D2: ag-absent -> regex/astgrep_absent (honest fall, no phantom engine)"
else
  fail "D2 ag-absent arm digest wrong: rc=$RC $OUT"
fi
fi
mk_astgrep

echo "== tier-2 rule packs: present, multi-doc, kind-based =="
PACKS=(typescript tsx javascript php python rust go ruby java csharp \
       kotlin swift scala c cpp dart elixir lua bash haskell)
MISS=0
for L in "${PACKS[@]}"; do
  [ -f "$PLUG/skills/scan-codebase/queries/astgrep/$L.yml" ] || { fail "missing pack $L.yml"; MISS=1; }
done
[ "$MISS" = "0" ] && ok "all ${#PACKS[@]} rule packs shipped (glossary)"
# Lane law (the tsx regression class): tsx has its OWN pack — rules parked in
# typescript.yml are invisible to the filename-derived Step-0 router.
grep -q "language: tsx" "$PLUG/skills/scan-codebase/queries/astgrep/tsx.yml" \
  && ! grep -q "language: tsx" "$PLUG/skills/scan-codebase/queries/astgrep/typescript.yml" \
  && ok "tsx rules live in tsx.yml only (lane law)" || fail "tsx lane law broken"
for L in "${PACKS[@]}"; do
  grep -q "^id: " "$PLUG/skills/scan-codebase/queries/astgrep/$L.yml" && \
  grep -q "kind: " "$PLUG/skills/scan-codebase/queries/astgrep/$L.yml" || fail "pack $L.yml not kind-based"
done
ok "packs are id'd kind-based rules"

echo "== live tier-2 extraction (SKIPPED unless a real ast-grep is installed) =="
if command -v ast-grep >/dev/null 2>&1; then
  N=$(cd "$W/repo" && ast-grep scan --inline-rules "$(awk 'FNR==1 && NR!=1 {print "---"} {print}' "$PLUG"/skills/scan-codebase/queries/astgrep/*.yml)" --json=compact . 2>/dev/null | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
  [ "${N:-0}" -ge 2 ] && ok "one-spawn concatenated-pack scan extracted $N definitions (js+py fixtures)" \
    || fail "live extraction found $N (<2)"
else
  ok "(skipped — ast-grep not on this runner; shim arms above cover the ladder)"
fi

echo "== doc + consumer wiring pins =="
grep -q "probe-scan-engine.sh" "$PLUG/skills/scan-codebase/SKILL.md" \
  && ok "SKILL Step 0 routes through the probe script" || fail "SKILL Step 0 not wired"
SP="$PLUG/skills/scan-codebase/references/scan-procedure.md"
grep -qF 'If `engine: ast-grep`' "$SP" && grep -qF '0-BASED' "$SP" \
  && grep -qF "(file, range.start.line, ruleId)" "$SP" \
  && ok "scan-procedure tier-2 lane: 0-based + dedupe contract stated" || fail "tier-2 lane contract missing"
grep -qF "FNR==1 && NR!=1" "$SP" \
  && ok "the ---separator concatenation seam is written down" || fail "concat seam missing"
grep -qF "ONE total" "$SP" && ok "spawn table carries the ast-grep row" || fail "spawn row missing"
if [ -e "$PLUG/skills/scan-codebase/references/tree-sitter-integration.md" ]; then
  fail "tree-sitter-integration.md is back (removed v7.4.0 with its lane)"
else
  ok "tree-sitter-integration.md stays removed (v7.4.0)"
fi
grep -qE '^type: dep_missing$' "$PLUG/skills/scan-codebase/references/halts-flags-handoff.md" \
  && ok "dep_missing YAML shape lives in halts-flags-handoff.md (v7.4.0 home; fork test pins the pointer)" || fail "dep_missing shape missing from its v7.4.0 home"
grep -qF "engine: ast-grep | regex" "$PLUG/skills/scan-codebase/references/codebase-map-schema.md" \
  && grep -qF "astgrep_version" "$PLUG/skills/scan-codebase/references/codebase-map-schema.md" \
  && ok "map schema enum (2-rung) + astgrep_version" || fail "schema not updated"
grep -qF '"astgrep_version"' "$PLUG/scripts/derive-codebase-map.sh" \
  && ok "deriver FM_ORDER accepts astgrep_version" || fail "deriver FM_ORDER missing key"
if [ -e "$PLUG/skills/generate-units/references/pagerank-targeting.md" ]; then
  fail "pagerank-targeting.md resurrected (removed 5.29.0 §D1)"
else
  ok "D1: pagerank-targeting.md stays removed; reuse rides the dispatch symbol_slice"
fi
grep -qF "ast-grep 0.42.3" "$PLUG/skills/scan-codebase/queries/VERSIONS.md" \
  && ok "VERSIONS.md pins the tested ast-grep" || fail "VERSIONS pin missing"

[ "$FAILED" = "0" ] && echo "ALL OOM-SAFE-LADDER PROOFS OK" || echo "OOM-safe-ladder proofs FAILED"
exit $FAILED
