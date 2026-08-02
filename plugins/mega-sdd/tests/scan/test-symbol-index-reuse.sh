#!/usr/bin/env bash
# test-symbol-index-reuse.sh — tranche R1+R2 (spec
# 2026-08-02-reuse-first-grounding-index.md).
# R1: build-symbol-index.sh (script-owned, deterministic, bounded, honest rc 3)
#     + query-symbol-index.sh (pure read; CI-safe via a hand-written index).
# R2: build-dispatch-prompt.sh emits the priority-3b `symbol_slice` with the
#     deterministic retrieval rule (target-file rows first, then same-dir),
#     provenance stamp, and honest omission when the index is absent.
# Live ast-grep arms self-skip on runners without the binary.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../../.." && pwd)"
PLUG="${ROOT}/plugins/mega-sdd"
BUILD="${PLUG}/scripts/build-symbol-index.sh"
QUERY="${PLUG}/scripts/query-symbol-index.sh"
DISPATCH="${PLUG}/scripts/build-dispatch-prompt.sh"
for f in "$BUILD" "$QUERY" "$DISPATCH"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done
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

echo "== R2 dispatch: symbol_slice emits with the deterministic rule =="
P="$W/proj"; V="$P/.mega-sdd/vaults/v1"; mkdir -p "$V/units" "$P/app/Support" "$P/app/Other" "$P/.mega-sdd/codebase"
( cd "$P" && git init -q . && git config user.email t@t && git config user.name t ) >/dev/null 2>&1
printf '<?php\nfunction formatCurrency(int $c): string { return ""; }\n' > "$P/app/Support/Money.php"
cat > "$V/units/U-001.md" <<'EOF'
---
id: U-001
title: Add money helper usage
task_type: modify
module: billing
risk: low
status: pending
target_files:
  - path: app/Support/Money.php
    operation: modify
acceptance_test:
  - type: command
    command: ./vendor/bin/phpunit
    expects: OK
    desc: money helper keeps formatting
---

## Description

Use the existing money helper.
EOF
( cd "$P" && git add -A && git commit -qm i ) >/dev/null 2>&1
cat > "$P/.mega-sdd/codebase/symbol-index.json" <<'EOF'
{"generated_by":"mega-sdd:build-symbol-index","generated_at":"2026-08-02T00:00:00Z","head_commit":"abcdef1234567890","astgrep_version":"0.42.3","file_count":3,"symbol_count":3,"symbols":[{"name":"sibling","kind":"php-function","file":"app/Support/Cents.php","line":2,"signature":"function sibling()","lang":"php"},{"name":"formatCurrency","kind":"php-function","file":"app/Support/Money.php","line":2,"signature":"function formatCurrency(int $c): string","lang":"php"},{"name":"unrelated","kind":"php-function","file":"app/Other/Far.php","line":2,"signature":"function unrelated()","lang":"php"}]}
EOF
bash "$DISPATCH" --cwd="$P" --vault="$V" --unit=U-001 --plugin-root="$PLUG" </dev/null >/dev/null 2>&1 \
  && ok "builder rc 0 with index present" || fail "builder failed with index"
DP="$V/bolts/U-001/dispatch-prompt.md"
grep -qF "### Existing symbols (REUSE — extend, don't recreate)" "$DP" \
  && ok "symbol_slice header in the emitted prompt" || fail "section missing from prompt"
grep -qF "index@abcdef12" "$DP" && grep -qF "built by scripts/build-symbol-index.sh" "$DP" \
  && ok "provenance stamp (head8 + builder name)" || fail "provenance stamp missing"
grep -qF 'app/Support/Money.php:2 php-function `formatCurrency`' "$DP" \
  && ok "target-file symbol row present" || fail "target-file row missing"
grep -qF "app/Support/Cents.php" "$DP" \
  && ok "same-directory symbol included" || fail "same-dir row missing"
if grep -qF "app/Other/Far.php" "$DP"; then
  fail "unrelated-directory symbol leaked into the slice"
else
  ok "unrelated directory excluded (deterministic rule, not a dump)"
fi
TF_LINE=$(grep -n "Money.php:2" "$DP" | head -1 | cut -d: -f1)
SIB_LINE=$(grep -n "Cents.php" "$DP" | head -1 | cut -d: -f1)
[ -n "$TF_LINE" ] && [ -n "$SIB_LINE" ] && [ "$TF_LINE" -lt "$SIB_LINE" ] \
  && ok "target-file rows ordered BEFORE same-dir rows" || fail "group order wrong ($TF_LINE vs $SIB_LINE)"
