#!/usr/bin/env bash
# test-5d-contract-truth.sh — god-review stage 5, Batch 5D: contract truth.
# Doc/consumer pins:
#
#   GU-KEEPVAULT-1     resolved-KEEP_VAULT conflicts route to `extend`-toward-
#                      vault (never a no-code verify); the CONFIRMED+CONFLICT
#                      halt is scoped to UNRESOLVED.
#   GU-SPLIT-DEPS-4    the SPLIT chain edge is a strict-deps evidence class.
#   GU-RISK-FIELD-1    the `risk:` frontmatter field is schema-defined with a
#                      named producer.
#   GU-PBT-REJECT-5    the properties-citation check exists as 12.5.h; pbt
#                      prose names it (no phantom render-pass claim).
#   GU-WHITELIST-6     target_files whitelist claims state the honest tier.
#   GU-HANDOFF-DRIFT-1 handoff blocks carry emitted_at + unit_oq_trace_missing
#                      and no legacy -bound example.
#   GU-MODFLAG-1       recovery routes use real surfaces (no --derive-modules /
#                      --refresh-modules phantom flags).
#   GU-GRAPH-CONFLICT-1 build-graph types CONFLICT refs as conflict nodes +
#                      carries state_reason/resolution (empirical).
#   + ATOMID, GCONF, SQUADREF, HALT-TAXO, PROBE-ANCHOR, RECONCILE-MATCH,
#     FORCECREATE-DEDUP pins.
#
# Run: bash tests/god-review-s5/test-5d-contract-truth.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
GU="${ROOT}/plugins/mega-sdd/skills/generate-units"
TT="$GU/references/task-typing.md"
US="$GU/references/unit-schema.md"
DR="$GU/references/decomposition-rails.md"
DG="$GU/references/defensive-generation.md"
HP="$GU/references/halt-protocol.md"
VP="$GU/references/validation-passes.md"
PBT="$GU/references/pbt-integration.md"
SKD="$GU/references/starterkit-derivation.md"
SK="$GU/SKILL.md"
HC="${ROOT}/plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md"
AAM="$GU/references/auto-and-memory.md"
MS="$GU/references/modules-schema.md"
BAF="${ROOT}/plugins/mega-sdd/skills/execute-bolts/references/batch-and-fanout.md"
BG="${ROOT}/plugins/mega-sdd/scripts/build-graph.sh"
HRP="${ROOT}/plugins/mega-sdd/skills/bind-codebase/references/hard-rules-and-packs.md"
for f in "$TT" "$US" "$DR" "$DG" "$HP" "$VP" "$PBT" "$SKD" "$SK" "$HC" "$AAM" "$MS" "$BAF" "$BG" "$HRP"; do
  [ -f "$f" ] || { echo "missing $f"; exit 1; }
done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t ct5d)"
trap 'rm -rf "$WORK"' EXIT

note "== 5D: contract truth =="

# ── GU-KEEPVAULT-1 ──
grep -qF 'resolved-KEEP_VAULT CONFLICT' "$TT" && grep -qF 'toward the VAULT claim' "$TT" \
  && ok "KEEPVAULT: task-typing routes resolved-KEEP_VAULT to extend-toward-vault" || fail "KEEPVAULT: route missing in task-typing"
grep -qF 'NEVER `verify`' "$TT" && ok "KEEPVAULT: no-code verify discharge explicitly forbidden" || fail "KEEPVAULT: verify discharge not forbidden"
grep -qF 'Mix of CONFIRMED + **unresolved** CONFLICT' "$TT" && ok "KEEPVAULT: halt scoped to UNRESOLVED conflicts" || fail "KEEPVAULT: halt still fires on resolved conflicts"
grep -qF 'unresolved CONFLICT → HALT' "$SK" && ok "KEEPVAULT: SKILL.md halt line scoped" || fail "KEEPVAULT: SKILL halt line stale"
grep -qF 'extend`-toward-vault' "$HRP" || grep -qF 'extend`-toward-vault' "$HRP" || grep -q 'extend.*toward.*vault' "$HRP" \
  && ok "KEEPVAULT: bind-side hard-rules ref names the carrier" || fail "KEEPVAULT: bind-side pointer missing"

