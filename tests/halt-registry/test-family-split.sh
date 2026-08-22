#!/usr/bin/env bash
# test-family-split.sh — pins spec 2026-08-17-halt-registry-family-split.md:
# the canonical halt registry keeps envelope + schemas + escalation + a per-type
# INDEX; the 82 guidance bodies live in references/halt-families/<f>.md. Guards
# index↔family consistency both directions, size budgets, anchor survival, and
# the taxonomy-mirror. Run </dev/null.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
HP="$P/references/halt-protocol.md"
FD="$P/references/halt-families"
TAX="$P/skills/orchestrate-flow/references/halt-taxonomy.md"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
PY="${MEGA_SDD_TEST_PY:-python3}"
command -v "$PY" >/dev/null 2>&1 || { echo "SKIP (no python3)"; exit 0; }

[ -f "$HP" ] && [ -d "$FD" ] || { echo "FAIL: registry or halt-families/ missing"; exit 1; }

echo "── a: index ↔ family consistency (both directions) ──"
"$PY" - "$HP" "$FD" <<'PYEOF'
import re, sys, os, glob
hp = open(sys.argv[1]).read()
fd = sys.argv[2]
i0 = hp.index('### Type-specific guidance — registry index')
i1 = hp.index('### Multiple blockers in one run')
idx = hp[i0:i1]
# family group headers + rows
groups = re.findall(r'\*\*([a-z-]+)\*\* \(`halt-families/([a-z-]+)\.md`\):', idx)
assert groups, "no family groups in index"
rows = {}
cur = None
for ln in idx.split('\n'):
    m = re.match(r'\*\*([a-z-]+)\*\* \(`halt-families/', ln)
    if m: cur = m.group(1); continue
    m = re.match(r'- `([a-z0-9_]+)`( \*\(subtype of `quality_gate_failed`\)\*)? — ', ln)
    if m and cur: rows.setdefault(cur, []).append(m.group(1))
n_rows = sum(len(v) for v in rows.values())
assert n_rows >= 78, f"index shrank: only {n_rows} rows"  # v7.3.0: routing_outcome_corrupt + memory_schema_mismatch removed with the memory lane
missing = []
for fam, types in rows.items():
    ft = open(os.path.join(fd, fam + '.md')).read()
    for t in types:
        if not re.search(r'^### ' + re.escape(t) + r'( \(registry one-liner\))?$', ft, re.M):
            missing.append((fam, t))
assert not missing, f"index rows with no family section: {missing}"
# reverse: every family ### heading is an index row
orphans = []
for fp in glob.glob(os.path.join(fd, '*.md')):
    fam = os.path.basename(fp)[:-3]
    for m in re.finditer(r'^### ([a-z0-9_]+)', open(fp).read(), re.M):
        if m.group(1) not in rows.get(fam, []):
            orphans.append((fam, m.group(1)))
assert not orphans, f"family sections with no index row: {orphans}"
print(f"consistent: {n_rows} rows across {len(rows)} families")
PYEOF
[ $? -eq 0 ] && ok "a1 index rows ↔ family sections consistent both ways" || fail "a1 index/family drift"

