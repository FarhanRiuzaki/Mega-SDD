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
#   GU-WHITELIST-6     target_files whitelist claims state the honest tier — since
#                      stage 6 the B3 observer SHIPPED, so every surface names
#                      `--whitelist-scan` AND encodes detect-after (blocks the
#                      NEXT execute-bolts, never the offending commit).
#   GU-HANDOFF-DRIFT-1 the unit walk's advertised halt list carries
#                      unit_oq_trace_missing and no legacy -bound example.
#   GU-MODFLAG-1       recovery routes use real surfaces (no --derive-modules /
#                      --refresh-modules phantom flags).
#   GU-GRAPH-CONFLICT-1 build-graph types CONFLICT refs as conflict nodes +
#                      carries state_reason/resolution (empirical).
#   + ATOMID, GCONF, SQUADREF, HALT-TAXO, PROBE-ANCHOR, RECONCILE-MATCH,
#     FORCECREATE-DEDUP pins.
#
# 9.0 P1 (classic skills removed — docs/superpowers/specs/2026-09-27-v9-simplification-design.md):
# the generate-units contracts these pins guard were relocated, so the pins follow them —
#   generate-units/SKILL.md + auto-and-memory.md  -> plan/references/unit-procedure.md
#   generate-units/references/{task-typing,unit-schema,decomposition-rails,validation-passes,
#     pbt-integration,adversarial-test-prompt}.md -> plan/references/<same>.md
#   generate-units/references/halt-protocol.md    -> references/halt-families/units.md
#   generate-units/references/modules-schema.md   -> references/modules-schema.md
# RETIRED (the pinned surface was deleted by design, no successor):
#   - the bind-codebase hard-rules-and-packs.md KEEP_VAULT carrier pointer (whole-vault
#     bind removed; its CONFLICT-derived Hard-rule step has no JIT-bind successor);
#   - the generate-units --auto handoff YAML (emitted_at + <vault>/units/ artifacts) —
#     plan emits no handoff ("No handoff YAML in this lane", plan/SKILL.md);
#   - the cross-skill `generate-intent/references/squad-partition.md` ref form (multi-squad
#     authoring retired, P1 decision 3) — repointed to "routing rules live in
#     decomposition-rails §Squad assignment, no ref to the deleted file";
#   - defensive-generation.md (deleted, not relocated) — GCONF / HALT-TAXO repointed to the
#     surviving grounding_confidence definition (unit-schema) and the 12.6 dedup owner.
#
# Run: bash tests/god-review-s5/test-5d-contract-truth.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PLAN="${ROOT}/plugins/mega-sdd/skills/plan"
TT="$PLAN/references/task-typing.md"
US="$PLAN/references/unit-schema.md"
DR="$PLAN/references/decomposition-rails.md"
VP="$PLAN/references/validation-passes.md"
PBT="$PLAN/references/pbt-integration.md"
ATP="$PLAN/references/adversarial-test-prompt.md"
UP="$PLAN/references/unit-procedure.md"      # successor of generate-units/SKILL.md + auto-and-memory.md
PSK="$PLAN/SKILL.md"
UH="${ROOT}/plugins/mega-sdd/references/halt-families/units.md"   # successor of generate-units halt-protocol.md
MS="${ROOT}/plugins/mega-sdd/references/modules-schema.md"
BAF="${ROOT}/plugins/mega-sdd/skills/execute-bolts/references/batch-and-fanout.md"
BG="${ROOT}/plugins/mega-sdd/scripts/build-graph.sh"
EBS="${ROOT}/plugins/mega-sdd/skills/execute-bolts/SKILL.md"
for f in "$TT" "$US" "$DR" "$VP" "$PBT" "$ATP" "$UP" "$PSK" "$UH" "$MS" "$BAF" "$BG" "$EBS"; do
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
# 9.0: the unit walk's halt index (ex generate-units SKILL.md) scopes the gate to UNRESOLVED
# conflicts and closes it in execute-bolts (no binding exists at plan time; 9.x: the inline default
# quarantines before the build; the per-dispatch gate was removed in P3, spec §8.6).
grep -qF '**Unresolved CONFLICT → the gate closes in execute-bolts**' "$UP" \
  && ok "KEEPVAULT: unit-procedure halt line scoped to unresolved" || fail "KEEPVAULT: unit-procedure halt line stale"
# (retired 9.0: the bind-codebase hard-rules-and-packs.md carrier pointer — bind-codebase deleted.)

