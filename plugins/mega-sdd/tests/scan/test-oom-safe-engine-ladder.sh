#!/usr/bin/env bash
# test-oom-safe-engine-ladder.sh — T1 (spec 2026-08-02-oom-safe-ast-engine-ladder.md).
# Proves the 3-tier ladder: probe-scan-engine.sh resolves tree-sitter → ast-grep →
# regex deterministically, SERIALLY, bounded, with the clang-OOM class named
# (`grammar_compile_killed` — BOTH spellings: stderr "Killed: 9" at rc=1, and the
# probe itself SIGKILLed), forced engines halt dep_missing instead of falling
# through, and the doc/consumer wiring is pinned. All engine arms run through PATH
# shims — no real tree-sitter/ast-grep needed (CI runners ship neither).
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
if [ "$SANDBOX_CLEAN" = "1" ]; then
OUT=$(run_probe --cwd="$W/repo" --engine=tree-sitter --lang=python:b.py); RC=$?
[ "$RC" = "3" ] && printf '%s' "$OUT" | grep -q '"required_binary":"tree-sitter"' \
  && ok "forced tree-sitter absent -> rc 3 dep_missing(tree-sitter)" \
  || fail "forced tree-sitter arm: rc=$RC out=$OUT"
OUT=$(run_probe --cwd="$W/repo" --engine=ast-grep --lang=python:b.py); RC=$?
[ "$RC" = "3" ] && printf '%s' "$OUT" | grep -q '"required_binary":"ast-grep"' \
  && ok "forced ast-grep absent -> rc 3 dep_missing(ast-grep) — parity, no silent regex" \
  || fail "forced ast-grep arm: rc=$RC out=$OUT"
fi
OUT=$(run_probe --cwd="$W/repo" --engine=regex --lang=python:b.py); RC=$?
[ "$RC" = "0" ] && printf '%s' "$OUT" | grep -q '"engine":"regex"' \
  && ok "forced regex -> rc 0, engine regex" || fail "forced regex arm: rc=$RC out=$OUT"

echo "== the clang-OOM class is NAMED, both spellings =="
# spelling 1 (the live 2026-08-02 incident): tree-sitter exits rc=1 with the
# OOM-killed clang child's "Killed: 9" on stderr
cat > "$W/shim/tree-sitter" <<'SH'
#!/bin/sh
[ "$1" = "--version" ] && { echo "tree-sitter 0.26.9"; exit 0; }
echo "Error: Failed to load language for file name b.py:" >&2
echo "Parser compilation failed." >&2
echo "clang: error: unable to execute command: Killed: 9" >&2
exit 1
SH
chmod +x "$W/shim/tree-sitter"; mk_astgrep
OUT=$(run_probe --cwd="$W/repo" --lang=python:b.py)
printf '%s' "$OUT" | grep -q '"reason":"grammar_compile_killed"' \
  && ok "rc=1 + stderr 'Killed: 9' classified grammar_compile_killed (live-incident spelling)" \
  || fail "stderr spelling not classified: $OUT"
printf '%s' "$OUT" | grep -q '"engine":"ast-grep"' && printf '%s' "$OUT" | grep -q '"precision_tier":"ast"' \
  && ok "OOM-killed grammar falls to tier 2 with precision_tier ast intact" \
  || fail "tier-2 fall wrong: $OUT"
# spelling 2: the probe process itself SIGKILLed
cat > "$W/shim/tree-sitter" <<'SH'
#!/bin/sh
[ "$1" = "--version" ] && { echo "tree-sitter 0.26.9"; exit 0; }
kill -9 $$
SH
chmod +x "$W/shim/tree-sitter"
OUT=$(run_probe --cwd="$W/repo" --lang=python:b.py)
printf '%s' "$OUT" | grep -q '"reason":"grammar_compile_killed"' \
  && ok "probe SIGKILLed (rc -9/137) classified grammar_compile_killed" \
  || fail "sigkill spelling not classified: $OUT"

echo "== bounded probes: a hung compile becomes probe_timeout, not a hang =="
cat > "$W/shim/tree-sitter" <<'SH'
#!/bin/sh
[ "$1" = "--version" ] && { echo "tree-sitter 0.26.9"; exit 0; }
sleep 30
SH
chmod +x "$W/shim/tree-sitter"
START=$(date +%s)
OUT=$(run_probe --cwd="$W/repo" --timeout=1 --lang=python:b.py)
ELAPSED=$(( $(date +%s) - START ))
printf '%s' "$OUT" | grep -q '"reason":"probe_timeout"' \
  && ok "hung probe -> probe_timeout (reachable, recorded)" || fail "timeout arm: $OUT"
[ "$ELAPSED" -lt 15 ] && ok "probe bounded (${ELAPSED}s wall for a 30s hang)" \
  || fail "probe not bounded: ${ELAPSED}s"

echo "== serial by construction: concurrent smoke probes would trip the lock =="
cat > "$W/shim/tree-sitter" <<SH
#!/bin/sh
[ "\$1" = "--version" ] && { echo "tree-sitter 0.26.9"; exit 0; }
mkdir "$W/probe.lock" 2>/dev/null || exit 99   # a second in-flight probe -> rc 99
sleep 0.3
rmdir "$W/probe.lock"
exit 0
SH
chmod +x "$W/shim/tree-sitter"
OUT=$(run_probe --cwd="$W/repo" --lang=python:b.py --lang=javascript:a.js)
if printf '%s' "$OUT" | grep -q 'query_error'; then
  fail "probes overlapped (lock tripped rc 99): $OUT"
