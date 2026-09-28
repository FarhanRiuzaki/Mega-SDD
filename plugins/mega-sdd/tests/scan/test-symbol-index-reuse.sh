#!/usr/bin/env bash
# test-symbol-index-reuse.sh — tranche R1 (spec
# 2026-08-02-reuse-first-grounding-index.md).
# R1: build-symbol-index.sh (script-owned, deterministic, bounded, honest rc 3)
#     + query-symbol-index.sh (pure read; CI-safe via a hand-written index).
# R2 (the dispatch builder's `symbol_slice`) was removed with the builder in P3;
#     pre-flight item 5 (the index feeds the JIT bind) is pinned below.
# Live ast-grep arms self-skip on runners without the binary.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../../.." && pwd)"
PLUG="${ROOT}/plugins/mega-sdd"
BUILD="${PLUG}/scripts/build-symbol-index.sh"
QUERY="${PLUG}/scripts/query-symbol-index.sh"
for f in "$BUILD" "$QUERY"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done
FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

echo "== R1 builder: usage + honest dep rc =="
bash "$BUILD" --cwd=/nonexistent-dir-xyz >/dev/null 2>&1; [ "$?" = "2" ] \
  && ok "bad --cwd -> rc 2" || fail "bad cwd rc"
bash "$BUILD" --cwd="$W" --timeout=abc >/dev/null 2>&1; [ "$?" = "2" ] \
  && ok "non-numeric --timeout -> rc 2" || fail "timeout validation"
# ast-grep-ABSENT arm via PATH shim sandbox (private pybin — real tool dirs excluded)
mkdir -p "$W/pybin"; ln -s "$(command -v python3)" "$W/pybin/python3"
if ! PATH="/usr/bin:/bin" command -v ast-grep >/dev/null 2>&1; then
  OUT=$(PATH="$W/pybin:/usr/bin:/bin" bash "$BUILD" --cwd="$W" 2>&1); RC=$?
  [ "$RC" = "3" ] && printf '%s' "$OUT" | grep -q "ast-grep not installed" \
    && ok "ast-grep absent -> rc 3, one-line honest reason (never a fake index)" \
    || fail "absent arm: rc=$RC out=$OUT"
else
  ok "(absent arm skipped — ast-grep lives in /usr/bin:/bin here)"
fi

echo "== R1 query: CI-safe against a hand-written index =="
FIX="$W/fixidx"; mkdir -p "$FIX/.mega-sdd/codebase"
cat > "$FIX/.mega-sdd/codebase/symbol-index.json" <<'EOF'
{"generated_by":"mega-sdd:build-symbol-index","generated_at":"2026-08-02T00:00:00Z","head_commit":"abcdef1234567890","astgrep_version":"0.42.3","file_count":2,"symbol_count":3,"symbols":[{"name":"formatCurrency","kind":"php-function","file":"app/Support/Money.php","line":2,"signature":"function formatCurrency(int $cents): string","lang":"php"},{"name":"MoneyBag","kind":"php-class","file":"app/Support/Money.php","line":5,"signature":"class MoneyBag {","lang":"php"},{"name":"login","kind":"javascript-function","file":"src/auth.js","line":1,"signature":"export function login(u) {","lang":"javascript"}]}
EOF
N=$(bash "$QUERY" --cwd="$FIX" --name=currency | wc -l | tr -d ' ')
[ "$N" = "1" ] && ok "--name substring match (case-insensitive)" || fail "name query N=$N"
N=$(bash "$QUERY" --cwd="$FIX" --dir=app/Support | wc -l | tr -d ' ')
[ "$N" = "2" ] && ok "--dir exact-directory match" || fail "dir query N=$N"
N=$(bash "$QUERY" --cwd="$FIX" --dir=app | wc -l | tr -d ' ')
[ "$N" = "2" ] && ok "F4: --dir is a PREFIX (app matches app/Support)" || fail "dir prefix N=$N"
N=$(bash "$QUERY" --cwd="$FIX" --kind=class | wc -l | tr -d ' ')
[ "$N" = "1" ] && ok "--kind substring filter" || fail "kind query N=$N"
N=$(bash "$QUERY" --cwd="$FIX" --limit=2 | wc -l | tr -d ' ')
[ "$N" = "2" ] && ok "--limit caps rows" || fail "limit query N=$N"
bash "$QUERY" --cwd="$W/nowhere-at-all" >/dev/null 2>&1; [ "$?" = "3" ] \
  && ok "missing index -> rc 3 with build pointer" || fail "missing-index rc"
bash "$QUERY" --cwd="$FIX" --name=zzznothing >/dev/null 2>&1; [ "$?" = "0" ] \
  && ok "zero rows is still rc 0 (empty result is an answer)" || fail "zero-row rc"
CFIX="$W/corrupt"; mkdir -p "$CFIX/.mega-sdd/codebase"
printf 'not json at all' > "$CFIX/.mega-sdd/codebase/symbol-index.json"
bash "$QUERY" --cwd="$CFIX" >/dev/null 2>&1; [ "$?" = "3" ] \
  && ok "B6: corrupt index -> rc 3 with rebuild pointer (never a traceback)" || fail "corrupt-index rc"

