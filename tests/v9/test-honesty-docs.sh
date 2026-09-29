#!/usr/bin/env bash
# test-honesty-docs.sh — pins the 9.0 honesty/doc fixes from the 2026-09-27 verification (V2, V3,
# V5, V6, V8, V9). User-facing text makes no accuracy claim for mega-sdd, scopes the routed-lane
# result to what was measured, points at things that exist, and every benchmark number it quotes
# recomputes from benchmarks/results/vanilla-ab/ (compare.json + per-run delivery-check.txt).
#   h1  no "anti-hallucination" marketing: manifest keywords, plugin CLAUDE.md, scenario-6
#   h2  routed result scoped: no "on par" / "at vanilla cost"; ratios + OVERLAP match compare.json
#   h3  old-default ranges (time, cost) and the delivery-check 9-clean-FAIL count match the raw data
#   h4  revamp-journey.md opens with the pre-9.0 history banner
#   h5  invariant #2 no longer names the per-unit bolt-implementer dispatch (removed in P3, spec §8.6)
#   h6  direct-lane.md's assisted trigger list = route-lane.sh's assisted signals
#   h7  install-deps description lists only tool-matrix tools
#   h8  plan Step 9.5 adversarial dispatch carries mega-sdd-trace:plan (+ listed in the contract)
#   h9  paths.md names no deleted script
#   h10 migrate-paths layout-2 rung: following its printed NEXT step reaches the layout-3 rung
# Run: bash tests/v9/test-honesty-docs.sh </dev/null
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"
rc=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; rc=1; }
. "$P/scripts/_lib/resolve-python.sh"
mega_sdd_python || { echo "SKIP: no usable python interpreter"; exit 0; }
PY="$MEGA_SDD_PY"

# h1
"$PY" - "$ROOT/.claude-plugin/marketplace.json" "$P/.claude-plugin/plugin.json" <<'EOF' && ok "h1: no anti-hallucination keyword in either manifest" || bad "h1: a manifest still carries the anti-hallucination keyword (or does not parse)"
import json, sys
m = json.load(open(sys.argv[1])); p = json.load(open(sys.argv[2]))
kws = [k for pl in m.get("plugins", []) for k in pl.get("keywords", [])] + p.get("keywords", [])
sys.exit(1 if any("hallucin" in k.lower() for k in kws) else 0)
EOF
grep -qi 'anti-hallucination by construction' "$P/CLAUDE.md" && bad "h1: plugin CLAUDE.md claims anti-hallucination by construction" || ok "h1: plugin CLAUDE.md makes no by-construction accuracy claim"
grep -qi 'anti-hallucinating' "$ROOT/tests/scenarios/scenario-6-recovery-from-halt.md" && bad "h1: scenario-6 still says anti-hallucinating" || ok "h1: scenario-6 claim qualified"

# h2 + h3: every quoted number recomputes from the committed raw data
PYTHONIOENCODING=utf-8 "$PY" - "$ROOT" <<'EOF' || rc=1
import json, os, re, sys
root = sys.argv[1]; ab = os.path.join(root, "benchmarks/results/vanilla-ab")
c = json.load(open(os.path.join(ab, "compare.json")))
docs = {n: open(os.path.join(root, n), encoding="utf-8").read() for n in
        ("README.md", "plugins/mega-sdd/README.md", "plugins/mega-sdd/references/direct-lane.md")}
bad = 0
def check(cond, msg):
    global bad
    print(("PASS: " if cond else "FAIL: ") + msg)
    bad |= (not cond)
med = lambda sc, arm, m: c[sc]["stats"][arm][m]["median"]
ratio = lambda sc, arm, m: med(sc, arm, m) / med(sc, "vanilla", m)
for n in ("README.md", "plugins/mega-sdd/README.md"):
    check(not re.search(r"on par|at vanilla cost", docs[n]), "h2: %s has no unscoped 'on par' / 'at vanilla cost'" % n)