# ── GU-SPLIT-DEPS-4 ──
grep -qF 'f. **SPLIT chain edge (Step 2.5 mandate)**' "$DR" && ok "SPLIT-DEPS: evidence class (f) exists for the mandated chain edge" || fail "SPLIT-DEPS: class (f) missing"

# ── GU-RISK-FIELD-1 ──
grep -qF 'risk: low | medium | high | critical' "$US" && ok "RISK: field defined in unit-schema (optional, enum)" || fail "RISK: field undefined"
grep -qF 'WRITTEN by Step 2.5' "$SK" && ok "RISK: SKILL names the producer" || fail "RISK: producer unnamed in SKILL"
grep -qF 'Who writes `risk:`' "$GU/references/adversarial-test-prompt.md" && ok "RISK: adversarial-test-prompt documents the producer" || fail "RISK: consumer doc lacks producer note"

# ── GU-PBT-REJECT-5 ──
grep -qF '### h. PBT properties citation check' "$VP" && ok "PBT: 12.5.h exists in validation-passes" || fail "PBT: 12.5.h missing"
grep -qF 'render-pass check 12.5.h (model-executed rule' "$PBT" && ok "PBT: pbt-integration names the real check + tier" || fail "PBT: phantom render-pass claim survives"

# ── GU-WHITELIST-6 ──
grep -qF 'no deterministic post-hoc observer' "$SK" && ok "WHITELIST: SKILL states the honest tier" || fail "WHITELIST: SKILL still claims enforcement"
grep -qF 'do not read "enforced" as a machine gate' "$US" && ok "WHITELIST: unit-schema states the honest tier" || fail "WHITELIST: unit-schema still claims enforcement"
grep -qF 'no deterministic post-hoc observer yet' "${ROOT}/plugins/mega-sdd/skills/execute-bolts/SKILL.md" && ok "WHITELIST: execute-bolts SKILL honest" || fail "WHITELIST: execute-bolts stale"

# ── GU-HANDOFF-DRIFT-1 ──
python3 - "$HC" <<'PY' && ok "HANDOFF: generate-units block has emitted_at + unit_oq_trace_missing + canonical paths" || fail "HANDOFF: contract block stale"
import re, sys
doc = open(sys.argv[1]).read()
m = re.search(r"### `generate-units`\n\n```yaml\n(.*?)```.*?Status `halted` on ([^\n]+)", doc, re.S)
assert m, "generate-units block not found"
block, halted = m.group(1), m.group(2)
ok = ("emitted_at:" in block and "<vault>/units/" in block
      and "unit_oq_trace_missing" in halted and "cross_module_dep_invalid" in halted)
sys.exit(0 if ok else 1)
PY
grep -qF 'unit_oq_trace_missing' "$AAM" && ok "HANDOFF: operative emission lists unit_oq_trace_missing" || fail "HANDOFF: auto-and-memory halted list stale"
if grep -qF '<vault>-bound/units (or' "$AAM"; then fail "HANDOFF: legacy -bound artifact example survives"; else ok "HANDOFF: artifact examples use the canonical nested path"; fi

# ── GU-MODFLAG-1 ──
if grep -rqF -- '--derive-modules' "${ROOT}/plugins/mega-sdd"; then fail "MODFLAG: phantom --derive-modules survives"; else ok "MODFLAG: --derive-modules eradicated"; fi
if grep -rqF -- '--refresh-modules' "${ROOT}/plugins/mega-sdd"; then fail "MODFLAG: phantom --refresh-modules survives"; else ok "MODFLAG: --refresh-modules eradicated"; fi
grep -qF 'mv _meta/modules.yaml.auto _meta/modules.yaml' "$MS" && ok "MODFLAG: modules-schema recovery = promote .auto" || fail "MODFLAG: recovery route missing"
grep -qF 'modules.yaml.auto` exists → instruct' "$BAF" && ok "MODFLAG: execute-bolts halt routes through the .auto promotion" || fail "MODFLAG: batch-and-fanout stale"

