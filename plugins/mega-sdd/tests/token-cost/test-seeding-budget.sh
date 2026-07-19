#!/usr/bin/env bash
# test-seeding-budget.sh — pins the P7 measurement instrument (seeding_budget.py
# + measure-seeds.sh). The instrument is the ruler every slice-first cut is
# justified by, so its correctness is load-bearing: a counter that lies by
# omission would launder a slice that never actually shrank the seed.
#
# Covers: byte/token math, realpath dedup, MISSING surfaced (never dropped),
# budget UNDER/OVER + --enforce exit contract, --stdin, and measure-seeds
# ranking on a live mini-vault (JSON + table, honest omission notes).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../.."
LIB="$PLUGIN/scripts/_lib/seeding_budget.py"
MEASURE="$PLUGIN/scripts/measure-seeds.sh"
rc=0
ok()  { echo "PASS ($1)"; }
bad() { echo "FAIL ($1)"; rc=1; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t seedbudget)"
trap 'rm -rf "$WORK"' EXIT

# ── seeding_budget.py: byte + token math ──────────────────────────────────────
printf '12345678' > "$WORK/eight.txt"   # 8 bytes -> ceil(8/4)=2 tokens
OUT="$(python3 "$LIB" "$WORK/eight.txt" --json 2>&1)"
echo "$OUT" | grep -q '"bytes": 8'          && ok "byte count exact"       || bad "byte count: $OUT"
echo "$OUT" | grep -q '"approx_tokens": 2'  && ok "token math ceil(b/4)"   || bad "token math: $OUT"

# ── realpath dedup: same file twice counts once ──────────────────────────────
OUT="$(python3 "$LIB" "$WORK/eight.txt" "$WORK/eight.txt" --json 2>&1)"
echo "$OUT" | grep -q '"bytes": 8' && ok "dedup: same path counted once" || bad "dedup failed: $OUT"

# ── MISSING surfaced, never silently dropped (understating is the moat risk) ──
OUT="$(python3 "$LIB" "$WORK/nope.md" --json 2>&1)"
echo "$OUT" | grep -q '"missing": \["'"$WORK"'/nope.md"\]' && ok "missing component surfaced" || bad "missing not surfaced: $OUT"
echo "$OUT" | grep -q '"bytes": 0' && ok "missing counted as 0, not invented" || bad "missing miscounted: $OUT"

# ── budget verdict + --enforce exit contract ─────────────────────────────────
python3 "$LIB" "$WORK/eight.txt" --budget 1 >/dev/null 2>&1
[ $? -eq 0 ] && ok "OVER budget advisory-only exits 0 without --enforce" || bad "advisory budget should exit 0"
python3 "$LIB" "$WORK/eight.txt" --budget 1 --enforce >/dev/null 2>&1
[ $? -eq 1 ] && ok "OVER + --enforce exits 1 (blocking)" || bad "--enforce OVER should exit 1"
python3 "$LIB" "$WORK/eight.txt" --budget 999 --enforce >/dev/null 2>&1
[ $? -eq 0 ] && ok "UNDER + --enforce exits 0" || bad "--enforce UNDER should exit 0"
OUT="$(python3 "$LIB" "$WORK/eight.txt" --budget 1 --json 2>&1)"
echo "$OUT" | grep -q '"verdict": "OVER"' && ok "JSON carries verdict" || bad "verdict missing: $OUT"

# ── --stdin counted ──────────────────────────────────────────────────────────
OUT="$(printf 'abcd' | python3 "$LIB" --stdin --json 2>&1)"
echo "$OUT" | grep -q '"bytes": 4' && ok "--stdin bytes counted" || bad "--stdin: $OUT"