cost = {sc: ratio(sc, "routed", "cost_usd") for sc in ("xs", "clinic")}
tok = {sc: ratio(sc, "routed", "total") for sc in ("xs", "clinic")}
for sc in ("xs", "clinic"):
    for m in ("cost_usd", "total"):
        check("routed: OVERLAP" in c[sc]["verdicts"][m], "h2: %s routed %s verdict is OVERLAP, as the docs say" % (sc, m))
    for n in ("README.md", "plugins/mega-sdd/README.md"):
        for r in (cost[sc], tok[sc]):
            check("%.2f×" % r in docs[n], "h2: %s quotes %s routed/vanilla %.2f×" % (n, sc, r))
for lo_hi in ("%.1f–%.1f×" % (min(cost.values()), max(cost.values())),
              "%.1f–%.1f×" % (min(tok.values()), max(tok.values()))):
    check(lo_hi in docs["README.md"], "h2: README quotes the routed median range %s" % lo_hi)
old = [(sc, a) for sc, a in (("xs", "lite"), ("xs", "classic"), ("clinic", "lite"))]
t = [ratio(sc, a, "review_ready_min") for sc, a in old]; k = [ratio(sc, a, "cost_usd") for sc, a in old]
t_rng = "%.1f–%.0f×" % (min(t), max(t)); k_rng = "%.1f–%.0f×" % (min(k), max(k))
for n in docs:
    check(t_rng in docs[n] and k_rng in docs[n], "h3: %s quotes the old-default ranges %s time, %s cost" % (n, t_rng, k_rng))
man = json.load(open(os.path.join(ab, "manifest.json")))["runs"]
fails = passes_other = 0; pipe = 0
for r in man:
    if r["scenario"] == "brownfield":
        continue
    d = os.path.join(ab, r["scenario"], r["run"])
    clean = json.load(open(os.path.join(d, "metrics.json")))["clean"]["is_clean"]
    v = open(os.path.join(d, "delivery-check.txt")).read()
    if r["arm"] in ("lite", "classic") and clean:
        pipe += 1; fails += "VERDICT: FAIL" in v
    elif r["arm"] not in ("lite", "classic"):
        passes_other += "VERDICT: PASS" not in v
check(pipe == fails and "its %d clean lite and classic runs all failed the check" % fails in docs["README.md"],
      "h3: README's delivery-check FAIL count (%d/%d clean pipeline runs) matches delivery-check.txt" % (fails, pipe))
check(passes_other == 0, "h3: every routed and vanilla greenfield run PASSed delivery-check, as the docs say")
sys.exit(1 if bad else 0)
EOF

# h4
head -5 "$ROOT/docs/mega-sdd/revamp-journey.md" | grep -q 'Sejarah (pra-9.0)' && ok "h4: revamp-journey.md carries the history banner" || bad "h4: revamp-journey.md lacks the pre-9.0 history banner"

# h5
grep -E '^2\. \*\*The CONFLICT gate blocks\*\*' "$P/CLAUDE.md" | grep -q 'bolt-implementer' \
  && bad "h5: invariant #2 still names the removed bolt-implementer dispatch (P3, spec §8.6)" || ok "h5: invariant #2 no longer names the removed per-unit bolt-implementer dispatch"

# h6
sig=$(grep -E "elif any\(s in fired for s in \(" "$P/scripts/route-lane.sh" | grep -oE "'[a-z_]+'" | tr -d "'")
line=$(grep -E '^Assisted fires on' -A1 "$P/references/direct-lane.md" | tr '\n' ' ')
miss=""; for s in $sig; do echo "$line" | grep -qF "\`$s\`" || miss="$miss $s"; done
[ -n "$sig" ] && [ -z "$miss" ] && ok "h6: direct-lane.md lists every assisted signal of route-lane.sh ($(echo $sig))" || bad "h6: direct-lane.md assisted triggers miss:${miss:- (route-lane.sh tuple not found)}"