else
  printf '%s' "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert sorted(d['grammars_used'])==['javascript','python'], d; print('ok')" >/dev/null 2>&1 \
    && ok "two-language smoke test ran serially (no lock trip, both passed)" \
    || fail "serial arm digest wrong: $OUT"
fi

echo "== ladder resolution arms =="
if [ "$SANDBOX_CLEAN" = "1" ]; then
rm_shims  # nothing installed at all
OUT=$(run_probe --cwd="$W/repo" --lang=python:b.py)
printf '%s' "$OUT" | grep -q '"engine":"regex"' && printf '%s' "$OUT" | grep -q '"precision_tier":"regex"' \
  && ok "no AST binary at all -> tier 3 regex" || fail "bare arm: $OUT"
mk_astgrep  # ast-grep only (the locked-down-laptop shape: scoop static binary, no cargo/brew)
OUT=$(run_probe --cwd="$W/repo" --lang=python:b.py --lang=javascript:a.js)
printf '%s' "$OUT" | grep -q '"engine":"ast-grep"' \
  && printf '%s' "$OUT" | grep -q '"astgrep_version":"0.42.3"' \
  && ok "ast-grep only -> tier 2 engine with version captured" || fail "ag-only arm: $OUT"
fi
# scaffold-only language: skipped, never failed
cat > "$W/shim/tree-sitter" <<'SH'
#!/bin/sh
[ "$1" = "--version" ] && { echo "tree-sitter 0.26.9"; exit 0; }
exit 0
SH
chmod +x "$W/shim/tree-sitter"
OUT=$(run_probe --cwd="$W/repo" --lang=go)
printf '%s' "$OUT" | grep -q '"reason":"no_source_file"' && printf '%s' "$OUT" | grep -q '"engine":"tree-sitter"' \
  && ok "scaffold-only lang skipped; engine kept per binary presence" || fail "scaffold arm: $OUT"

echo "== round regression arms (dual-blind 2026-08-02, all folded) =="
# B1: non-UTF-8 probe output must not crash the resolver — digest on every path
cat > "$W/shim/tree-sitter" <<'SH'
#!/bin/sh
[ "$1" = "--version" ] && { echo "tree-sitter 0.26.9"; exit 0; }
head -c 64 /dev/urandom >&2
exit 1
SH
chmod +x "$W/shim/tree-sitter"; mk_astgrep
OUT=$(run_probe --cwd="$W/repo" --lang=python:b.py); RC=$?
[ "$RC" = "0" ] && printf '%s' "$OUT" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null \
  && ok "B1: raw-bytes stderr -> rc 0, valid JSON digest (errors=replace)" \
  || fail "B1: rc=$RC out=$OUT"
# B4: version token = first X.Y match, not the trailing "(sha)"
cat > "$W/shim/tree-sitter" <<'SH'
#!/bin/sh
[ "$1" = "--version" ] && { echo "tree-sitter 0.25.4 (2a835ee029dca1c325e6f1c01dbce40396f6123e)"; exit 0; }
exit 0
SH
chmod +x "$W/shim/tree-sitter"
OUT=$(run_probe --cwd="$W/repo" --lang=python:b.py)
printf '%s' "$OUT" | grep -q '"tree_sitter_version":"0.25.4"' \
  && ok "B4: sha-suffixed --version parses to 0.25.4" || fail "B4: $OUT"
# B2: a no_query_file language must NOT inflate engine/precision to ast
printf 'fun main() {}\n' > "$W/repo/k.kt"
OUT=$(run_probe --cwd="$W/repo" --lang=kotlin:k.kt)
printf '%s' "$OUT" | grep -q '"engine":"regex"' && printf '%s' "$OUT" | grep -q '"reason":"no_query_file"' \
  && ok "B2: kotlin-only (no .scm, no pack) -> regex engine, never a fake ast stamp" \
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

echo "== tier-2 rule packs: present, multi-doc, kind-based =="
PACKS=(typescript javascript php python rust go ruby java csharp)
MISS=0
for L in "${PACKS[@]}"; do
  [ -f "$PLUG/skills/scan-codebase/queries/astgrep/$L.yml" ] || { fail "missing pack $L.yml"; MISS=1; }
done
[ "$MISS" = "0" ] && ok "all 9 rule packs shipped"
grep -q "language: tsx" "$PLUG/skills/scan-codebase/queries/astgrep/typescript.yml" \
  && ok "typescript pack covers tsx (its own ast-grep language)" || fail "tsx rules missing"
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
TI="$PLUG/skills/scan-codebase/references/tree-sitter-integration.md"
grep -qF "The 3-tier ladder" "$TI" && grep -qF "grammar_compile_killed" "$TI" \
  && ok "tree-sitter-integration owns the ladder + names the OOM class" || fail "ladder owner missing"
grep -qE '^\s*type: dep_missing$' "$TI" \
  && ok "dep_missing YAML shape intact (fork test pins it)" || fail "dep_missing shape broken"
grep -qF "engine: tree-sitter | ast-grep | regex" "$PLUG/skills/scan-codebase/references/codebase-map-schema.md" \
  && grep -qF "astgrep_version" "$PLUG/skills/scan-codebase/references/codebase-map-schema.md" \
  && ok "map schema enum + astgrep_version" || fail "schema not updated"
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