# honest omission when the index is absent
rm "$P/.mega-sdd/codebase/symbol-index.json"
OUT=$(bash "$DISPATCH" --cwd="$P" --vault="$V" --unit=U-001 --plugin-root="$PLUG" --explain </dev/null 2>/dev/null)
printf '%s' "$OUT" | grep -q "symbol-index.json absent" \
  && ok "absent index -> recorded omission naming build-symbol-index.sh" \
  || fail "absent-index omission not recorded"
if grep -qF "Existing symbols" "$V/bolts/U-001/dispatch-prompt.md"; then
  fail "section emitted despite absent index"
else
  ok "no index -> no section (omitted, never placeholder-filled)"
fi

echo "== round-2 dispatch arms (F1 cap, B5 sanitize) =="
python3 - "$P/.mega-sdd/codebase/symbol-index.json" <<'PY'
import json, sys
rows = [{"name": "sym%02d" % i, "kind": "php-function", "file": "app/Support/Gen%02d.php" % i,
         "line": 1, "signature": "function sym%02d()" % i} for i in range(45)]
rows.append({"name": "evil`tick", "kind": "php-function", "file": "app/Support/Money.php",
             "line": 9, "signature": "ok line\n# INJECTED HEADING\n```"})
doc = {"generated_by": "mega-sdd:build-symbol-index", "generated_at": "2026-08-02T00:00:00Z",
       "head_commit": "abcdef1234567890", "astgrep_version": "0.42.3",
       "file_count": 46, "symbol_count": len(rows), "symbols": rows}
json.dump(doc, open(sys.argv[1], "w"))
PY
bash "$DISPATCH" --cwd="$P" --vault="$V" --unit=U-001 --plugin-root="$PLUG" </dev/null >/dev/null 2>&1
NROWS=$(grep -c "^- app/Support/" "$DP")
[ "$NROWS" = "40" ] && ok "F1: level-0 cap = 40 rows even UNDER budget" || fail "F1: rows=$NROWS"
grep -qF "+6 more — query via scripts/query-symbol-index.sh" "$DP" \
  && ok "F1: overflow pointer counts the capped remainder" || fail "F1: pointer missing"
if grep -q "^# INJECTED HEADING" "$DP"; then
  fail "B5: hostile newline signature minted its own markdown line"
else
  ok "B5: index fields collapsed to one line (no injected heading)"
fi
if grep -qF 'evil`tick' "$DP"; then
  fail "B5: backtick survived into the name cell"
else
  ok "B5: backticks stripped from interpolated fields"
fi

echo "== contract pins =="
grep -qF '| 3b | `symbol_slice` |' "$PLUG/skills/execute-bolts/references/context-enrichment.md" \
  && ok "context-enrichment table row 3b" || fail "spec table row missing"
grep -qF "Symbol slice (3b" "$PLUG/skills/execute-bolts/references/context-enrichment.md" \
  && ok "spec subsection present" || fail "spec subsection missing"
grep -qF "Reuse symbol index — ONCE per run, batch setup, never per bolt." "$PLUG/skills/execute-bolts/SKILL.md" \
  && ok "F6: SKILL batch-setup item 5 (outside every per-bolt block)" || fail "SKILL batch step missing"
if grep -qF "build-symbol-index.sh" <(sed -n '/### Step 4.5/,/### Step 5/p' "$PLUG/skills/execute-bolts/SKILL.md"); then
  fail "F6: index build leaked back into the per-bolt Step 4.5 block"
else
  ok "F6: per-bolt Step 4.5 block carries NO index build call"
fi
grep -qF "symbol-index.json" "$PLUG/references/paths.md" \
  && ok "paths.md registration" || fail "paths.md missing"
grep -qF '"symbol_slice": 3' "$PLUG/tests/moat/test-dispatch-prompt-cascade.sh" \
  && ok "cascade transcription carries the 3b row" || fail "cascade PRI stale"

[ "$FAILED" = "0" ] && echo "ALL SYMBOL-INDEX-REUSE PROOFS OK" || echo "symbol-index proofs FAILED"
exit $FAILED