# ── GU-SPLIT-DEPS-4 ──
grep -qF 'f. **SPLIT chain edge (Step 2.5 mandate)**' "$DR" && ok "SPLIT-DEPS: evidence class (f) exists for the mandated chain edge" || fail "SPLIT-DEPS: class (f) missing"

# ── GU-RISK-FIELD-1 ──
grep -qF 'risk: low | medium | high | critical' "$US" && ok "RISK: field defined in unit-schema (optional, enum)" || fail "RISK: field undefined"
grep -qF 'WRITTEN by Step 2.5' "$UP" && ok "RISK: unit-procedure names the producer" || fail "RISK: producer unnamed in unit-procedure"
grep -qF 'Who writes `risk:`' "$ATP" && ok "RISK: adversarial-test-prompt documents the producer" || fail "RISK: consumer doc lacks producer note"

# ── GU-PBT-REJECT-5 ──
grep -qF '### h. PBT properties citation check' "$VP" && ok "PBT: 12.5.h exists in validation-passes" || fail "PBT: 12.5.h missing"
grep -qF 'render-pass check 12.5.h (model-executed rule' "$PBT" && ok "PBT: pbt-integration names the real check + tier" || fail "PBT: phantom render-pass claim survives"

# ── GU-WHITELIST-6 ──
# Stage 6 shipped the deterministic B3 whitelist observer. The honest tier is no
# longer "no observer exists" — it is "the observer is detect-after": it blocks the
# NEXT execute-bolts, it does NOT prevent the offending commit. Each surface must
# name the observer AND carry that detect-after phrasing (guards against a regression
# back to the stage-5 over-claim of prevent-the-write / block-the-commit).
WL_DETECT_AFTER='block the next `execute-bolts` with `whitelist_violation`'
for pair in "plan unit-procedure:$UP" "unit-schema:$US" "execute-bolts SKILL:$EBS"; do
  wl_name="${pair%%:*}"; wl_f="${pair#*:}"
  if grep -qF -- '--whitelist-scan' "$wl_f" && grep -qF -- "$WL_DETECT_AFTER" "$wl_f"; then
    ok "WHITELIST: $wl_name names the B3 observer with detect-after honesty"
  else
    fail "WHITELIST: $wl_name stale — must name --whitelist-scan AND encode detect-after"
  fi
  if grep -qiE 'prevents the (out-of-whitelist )?write|blocks the (offending )?commit' "$wl_f"; then
    fail "WHITELIST: $wl_name re-introduces the stage-5 over-claim (B3 is detect-after, not prevent)"
  fi
done

# ── GU-HANDOFF-DRIFT-1 ── 9.0: generate-units (and its auto-and-memory.md --auto handoff
# YAML) is gone; `plan` emits NO handoff — the front door re-derives state from disk. The
# emitted_at / <vault>/units/ artifact-path assertions on that YAML are RETIRED. The drift
# this pin caught (the phase's advertised halt list omitting unit_oq_trace_missing /
# cross_module_dep_invalid) survives on plan/SKILL.md's halt list — pinned on the SAME line.
grep -qF 'No handoff YAML in this lane' "$PSK" \
  && ok "HANDOFF: plan states it emits no handoff YAML (state re-derived from disk)" || fail "HANDOFF: plan handoff contract unstated"
python3 - "$PSK" <<'PY' && ok "HANDOFF: plan halt list carries unit_oq_trace_missing + cross_module_dep_invalid" || fail "HANDOFF: plan halt list stale"
import sys
lines = [l for l in open(sys.argv[1]) if "`emitted_by: plan`" in l and "Every halt emits" in l]
ok = bool(lines) and all("`unit_oq_trace_missing`" in l and "`cross_module_dep_invalid`" in l for l in lines)
sys.exit(0 if ok else 1)
PY
grep -qF 'Implementation-relevant OQ-ID absent from `binding_refs` → `unit_oq_trace_missing`' "$UP" \
  && ok "HANDOFF: unit-procedure halt index lists unit_oq_trace_missing" || fail "HANDOFF: unit-procedure halt index stale"
if grep -rqF '<vault>-bound/units (or' "$PLAN"; then fail "HANDOFF: legacy -bound artifact example survives"; else ok "HANDOFF: artifact examples use the canonical nested path"; fi

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
# GCONF — 9.0: defensive-generation.md (the file that carried the "descriptive, not
# prescriptive" contradiction AND its fix) was deleted, not relocated. The surviving owner of
# grounding_confidence semantics is the unit-schema definition: it must name the A1 gate as the
# enforcer for verify+HIGH, and no surviving plan doc may re-claim the field never gates.
grep -qF 'Enforced: validate-unit-spec.sh halt verify_grounding_untrusted (HIGH verify units only).' "$US" \
  && ok "GCONF: grounding_confidence definition names the A1 gate for verify+HIGH" || fail "GCONF: unit-schema lost the A1 enforcement note"
