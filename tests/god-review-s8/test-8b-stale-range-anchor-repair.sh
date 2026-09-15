#!/usr/bin/env bash
# S8-b — moat class "stale line-range anchor" (owner amendment P3 #4, v8 P3; live
# instances: clinic lite U-008 `.env.example:1-29` on a 28-line file, xs lite U-006 —
# both KEEP_CODE with zero code change, ±10 min of controller detour each).
# Auto-repair at the JIT bind gate is allowed ONLY when the repaired range points at
# content that is byte-identical to what the anchor was authored against (sha match);
# changed content stays CONFLICT — never "repaired".
#   R1 shift  the authoring-snapshot range content is found verbatim (unique) at another
#             offset of the current file → range shifted, CONFIRMED, `repair` recorded,
#             unit `## Anchors` line rewritten
#   R2 clamp  the file is byte-identical to the authoring snapshot AND the range overshoots
#             EOF by exactly one line (the trailing-newline miscount, the P2 class) → clamped
#   CONFLICT  content of the range changed (no unique verbatim match) — stays CONFLICT
#   CONFLICT  a PARTIAL range (lo > 1) overshooting by > 1 line on an unchanged file — the
#             intended block is ambiguous, never clamped
#   R2 clamp  (8.0.1) a WHOLE-FILE range (lo == 1) overshooting by > 1 on a byte-identical file →
#             clamped: lines past EOF never existed, lines 1..n ARE what the author read (xs lite
#             8.0.0 run: 4/5 units hit `login/page.tsx:1-25` on an unchanged 22-line file = 4 false
#             CONFLICTs, all KEEP_CODE with zero code change)
#   idempotent: a second bind repairs nothing (anchors already rewritten)
#   parity: check-anchor-freshness.sh sees the rewritten anchors as fresh
# Run: bash tests/god-review-s8/test-8b-stale-range-anchor-repair.sh </dev/null
set -uo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"; S="$REPO/plugins/mega-sdd/scripts"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
rc=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; rc=1; }
F="$WORK/proj"; V="$F/.mega-sdd/vaults/v"; mkdir -p "$V/units" "$F/src"
G() { git -C "$F" -c user.email=t@t -c user.name=t "$@"; }
( cd "$F" && git init -q . )
lines() { local n=$1 f=$2; : > "$f"; local i; for i in $(seq 1 "$n"); do echo "line $i of $(basename "$f")" >> "$f"; done; }
lines 28 "$F/src/a.txt"; lines 10 "$F/src/b.txt"; lines 10 "$F/src/c.txt"; lines 28 "$F/src/d.txt"; lines 22 "$F/src/e.txt"
cat > "$V/units/U-001.md" <<'MD'
---
id: U-001
title: anchors
task_type: extend
vault_source: context.md#f
target_files:
  - path: src/z.txt
    operation: create
acceptance_test:
  - type: test
    command: x
    expects: "ok"
---
# u

## Anchors
- src/a.txt:1-29 — whole file (author counted the trailing newline: 29 on a 28-line file)
- src/b.txt:8-10 — a block that will move UP by two lines (lines deleted above it → range past EOF)
- src/c.txt:2-4 — a block whose content will change
- src/d.txt:5-40 — a PARTIAL range overshooting by 12 lines (ambiguous block)
- src/e.txt:1-25 — a WHOLE-FILE range overshooting by 3 on an unchanged 22-line file (the 8.0.0 field shape)
MD
G add -A >/dev/null; G commit -qm "docs(sdd): plan vault (authoring snapshot)"
# the code moves on: b LOSES its two top lines (the authored block 8-10 now lives at 6-8 and the
# old range overshoots the 8-line file), c's block is rewritten in place
tail -n +3 "$F/src/b.txt" > "$F/src/b.tmp" && mv "$F/src/b.tmp" "$F/src/b.txt"
python3 - "$F/src/c.txt" <<'PY'
import sys; p=sys.argv[1]; L=open(p).read().splitlines()
L[1]="CHANGED 2"; L[2]="CHANGED 3"; L[3]="CHANGED 4"; open(p,"w").write("\n".join(L)+"\n")
PY
G add -A >/dev/null; G commit -qm "feat(U-000): move b, rewrite c"

W="$V/bolts/_wave-claims.json"
bash "$S/derive-unit-claims.sh" --cwd="$F" --vault="$V" --units=U-001 >/dev/null 2>&1 || bad "derive-unit-claims failed"
bash "$S/write-unit-binding.sh" --cwd="$F" --vault="$V" --unit=U-001 --claims="$W" >/dev/null 2>&1 || bad "write-unit-binding failed"
B="$V/bolts/U-001/binding.json"
J() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {"d": d}))' "$1" "$2"; }
claim() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); c=[c for c in d["claims"] if c["expect"].startswith(sys.argv[2])]; print(json.dumps(c[0]) if c else "{}")' "$B" "$1"; }

# ── R2 clamp: a.txt 1-29 on an unchanged 28-line file ──
A="$(claim src/a.txt)"
echo "$A" | python3 -c 'import json,sys; c=json.load(sys.stdin); assert c["verdict"]=="CONFIRMED" and c["anchor"]=="src/a.txt:1-28" and c["repair"]["rule"]=="R2-clamp" and c["repair"]["from"]=="src/a.txt:1-29", c' \
  && ok "R2: 1-29 on an unchanged 28-line file → CONFIRMED, clamped to 1-28, repair recorded (from/rule/reference)" || bad "R2 clamp: $A"