# ── --weight cost-units (cache economics: fresh 1.0x vs resident 0.1x) ─────────
printf '________________________________________' > "$WORK/forty.txt"  # 40B -> 10 tok
OUT="$(python3 "$LIB" "$WORK/forty.txt" --weight fresh --json 2>&1)"
echo "$OUT" | grep -q '"cost_units": 10' && ok "fresh weight (1.0x): cost_units == tokens" || bad "fresh weight: $OUT"
OUT="$(python3 "$LIB" "$WORK/forty.txt" --weight resident --json 2>&1)"
echo "$OUT" | grep -q '"cost_units": 1' && ok "resident weight (0.1x): 10 tok -> 1 cost-unit" || bad "resident weight: $OUT"
OUT="$(python3 "$LIB" "$WORK/forty.txt" --weight 0.5 --json 2>&1)"
echo "$OUT" | grep -q '"cost_units": 5' && ok "float weight 0.5x honored" || bad "float weight: $OUT"
python3 "$LIB" "$WORK/forty.txt" --weight bogus >/dev/null 2>&1
[ $? -eq 3 ] && ok "bad --weight -> usage exit 3" || bad "weight validation"
# budget verdicts against cost-units when weighted (resident discount clears it)
python3 "$LIB" "$WORK/forty.txt" --weight resident --budget 5 --enforce >/dev/null 2>&1
[ $? -eq 0 ] && ok "weighted budget uses cost-units (1 <= 5, UNDER)" || bad "weighted budget wrong unit"

# ── usage guard ──────────────────────────────────────────────────────────────
python3 "$LIB" >/dev/null 2>&1
[ $? -eq 3 ] && ok "no-args -> usage exit 3" || bad "usage exit contract"

# ── measure-seeds.sh on a live mini-vault ────────────────────────────────────
V="$WORK/proj/.mega-sdd/vaults/mini"
mkdir -p "$V" "$WORK/proj/.mega-sdd/codebase"
printf '# index\ncontent\n'      > "$V/00-index.md"
printf '# data\nEmployee\n'      > "$V/03-data-model.md"
printf '{"vault":"mini"}\n'      > "$V/vault.json"
printf '# Binding\n- C-001 | 03-data-model.md:2 | app/E.php:1 | x\n' > "$V/binding.md"
printf '{"claims":[{"id":"C-001","verdict":"CONFIRMED","vault_source":"03-data-model.md:2"}]}\n' > "$V/binding.json"
printf '# Map\nclass Employee\n' > "$WORK/proj/.mega-sdd/codebase/codebase-map.md"

OUT="$(bash "$MEASURE" --vault "$V" 2>&1)"; MRC=$?
[ $MRC -eq 0 ] && ok "measure-seeds exits 0 on a vault" || bad "measure-seeds rc=$MRC: $OUT"
echo "$OUT" | grep -q "bind-codebase"  && ok "ranks bind-codebase seed"  || bad "bind-codebase row missing: $OUT"
echo "$OUT" | grep -q "phase-advisor"  && ok "ranks phase-advisor seed"  || bad "phase-advisor row missing"
echo "$OUT" | grep -q "generate-units" && ok "ranks generate-units seed" || bad "generate-units row missing"
# JSON mode is well-formed + sorted desc by cost-units (cache-weighted), and
# every consumer carries a cache weight + cost_units.
JOUT="$(bash "$MEASURE" --vault "$V" --json 2>&1)"
echo "$JOUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); c=[s["cost_units"] for s in d["seeds"]]; sys.exit(0 if c==sorted(c,reverse=True) else 1)' \
  && ok "JSON ranked descending by cost-units" || bad "JSON not sorted by cost-units / malformed"
echo "$JOUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if all("weight" in s and "cost_units" in s for s in d["seeds"]) else 1)' \
  && ok "every consumer carries cache weight + cost_units" || bad "weight/cost_units missing from a consumer"
# honest omission note fires (this vault has a map but no KB, no pack)
echo "$JOUT" | grep -q "KB: not found" && ok "honest omission note for missing KB" || bad "missing-KB note absent"

# ── measure-seeds usage guard ────────────────────────────────────────────────
bash "$MEASURE" --vault "$WORK/does-not-exist" >/dev/null 2>&1
[ $? -eq 3 ] && ok "measure-seeds missing vault -> exit 3" || bad "measure-seeds usage exit"

echo "== test-seeding-budget: $([ $rc -eq 0 ] && echo ALL-PASS || echo HAS-FAIL) =="
exit $rc