if grep -rqiE 'grounding_confidence.{0,40}not prescriptive' "$PLAN"; then fail "GCONF: contradiction survives (grounding_confidence claimed non-gating)"; else ok "GCONF: no 'not prescriptive' contradiction on the plan surfaces"; fi
# SQUADREF — 9.0: squad authoring retired (P1 decision 3); generate-intent/references/
# squad-partition.md is deleted, so the routing rules' home is decomposition-rails §Squad
# assignment. Both surfaces must point at a RESOLVABLE home — never the deleted file.
grep -qF '## Squad assignment (Step 5)' "$DR" && grep -qF 'decomposition-rails.md §Squad assignment' "$US" \
  && grep -qF 'decomposition-rails.md §Squad assignment' "$UP" \
  && ok "SQUADREF: squad routing refs resolve to decomposition-rails §Squad assignment" || fail "SQUADREF: squad routing ref unresolvable"
if grep -qF 'squad-partition.md' "$DR" "$US" "$UP"; then fail "SQUADREF: ref to the deleted squad-partition.md survives"; else ok "SQUADREF: no ref to the deleted squad-partition.md"; fi
# HALT-TAXO — 9.0: the 12.6 dedup owner is unit-procedure; the negative covers every
# surviving unit-halt surface (plan/, the units halt family, the registry).
grep -qF 'A `create` unit whose `target_files` ALL already exist → halt `dedup_ambiguous`' "$UP" \
  && ok "HALT-TAXO: 12.6 collision halts under the canonical dedup_ambiguous" || fail "HALT-TAXO: 12.6 canonical halt name missing"
if grep -rqF 'HALT `target_files_collision`' "$PLAN" "$UH" "${ROOT}/plugins/mega-sdd/references/halt-protocol.md"; then fail "HALT-TAXO: emitterless target_files_collision survives"; else ok "HALT-TAXO: stale alias renamed to dedup_ambiguous"; fi
# PROBE-ANCHOR — the verify-without-anchor blocker moved to references/halt-families/units.md
# (entry + YAML); plan-time anchors come from the symbol index, so the gap is an "anchor gap".
python3 - "$UH" <<'PY2' && ok "PROBE-ANCHOR: verify-without-anchor halt has YAML + entry" || fail "PROBE-ANCHOR: halt YAML missing"
import re, sys
doc = open(sys.argv[1]).read()
m = re.search(r"\*\*Blocker shape — `verify` without anchor \(anchor gap\)\*\*[^\n]*\n+```yaml\n(.*?)```", doc, re.S)
ok = bool(m) and "type: unit_underspecified" in m.group(1) and "task_type=verify assigned but no anchor exists" in m.group(1)
sys.exit(0 if ok else 1)
PY2
if grep -rqF 'downgrade-to-create only if no anchor exists' "$PLAN"; then fail "PROBE-ANCHOR: contradictory downgrade parenthetical survives"; else ok "PROBE-ANCHOR: unit-walk parenthetical reconciled with the probe rule"; fi
grep -qF 'Second trigger (reconcile lane)' "$UH" && ok "RECONCILE: dedup_ambiguous second trigger documented" || fail "RECONCILE: reconcile trigger missing"
# RECONCILE match key — 9.0: the whole-vault binding.md is gone; each unit's claims are minted
# from the unit itself into its OWN bolts/U-XXX/binding.json, so the reconcile key is the unit's
# own evidence file (SPLIT siblings sharing one context_source can never cross-match — the
# property the old "binding_refs → claim PRIMARY key" pin guarded).
grep -qF 'Per existing unit (its evidence is its OWN `bolts/U-XXX/binding.json`' "$TT" \
  && ok "RECONCILE: per-unit binding.json is the reconcile match key" || fail "RECONCILE: match key stale"
grep -qF 'Exception (7.6 reconciliation)' "$VP" && ok "FORCECREATE: 12.6 honors the user's 7.6 force-create decision" || fail "FORCECREATE: double-vote survives"
if grep -qF -- '--force-overwrite (NOT YET IMPLEMENTED' "$UH" "${ROOT}/plugins/mega-sdd/references/halt-protocol.md"; then fail "FORCECREATE: phantom flag survives in halt-protocol"; else ok "FORCECREATE: phantom flag removed"; fi

if [ "$FAILED" -eq 0 ]; then note "ALL 5D OK"; else note "5D had failures"; fi
exit $FAILED