grep -q '^- src/a.txt:1-28 — whole file' "$V/units/U-001.md" && ok "R2: unit ## Anchors line rewritten to 1-28 (rest of the line untouched)" || bad "R2 unit rewrite: $(grep 'src/a.txt' "$V/units/U-001.md")"

# ── R1 shift: b.txt 8-10 content now lives at 6-8 (range 8-10 no longer fits the 8-line file) ──
Bc="$(claim src/b.txt)"
echo "$Bc" | python3 -c 'import json,sys; c=json.load(sys.stdin); assert c["verdict"]=="CONFIRMED" and c["anchor"]=="src/b.txt:6-8" and c["repair"]["rule"]=="R1-shift" and c["repair"]["from"]=="src/b.txt:8-10", c' \
  && ok "R1: 8-10 whose authoring content moved to 6-8 → CONFIRMED, shifted (content sha match)" || bad "R1 shift: $Bc"
grep -q '^- src/b.txt:6-8 — a block' "$V/units/U-001.md" && ok "R1: unit anchor rewritten to 6-8" || bad "R1 unit rewrite: $(grep 'src/b.txt' "$V/units/U-001.md")"

# ── CONFLICT: c.txt 2-4 content changed — range still fits, so today it is CONFIRMED by
#    range-fit (unchanged behavior, out of P3 scope); the repair machinery must NOT touch it ──
Cc="$(claim src/c.txt)"
echo "$Cc" | python3 -c 'import json,sys; c=json.load(sys.stdin); assert "repair" not in c and c["anchor"]=="src/c.txt:2-4", c' \
  && ok "changed content inside a fitting range: no repair attempted, anchor untouched (range-fit verdict unchanged)" || bad "c.txt touched: $Cc"

# ── CONFLICT: d.txt 5-40 on a 28-line file — PARTIAL range, overshoot 12, never clamped ──
Dc="$(claim src/d.txt)"
echo "$Dc" | python3 -c 'import json,sys; c=json.load(sys.stdin); assert c["verdict"]=="CONFLICT" and "repair" not in c and "not repairable" in c["evidence"], c' \
  && ok "partial range overshooting > 1 on an unchanged file → CONFLICT (ambiguous block; nothing clamped), evidence says why" || bad "d.txt: $Dc"
grep -q '^- src/d.txt:5-40 —' "$V/units/U-001.md" && ok "CONFLICT anchor left verbatim in the unit" || bad "d.txt anchor was rewritten"

# ── R2 (8.0.1): e.txt 1-25 on an unchanged 22-line file — whole-file range, clamped ──
Ec="$(claim src/e.txt)"
echo "$Ec" | python3 -c 'import json,sys; c=json.load(sys.stdin); assert c["verdict"]=="CONFIRMED" and c["anchor"]=="src/e.txt:1-22" and c["repair"]["rule"]=="R2-clamp" and c["repair"]["from"]=="src/e.txt:1-25" and "whole-file" in c["evidence"], c' \
  && ok "R2 (8.0.1): whole-file 1-25 on an unchanged 22-line file → CONFIRMED, clamped to 1-22 (overshoot 3 — the xs 8.0.0 field shape)" || bad "e.txt whole-file clamp: $Ec"
grep -q '^- src/e.txt:1-22 — a WHOLE-FILE' "$V/units/U-001.md" && ok "R2 (8.0.1): unit ## Anchors line rewritten to 1-22" || bad "e.txt unit rewrite: $(grep 'src/e.txt' "$V/units/U-001.md")"

# ── content changed AND range overshoots: no verbatim match anywhere → CONFLICT ──
# the repaired anchors are committed FIRST (their authoring snapshot = this commit, where
# a.txt is still the 28-line file); only THEN a.txt mutates (27 lines, line 1 rewritten)
G add -A >/dev/null; G commit -qm "chore(sdd): repaired anchors" >/dev/null
python3 - "$F/src/a.txt" <<'PY'
import sys; p=sys.argv[1]; L=open(p).read().splitlines(); L=L[:27]; L[0]="MUTATED"; open(p,"w").write("\n".join(L)+"\n")
PY
G add -A >/dev/null; G commit -qm "feat(U-000): mutate a" >/dev/null
bash "$S/derive-unit-claims.sh" --cwd="$F" --vault="$V" --units=U-001 >/dev/null 2>&1
bash "$S/write-unit-binding.sh" --cwd="$F" --vault="$V" --unit=U-001 --claims="$W" >/dev/null 2>&1
A2="$(claim src/a.txt)"
echo "$A2" | python3 -c 'import json,sys; c=json.load(sys.stdin); assert c["verdict"]=="CONFLICT" and "repair" not in c, c' \
  && ok "range 1-28 on a MUTATED 27-line file → CONFLICT (content differs from the authoring snapshot: no shift, no clamp)" || bad "mutated a.txt: $A2"

# ── idempotency: re-bind on the now-committed rewritten anchors repairs nothing for b ──
B2="$(claim src/b.txt)"
echo "$B2" | python3 -c 'import json,sys; c=json.load(sys.stdin); assert c["verdict"]=="CONFIRMED" and c["anchor"]=="src/b.txt:6-8" and "repair" not in c, c' \
  && ok "idempotent: the rewritten 6-8 anchor binds CONFIRMED with no further repair" || bad "idempotency: $B2"

# ── parity: anchor-freshness sees the repaired anchors as fresh (start lines in range) ──
OUT="$(bash "$S/check-anchor-freshness.sh" --cwd="$F" --units=U-001 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "check-anchor-freshness rc=0 on the repaired unit" || bad "anchor-freshness rc=$RC: $(echo "$OUT" | head -c 200)"

echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