echo "== R1 live build (skipped without ast-grep) =="
if command -v ast-grep >/dev/null 2>&1; then
  LV="$W/live"; mkdir -p "$LV/app" "$LV/node_modules/dep" "$LV/packages/x/vendor/y"
  printf 'def top(a):\n    return a\n' > "$LV/app/svc.py"
  printf 'def hidden():\n    pass\n' > "$LV/node_modules/dep/d.py"
  printf 'def nested_vendor():\n    pass\n' > "$LV/packages/x/vendor/y/v.py"
  ( cd "$LV" && git init -q . && git config user.email t@t && git config user.name t \
    && git add -A -f && git commit -qm i ) >/dev/null 2>&1
  bash "$BUILD" --cwd="$LV" >/dev/null 2>&1 \
    && ok "live build rc 0" || fail "live build failed"
  IDX="$LV/.mega-sdd/codebase/symbol-index.json"
  python3 - "$IDX" <<'PY' && ok "exclusions: node_modules + NESTED vendor never indexed; 1-based lines; head stamped" || fail "live index content wrong"
import json, sys
d = json.load(open(sys.argv[1]))
files = {s["file"] for s in d["symbols"]}
assert "app/svc.py" in files, files
assert not any("node_modules" in f or "vendor" in f for f in files), files
assert all(s["line"] >= 1 for s in d["symbols"])
assert d["head_commit"], "head missing"
PY
  bash "$BUILD" --cwd="$LV" --out="$LV/i2.json" >/dev/null 2>&1
  python3 - "$IDX" "$LV/i2.json" <<'PY' && ok "byte-determinism modulo generated_at" || fail "nondeterministic index"
import json, sys
a, b = (json.load(open(p)) for p in sys.argv[1:3])
a.pop("generated_at"); b.pop("generated_at")
assert a == b
PY
  # round-2 live arms (dual-blind 2026-08-02, all folded)
  LR="$W/round2"; mkdir -p "$LR/src/bin" "$LR/bin" "$LR/secretstuff"
  printf 'def dashfile():\n    pass\n' > "$LR/-r.py"
  printf 'pub fn multi_bin_entry() {}\n' > "$LR/src/bin/main.rs"
  printf 'def top_level_bin():\n    pass\n' > "$LR/bin/tool.py"
  printf 'const handler = async (x) => x\n' > "$LR/app.js"
  printf '[ApiController]\npublic class C {\n  [HttpGet("x")]\n  public int Fetch() { return 1; }\n}\n' > "$LR/C.cs"
  printf 'def hidden():\n    pass\n' > "$LR/secretstuff/priv.py"
  printf 'secretstuff/\n' > "$LR/.gitignore"
  ( cd "$LR" && git init -q . && git config user.email t@t && git config user.name t \
    && git add -A && git commit -qm i ) >/dev/null 2>&1
  bash "$BUILD" --cwd="$LR" >/dev/null 2>&1 \
    && ok "B1: a tracked '-r.py' no longer argv-injects ast-grep (build rc 0)" \
    || fail "B1: dash-file build failed"
  python3 - "$LR/.mega-sdd/codebase/symbol-index.json" <<'PY' && ok "B3/B4/B8/B9: attribute-skipped name, arrow indexed, gitignored excluded, src/bin kept, top-level bin/ pruned" || fail "round-2 live index content wrong"
import json, sys
d = json.load(open(sys.argv[1]))
by = {}
for s in d["symbols"]:
    by.setdefault(s["file"], []).append(s)
files = set(by)
assert "-r.py" in files, files                                  # B1 content too
assert "src/bin/main.rs" in files, files                        # B9 nested kept
assert not any(f.startswith("bin/") for f in files), files      # B9 top pruned
assert "secretstuff/priv.py" not in files, files                # B8 gitignore honored
arrows = [s for s in by.get("app.js", []) if s["name"] == "handler"]
assert arrows, by.get("app.js")                                 # B4 arrow covered
cs = [s for s in by.get("C.cs", []) if s["kind"] == "csharp-method"]
assert cs and cs[0]["name"] == "Fetch" and not cs[0]["signature"].startswith("["), cs  # B3
PY
else
  ok "(live arms skipped — ast-grep not on this runner; query arms above are the CI proof)"
fi

echo "== contract pins =="
grep -qF "Reuse symbol index — ONCE per run, batch setup, never per bolt." "$PLUG/skills/execute-bolts/SKILL.md" \
  && grep -qF 'so the JIT bind reads a fresh index (`rebind-units.sh` rebuilds a stale one)' "$PLUG/skills/execute-bolts/SKILL.md" \
  && ok "F6: SKILL batch-setup item 5 feeds the JIT bind" || fail "SKILL batch step missing"
grep -qF "symbol-index.json" "$PLUG/references/paths.md" \
  && ok "paths.md registration" || fail "paths.md missing"

[ "$FAILED" = "0" ] && echo "ALL SYMBOL-INDEX-REUSE PROOFS OK" || echo "symbol-index proofs FAILED"
exit $FAILED