echo "── b: size budgets (spec-amended) ──"
B=$(wc -c < "$HP" | tr -d ' ')
[ "$B" -le 30000 ] && ok "b1 registry $B <= 30000" || fail "b1 registry regrew to $B"
OVER=""
for f in "$FD"/*.md; do
  FB=$(wc -c < "$f" | tr -d ' ')
  [ "$FB" -gt 12800 ] && OVER="$OVER $(basename $f):$FB"
done
[ -z "$OVER" ] && ok "b2 every family <= 12800 B" || fail "b2 oversized family:$OVER"

echo "── c: anchor + pin survival in the canonical file ──"
grep -q '^## §halt-protocol' "$HP" && ok "c1 §halt-protocol anchor heads its section" || fail "c1 envelope anchor lost"
grep -q '^## §halt-escalation-discipline' "$HP" && ok "c2 escalation anchor intact" || fail "c2 escalation anchor lost"
grep -q 'citation_unresolvable' "$HP" && ok "c3 citation_unresolvable greppable in registry" || fail "c3 enum pin lost"
grep -q 'ANNEX_FORGED' "$HP" && ok "c4 ANNEX_FORGED greppable in registry (index row)" || fail "c4 ANNEX_FORGED pin lost"
grep -q 'execution_fabricated' "$HP" && ok "c5 execution_fabricated registry row present" || fail "c5 execution_fabricated lost"
grep -q 'Keterangan block FIRST' "$HP" && ok "c6 halt-displayer contract intact" || fail "c6 displayer contract lost"

echo "── d: taxonomy mirror names no halt type unknown to the registry ──"
# Round catch (P2a M5): the first version computed `miss` and never asserted it,
# and its `t in hp` filter made a wholly-absent type unflaggable. Now: every
# snake_case backticked token in the taxonomy that is not a known envelope FIELD
# must appear SOMEWHERE in the canonical registry text (index row, enum, or kept
# section) — a phantom type in the mirror fails.
"$PY" - "$HP" "$TAX" <<'PYEOF'
import re, sys
hp = open(sys.argv[1]).read()
tax = open(sys.argv[2]).read()
known_fields = {'next_action','suggested_action','conflict_old','conflict_new',
                'suggested_action_rationale','user_response_required','details',
                'halt_self_resolved','fix_applied','memory_context','source_skill',
                'vault_version','resolver_owner','resolver_route','max_replan_count',
                'max_revalidate_count','partial_slices','stale_slices','per_slice'}
tax_types = set(re.findall(r'`([a-z0-9_]+)`', tax))
miss = sorted(t for t in tax_types if '_' in t and t not in known_fields and t not in hp)
assert not miss, f"taxonomy names types the registry does not know: {miss}"
idx_types = set(re.findall(r'^- `([a-z0-9_]+)`', hp[hp.index('registry index'):], re.M))
print(f"index={len(idx_types)} taxonomy-tokens={len(tax_types)} phantom=0")
PYEOF
[ $? -eq 0 ] && ok "d1 taxonomy mirror asserts (phantom type would fail)" || fail "d1 mirror drift or phantom type"

echo "── d2: subtype enum restored + dispatch rule canonical (round B1) ──"
grep -q '#### `quality_gate_failed` subtypes' "$HP" && ok "d2a subtype section heads the registry" || fail "d2a subtype section missing"
grep -qF 'Consumer dispatch logic MUST branch on `details.subtype`' "$HP" && ok "d2b dispatch rule canonical" || fail "d2b dispatch rule lost"
N9=$(grep -c '^- `[a-z0-9_]*` \*(subtype of `quality_gate_failed`)\*' "$HP")
[ "$N9" -eq 9 ] && ok "d2c all 9 subtype rows marked" || fail "d2c subtype row markers wrong: $N9"

echo "── d3: stop-class floor across family files (semantic-flip tripwire) ──"
NSTOP=$(cat "$FD"/*.md | grep -o 'ALWAYS STOP' | wc -l | tr -d ' ')
[ "$NSTOP" -ge 55 ] && ok "d3 ALWAYS STOP floor holds ($NSTOP >= 55)" || fail "d3 stop-class erosion: only $NSTOP ALWAYS STOP markers left"

echo "── e: family files carry the relocation banner (edit-here contract) ──"
BAD=""
for f in "$FD"/*.md; do
  grep -q 'VERBATIM relocations; edit them here' "$f" || BAD="$BAD $(basename $f)"
done
[ -z "$BAD" ] && ok "e1 every family carries the edit-here banner" || fail "e1 banner missing:$BAD"

echo "── z: no guidance body left in the registry (the split actually happened) ──"
grep -qF 'MSYS2 runtime injects' "$HP" && fail "z0 sanity probe misfired" || true
grep -qF 'a chat-brief delta exceeds the ticket-scale cap (new entities+flows > 2, changed rows > 12' "$HP" \
  && fail "z1 delta_too_large full body still inline in registry" || ok "z1 long guidance bodies gone from registry"

echo
echo "halt-family split: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