# h7
desc=$(sed -n '/^description:/{p;q;}' "$P/skills/install-deps/SKILL.md" | sed -E 's/^[^(]*\(([^)]*)\).*/\1/')
ids=$(grep -E '^  - id: ' "$P/skills/install-deps/references/tool-matrix.yaml" | awk '{print $3}')
extra=""; for t in $(echo "$desc" | tr ',' ' '); do echo "$ids" | grep -qx "$t" || extra="$extra $t"; done
[ -z "$extra" ] && ok "h7: install-deps description lists only tool-matrix tools" || bad "h7: install-deps description names tools not in tool-matrix.yaml:$extra"

# h8
sed -n '/^Subagent dispatch contract:/,/^## /p' "$P/skills/plan/references/adversarial-test-prompt.md" | grep -qF '`mega-sdd-trace:plan`' \
  && ok "h8: the Step 9.5 dispatch contract carries mega-sdd-trace:plan" || bad "h8: adversarial dispatch contract has no trace line"
grep -F 'Adversarial review in parallel (L3c)' "$P/skills/plan/references/plan-procedure.md" | grep -qF 'mega-sdd-trace:plan' \
  && ok "h8: plan-procedure L3c dispatch carries the trace line" || bad "h8: plan-procedure L3c dispatch lacks the trace line"
grep -F 'Step 9.5' "$ROOT/docs/gateway-contract.md" | grep -qF 'mega-sdd-trace:plan' \
  && ok "h8: gateway-contract lists the Step 9.5 dispatch" || bad "h8: gateway-contract does not list the Step 9.5 dispatch"

# h9
gone=""; for s in $(grep -oE 'scripts/[A-Za-z0-9_/.-]+\.(sh|py)' "$P/references/paths.md" | sort -u); do
  [ -f "$P/$s" ] || gone="$gone $s"; done
[ -z "$gone" ] && ok "h9: every script paths.md names exists" || bad "h9: paths.md names deleted script(s):$gone"

# h10: do what the layout-2 rung's NEXT step says, and land on the layout-3 rung
MP="$P/scripts/migrate-paths.sh"; W="$(mktemp -d 2>/dev/null || mktemp -d -t honesty)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/p/.mega-sdd/vaults"; cp -R "$ROOT/tests/migrate-paths/fixtures/clinic-vault7" "$W/p/.mega-sdd/vaults/clinic"
( cd "$W/p" && git init -q . && git config user.email t@t && git config user.name t && git add -A && git commit -qm init ) >/dev/null 2>&1
OUT=$(bash "$MP" --vault-layout --apply --cwd="$W/p" </dev/null 2>&1)
NEXT=$(echo "$OUT" | sed -n '/^NEXT (MANDATORY)/,$p')
if echo "$NEXT" | grep -q '(bind)'; then bad "h10: layout-2 NEXT still points at the removed whole-vault bind"
elif ! echo "$NEXT" | grep -qF -- '--vault-layout=3 --apply'; then bad "h10: layout-2 NEXT does not name the layout-3 rung"
elif ! echo "$NEXT" | grep -qi 'commit'; then bad "h10: layout-2 NEXT omits the commit the layout-3 rung's dirty-tree guard needs"
else
  ( cd "$W/p" && git add -A && git commit -qm layout2 ) >/dev/null 2>&1
  OUT3=$( cd "$W/p" && bash "$MP" --vault-layout=3 --apply 2>&1 ); R3=$?
  [ "$R3" -eq 0 ] && [ -f "$W/p/.mega-sdd/vaults/clinic/context.md" ] && echo "$OUT3" | grep -q 'full JIT re-bind required' \
    && ok "h10: following the layout-2 NEXT step reaches the layout-3 rung and its JIT re-bind" || bad "h10: layout-3 rung after the layout-2 NEXT step: rc=$R3 $(echo "$OUT3" | tail -2)"
fi
exit $rc