# ── GU-GRAPH-CONFLICT-1 (empirical) ──
F="$WORK/graph"; mkdir -p "$F/.mega-sdd/vaults/demo/units"
printf '{"vault_id": "demo", "version": "1.0"}\n' > "$F/.mega-sdd/vaults/demo/vault.json"
cat > "$F/.mega-sdd/vaults/demo/binding.json" <<'EOF'
{"schema_version": "1.0", "vault": "demo", "head": null,
 "claims": [{"id": "C-001", "verdict": "CONFIRMED", "state": "UNKNOWN",
             "state_reason": "truncated_section", "resolution": "KEEP_VAULT",
             "anchor": null, "confidence": "low", "field_diff": "n/a", "vault_source": null}]}
EOF
cat > "$F/.mega-sdd/vaults/demo/units/U-001.md" <<'EOF'
---
unit_id: U-001
title: T
task_type: extend
binding_refs:
  - C-001
  - CONFLICT-1
vault_source: x.md
target_files:
  - src/x.py
---
body
EOF
bash "${ROOT}/plugins/mega-sdd/scripts/build-graph.sh" --root "$F" >/dev/null 2>&1 || true
GJ="$F/.mega-sdd/graph.json"
if [ -f "$GJ" ]; then
  python3 - "$GJ" <<'PY' && ok "GRAPH: CONFLICT-1 typed 'conflict'; claim carries state_reason+resolution" || fail "GRAPH: node typing/attrs stale"
import json, sys
g = json.load(open(sys.argv[1]))
nodes = {n["id"]: n for n in g.get("nodes", [])}
conf = next((n for n in nodes.values() if n["id"].endswith(":CONFLICT-1")), None)
claim = next((n for n in nodes.values() if n["id"].endswith(":C-001")), None)
ok = (conf is not None and conf.get("type") == "conflict"
      and claim is not None
      and claim.get("attrs", {}).get("state_reason") == "truncated_section"
      and claim.get("attrs", {}).get("resolution") == "KEEP_VAULT")
sys.exit(0 if ok else 1)
PY
else
  fail "GRAPH: build-graph produced no graph.json on the fixture"
fi

# ── smaller pins ──
if grep -qF 'SPLIT into U-001, U-001.1, U-001.2' "$US"; then fail "ATOMID: dotted split-ID grammar survives"; else ok "ATOMID: dotted split IDs removed (sequential U-00N)"; fi
grep -qF 'for `verify`+HIGH it is PRESCRIPTIVE' "$DG" && ok "GCONF: grounding_confidence semantics reconciled with the A1 gate" || fail "GCONF: contradiction survives"
grep -qF 'generate-intent/references/squad-partition.md' "$DR" && grep -qF 'generate-intent/references/squad-partition.md' "$US" \
  && ok "SQUADREF: cross-skill ref form on both surfaces" || fail "SQUADREF: bare squad-partition.md ref survives"
if grep -qF 'HALT `target_files_collision`' "$DG"; then fail "HALT-TAXO: emitterless target_files_collision survives"; else ok "HALT-TAXO: stale alias renamed to dedup_ambiguous"; fi
grep -qF '## `verify` without anchor (binding gap)' "$HP" && ok "PROBE-ANCHOR: verify-without-anchor halt has YAML + entry" || fail "PROBE-ANCHOR: halt YAML missing"
if grep -qF 'downgrade-to-create only if no anchor exists' "$SK"; then fail "PROBE-ANCHOR: contradictory downgrade parenthetical survives"; else ok "PROBE-ANCHOR: SKILL parenthetical reconciled with the probe rule"; fi
grep -qF 'Second trigger (reconcile lane)' "$HP" && ok "RECONCILE: dedup_ambiguous second trigger documented" || fail "RECONCILE: reconcile trigger missing"
grep -qF 'matched by `binding_refs` → claim as the PRIMARY key' "$TT" && ok "RECONCILE: binding_refs is the primary match key" || fail "RECONCILE: match key stale"
grep -qF 'Exception (7.6 reconciliation)' "$VP" && ok "FORCECREATE: 12.6 honors the user's 7.6 force-create decision" || fail "FORCECREATE: double-vote survives"
if grep -qF -- '--force-overwrite (NOT YET IMPLEMENTED' "$HP"; then fail "FORCECREATE: phantom flag survives in halt-protocol"; else ok "FORCECREATE: phantom flag removed"; fi

if [ "$FAILED" -eq 0 ]; then note "ALL 5D OK"; else note "5D had failures"; fi
exit $FAILED
