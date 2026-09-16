#!/usr/bin/env bash
# L3 — plan PRE-CODE diet (spec docs/superpowers/specs/2026-09-16-clinic-levers-design.md §2, 8.3.0,
# MEASUREMENT PENDING). MEASURED cause (research §2f): the clinic `plan` took 56 m — ±10 m reading
# validator SOURCE for grammar, 13 m writing 22 units one per turn, ±20 m serial adversarial review.
#   a  the grammar cheatsheet exists, is routed from plan SKILL.md + plan-procedure.md, and every regex
#      it cites appears VERBATIM in the file(s) it names (parity — the sheet cannot drift silently)
#   b  the procedure carries the three diet rules (cheatsheet not source, batched writes, parallel review)
#      + the L2 DAG rails, each labelled MEASUREMENT PENDING at the block level
# Run: bash tests/v8-plan/test-plan-precode-diet.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"
CS="$P/skills/plan/references/unit-grammar-cheatsheet.md"
[ -f "$CS" ] && pass "a: cheatsheet exists" || { fail "a: cheatsheet missing"; echo "FAILURES PRESENT"; exit 1; }
grep -q 'unit-grammar-cheatsheet.md' "$P/skills/plan/SKILL.md" && grep -q 'unit-grammar-cheatsheet.md' "$P/skills/plan/references/plan-procedure.md" \
  && pass "a: routed from plan SKILL.md and plan-procedure.md" || fail "a: cheatsheet not routed"
python3 - "$CS" "$P" <<'PY' && pass "a: every cited regex appears verbatim in the file(s) its row names (parity)" || fail "a: cheatsheet drifted from the validators"
import re, sys, io
cs, root = sys.argv[1], sys.argv[2]
rows = [l for l in io.open(cs, encoding="utf-8").read().splitlines() if l.startswith("|") and not set(l) <= set("|- :")]
checked = 0
for l in rows:
    cells = [c.strip() for c in l.strip().strip("|").split("|")]
    # re-join cells split by an escaped pipe: a cell ending with a backslash was `\|`
    merged = []
    for c in cells:
        if merged and merged[-1].endswith("\\"):
            merged[-1] = merged[-1][:-1] + "|" + c
        else:
            merged.append(c)
    files = re.findall(r"`(scripts/[^`]+)`", l)
    rx = [c[1:-1] for c in merged if len(c) > 2 and c[0] == "`" and c[-1] == "`" and re.search(r"\\s|\[\^|\(\?:|\\d", c)]
    for r in rx:
        assert files, "regex row without a reader file: %s" % l
        srcs = [io.open(root + "/" + f, encoding="utf-8", errors="replace").read() for f in files]
        assert any(r in s for s in srcs), "regex not found verbatim in %s: %s" % (files, r)
        checked += 1
assert checked >= 12, "only %d regexes checked — the sheet lost rows" % checked
print("parity ok:", checked, "regexes")
PY
PR="$P/skills/plan/references/plan-procedure.md"
for k in 'never open `validate-*.sh`' 'Write in batches (L3b)' 'ONE message dispatching N read-only `Explore` reviewers' 'DAG shape (L2)' 'MEASUREMENT PENDING'; do
  grep -qF "$k" "$PR" && pass "b: procedure says: $k" || fail "b: procedure lacks: $k"
done
grep -q 'dag_shape_advisory` = split/reorder' "$PR" && pass "b: Step 5 validator table routes dag_shape_advisory to split/reorder" || fail "b: Step 5 row lacks dag_shape_advisory"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
