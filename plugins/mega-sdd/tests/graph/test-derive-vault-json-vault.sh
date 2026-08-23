#!/usr/bin/env bash
# test-derive-vault-json-vault.sh — batch2 W5 (spec 2026-07-19-batch2-derive-and-diet.md):
# vault.json is DERIVED from the 7 vault markdown files by
# scripts/derive-vault-json.sh — never re-typed by the model. Cases:
#
#   1  round-trip: fixture vault + authored patch → exit 0, PASS line counts;
#      json-equality vs the checked-in expected vault.json (Purpose comment +
#      full-mode fallback; flow type/dod_count/source_acs/_kb_source; ADR
#      default accepted + Superseded mapping; OQ status/category/mode/conf/
#      text/resolution/oos-reason/deferred-reason/resolver_owner; summary;
#      constitution_hash == python3-hashlib recompute; bracket-first category
#      + roll-up fallback; OQ annotation position pins — a resolved OQ that is
#      NOT the last line of its doc keeps its resolution; bold '**Deferred**'
#      inside a question text stays status=open with the text intact; a
#      genuinely deferred OQ mid-doc keeps its deferred_reason)
#   2  idempotency: second run byte-identical INCLUDING generated_at
#   3  malformed → exit 2, vault.json untouched: duplicate flow id; duplicate
#      OQ tag across docs; patch setting a derived key; patch setting a
#      derived per-OQ key; invalid --event; cross-count guard trip
#   4  lock: stale vault.json.lock → exit 4; lock released after a normal run
#   5  carry-forward: design_system_flags / design_system / legacy advisor (no writer since v7.4.0) / title /
#      legacy mode (contradicting md implementation_mode — carried verbatim,
#      never reconciled) / scope block / prd_sha256 / recommend-OQ JSON-only
#      fields / changelog ALL preserved verbatim
#   6  resolve-oq sim: [ ]→[x] + --event oq-resolved → status/resolution/
#      resolved_at/summary/changelog; transition-only stamping on re-derive
#   7  --patch defer_to lands per-entry; defer_to:binding orphan created via
#      patch survives later derives with WARN (amendment §2)
#   8  prd_sha256 + constitution_hash byte-identical across 5 derives; WARN
#      (not recompute) when constitution.md drifts; fresh-computed when absent
#   9  consumer-green sweep: build-graph flow nodes; validate-preflight
#      bind-codebase; validate-vault-oqs PASS on good / FAIL
#      oq_recommend_underspecified on stripped-recommend variant;
#      the --modules rollup + analyze-parallelism do not die
#  10  grammar parity: vault_md.OQ_TAG_RE / CATEGORY_BRACKET_RE patterns
#      byte-identical to the validator's pre-refactor strings; numeric OQ-001
#      tag parses (amendment §3); validator behavior unchanged on the
#      operator-ux fixtures
#  11  usage: no --vault → exit 3
#
# Run: bash plugins/mega-sdd/tests/graph/test-derive-vault-json-vault.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DERIVE="${PLUGIN_ROOT}/scripts/derive-vault-json.sh"
FX="${SCRIPT_DIR}/fixtures/derive-vault"
[ -f "$DERIVE" ] || { echo "missing $DERIVE"; exit 1; }
[ -d "$FX" ] || { echo "missing fixture dir $FX"; exit 1; }

FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t w5derive)"
trap 'rm -rf "$WORK"' EXIT

seed_vault() {  # <dir> — copy the fixture md set (no vault.json)
  mkdir -p "$1"
  cp "$FX"/0*.md "$FX/constitution.md" "$1/"
}

json_eq_ignoring_stamps() {  # <derived> <expected> — pop generated_at + per-OQ transition stamps
  python3 - "$1" "$2" <<'PY'
import json, sys
a = json.load(open(sys.argv[1], encoding="utf-8"))
b = json.load(open(sys.argv[2], encoding="utf-8"))
for d in (a, b):
    d.pop("generated_at", None)
    for oq in d.get("open_questions", []):
        oq.pop("resolved_at", None)
        oq.pop("deferred_at", None)
sys.exit(0 if a == b else 1)
PY
}

echo "== W5: derive-vault-json =="

# ── 1. round-trip vs checked-in expected json ──
V1="$WORK/v1"; seed_vault "$V1"
OUT=$(bash "$DERIVE" --vault "$V1" --patch "$FX/authored-patch.json" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -qF "PASS: derived vault.json (2 entities, 2 flows, 2 adrs, 7 oqs)" \
  && ok "1: fixture derive exits 0 with the counted PASS line" \
  || fail "1: derive rc=$RC out: $(echo "$OUT" | head -3)"
json_eq_ignoring_stamps "$V1/vault.json" "$FX/expected-vault.json" \
  && ok "1: derived json equals checked-in expected (entities/flows/adrs/OQ skeletons + authored patch merge)" \
  || fail "1: derived json diverges from expected"
python3 - "$V1/vault.json" <<'PY' && ok "1: OQ annotation position pins — mid-doc resolution kept; bold Deferred-in-text stays open; mid-doc deferred_reason kept" || fail "1: OQ annotation position pin broken"
import json, sys
oq = {o["tag"]: o for o in json.load(open(sys.argv[1]))["open_questions"]}
# a resolved OQ that is NOT the last line of its doc keeps its resolution
assert oq["OQ-DM-1"]["status"] == "resolved" and oq["OQ-DM-1"]["resolution"] == "UUID."
# bold '**Deferred**' inside the question text: status stays open, text intact
assert oq["OQ-CN-3"]["status"] == "open"
assert oq["OQ-CN-3"]["text"] == "how should **Deferred** settlement deep-links batch?"
assert "deferred_reason" not in oq["OQ-CN-3"] and "deferred_at" not in oq["OQ-CN-3"]
# a genuinely deferred OQ mid-doc (content follows) keeps its deferred_reason
assert oq["OQ-CN-4"]["status"] == "deferred"
assert oq["OQ-CN-4"]["deferred_reason"] == "waiting on legal review"
assert oq["OQ-CN-4"]["text"] == "data retention period?"
sys.exit(0)
PY
python3 - "$V1/vault.json" "$FX/constitution.md" <<'PY' && ok "1: constitution_hash equals hashlib recompute; transition stamps present" || fail "1: constitution_hash / transition stamps wrong"
import hashlib, json, sys
d = json.load(open(sys.argv[1]))
assert d["constitution_hash"] == hashlib.sha256(open(sys.argv[2], "rb").read()).hexdigest()
oq = {o["tag"]: o for o in d["open_questions"]}
assert oq["OQ-DM-1"].get("resolved_at"), "resolved_at not stamped"
assert oq["OQ-AR-7"].get("deferred_at"), "deferred_at not stamped"
sys.exit(0)
PY

# ── 2. idempotency: byte-identical re-derive INCLUDING generated_at ──
SUM1=$(python3 -c "import hashlib;print(hashlib.sha256(open('$V1/vault.json','rb').read()).hexdigest())")
sleep 1
bash "$DERIVE" --vault "$V1" --patch "$FX/authored-patch.json" </dev/null >/dev/null 2>&1 || fail "2: re-derive failed"
SUM2=$(python3 -c "import hashlib;print(hashlib.sha256(open('$V1/vault.json','rb').read()).hexdigest())")
[ "$SUM1" = "$SUM2" ] && ok "2: no-op re-derive byte-identical (generated_at preserved — doc-control sha stable)" \
  || fail "2: re-derive churned the file"
[ -f "$V1/vault.json.tmp" ] && fail "2: tmp file left behind (non-atomic write)" || ok "2: atomic replace (no tmp litter)"

# ── 3. malformed cases → exit 2, vault.json untouched ──
V3="$WORK/v3"; seed_vault "$V3"
printf '\n### F-U-001: duplicate id\n\n**Definition of Done**:\n- [ ] x\n' >> "$V3/04-flows.md"
OUT=$(bash "$DERIVE" --vault "$V3" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -qF "duplicate flow id" && [ ! -f "$V3/vault.json" ] \
  && ok "3a: duplicate flow id → exit 2, json NOT written" \
  || fail "3a: duplicate-flow handling wrong (rc=$RC)"
V3B="$WORK/v3b"; seed_vault "$V3B"
printf '\n## Open Questions\n- [ ] **OQ-DM-1** [P1]: duplicated in another doc\n' >> "$V3B/06-constraints.md"
OUT=$(bash "$DERIVE" --vault "$V3B" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -qF "duplicate OQ tag" && [ ! -f "$V3B/vault.json" ] \
  && ok "3b: duplicate OQ tag across docs → exit 2" \
  || fail "3b: duplicate-OQ handling wrong (rc=$RC)"
V3C="$WORK/v3c"; seed_vault "$V3C"
echo '{"entities": []}' > "$WORK/bad-top.json"
OUT=$(bash "$DERIVE" --vault "$V3C" --patch "$WORK/bad-top.json" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -qF "derived key 'entities'" && [ ! -f "$V3C/vault.json" ] \
  && ok "3c: patch setting a derived top-level key → exit 2 (anti-laundering)" \
  || fail "3c: derived-key patch accepted (rc=$RC)"
echo '{"open_questions": {"OQ-AR-1": {"status": "resolved"}}}' > "$WORK/bad-oq.json"
OUT=$(bash "$DERIVE" --vault "$V3C" --patch "$WORK/bad-oq.json" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -qF "derived per-OQ key" \
  && ok "3d: patch setting a derived per-OQ key (status) → exit 2" \
  || fail "3d: derived per-OQ patch accepted (rc=$RC)"
OUT=$(bash "$DERIVE" --vault "$V3C" --event 'not-json' </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && ok "3e: invalid --event → exit 2" || fail "3e: invalid event accepted (rc=$RC)"
OUT=$(bash "$DERIVE" --vault "$V3C" --event '{"no_event_key": 1}' </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && ok "3f: --event without 'event' key → exit 2" || fail "3f: schemaless event accepted (rc=$RC)"
V3G="$WORK/v3g"; seed_vault "$V3G"
# Tables OUTSIDE a ```dbml fence: loose count sees them, the fence parser does
# not → the anti-silent-empty guard must trip instead of deriving thin arrays.
printf '\nTable ghost_a {\n  id bigint\n}\nTable ghost_b {\n  id bigint\n}\nTable ghost_c {\n  id bigint\n}\n' >> "$V3G/03-data-model.md"
OUT=$(bash "$DERIVE" --vault "$V3G" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && echo "$OUT" | grep -qF "cross-count guard tripped on entities" && [ ! -f "$V3G/vault.json" ] \
  && ok "3g: unfenced Tables → cross-count guard exit 2 (never a silently thin json)" \
  || fail "3g: cross-count guard missing (rc=$RC): $(echo "$OUT" | head -2)"

# ── 4. lock semantics ──
V4="$WORK/v4"; seed_vault "$V4"
touch "$V4/vault.json.lock"
OUT=$(bash "$DERIVE" --vault "$V4" </dev/null 2>&1); RC=$?
[ "$RC" -eq 4 ] && echo "$OUT" | grep -qF "vault.json.lock held" \
  && ok "4: stale lock → exit 4 (skill maps to memory_in_use; stderr carries the orphan hint)" \
  || fail "4: lock-held exit wrong (rc=$RC)"
rm -f "$V4/vault.json.lock"
bash "$DERIVE" --vault "$V4" </dev/null >/dev/null 2>&1
[ ! -f "$V4/vault.json.lock" ] && ok "4: lock released after a normal run" || fail "4: lock leaked"

# ── 5. carry-forward lane (incl. the contradictory mode fixture, amendment §3) ──
V5="$WORK/v5"; seed_vault "$V5"
bash "$DERIVE" --vault "$V5" --patch "$FX/authored-patch.json" </dev/null >/dev/null 2>&1
python3 - "$V5/vault.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["mode"] = "existing"                       # legacy field CONTRADICTING md implementation_mode: new
d["prd_sha256"] = "pinned-sha-abc123"
d["prd_path_at_generation"] = "./prd.md"
d["scope"] = "BE"
d["scope_metadata"] = {"id": "BE", "name": "Backend API"}
d["design_system"] = {"style": "minimalism", "source": "prd", "provenance": "PRD §9"}
d["changelog"] = [{"event": "generated", "at": "2026-07-19T00:00:00Z"}]
d["custom_future_key"] = {"keep": "me"}
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False); open(p, "a").write("\n")
PY
bash "$DERIVE" --vault "$V5" </dev/null >/dev/null 2>&1; RC=$?
python3 - "$V5/vault.json" <<'PY' && [ "$RC" -eq 0 ] && ok "5: authored fields ALL preserved verbatim; mode:existing carried while implementation_mode:new (never reconciled)" || fail "5: carry-forward lost a field (rc=$RC)"
import json, sys
d = json.load(open(sys.argv[1]))
oq7 = [o for o in d["open_questions"] if o["tag"] == "OQ-AR-7"][0]
assert d["mode"] == "existing" and d["implementation_mode"] == "new"
assert d["prd_sha256"] == "pinned-sha-abc123" and d["prd_path_at_generation"] == "./prd.md"
assert d["scope"] == "BE" and d["scope_metadata"]["name"] == "Backend API"
assert d["title"] == "Demo Leave System"
assert d["design_system_flags"]["HAS_UI_COMPONENTS"] is False
assert d["design_system"]["style"] == "minimalism"
assert d["advisor"]["model"] == "demo"
assert d["custom_future_key"] == {"keep": "me"}
assert d["changelog"][0]["event"] == "generated"
assert oq7["recommendation"] == "Use RFC 7807 problem+json envelope"
assert oq7["scan_citations"] == ["app/Http/Resources/ErrorResource.php:12"]
assert oq7["fallback_if_wrong"] == "Revisit with JSON:API error format"
sys.exit(0)
PY

# ── 6. resolve-oq simulation: md edit + --event → derive effects the fields ──
python3 - "$V5/02-architecture.md" "$V5/00-index.md" <<'PY'
import sys
old = "- [ ] **OQ-AR-1** [P1] [tech / scan] [conf: high]: which test framework? — resolve: scan codebase-map §test_frameworks"
new = "- [x] **OQ-AR-1** [P1] [tech / scan] [conf: high]: which test framework? → **Resolved v1.2** (2026-07-19): PHPUnit 11."
for p in sys.argv[1:]:
    s = open(p, encoding="utf-8").read()
    open(p, "w", encoding="utf-8").write(s.replace(old, new).replace(old + " `[02-architecture.md]`", new))
PY
bash "$DERIVE" --vault "$V5" --event '{"event":"oq-resolved","id":"OQ-AR-1","at":"2026-07-19T10:00:00Z","action":"A"}' </dev/null >/dev/null 2>&1; RC=$?
STAMP=$(python3 -c "
import json; d=json.load(open('$V5/vault.json'))
oq=[o for o in d['open_questions'] if o['tag']=='OQ-AR-1'][0]
assert oq['status']=='resolved' and oq['resolution']=='PHPUnit 11.'
assert oq['scan_query'] == 'codebase-map §test_frameworks'
assert d['open_questions_summary']['by_status']['resolved']==2
assert [e['event'] for e in d['changelog']]==['generated','oq-resolved']
print(oq['resolved_at'])") && [ "$RC" -eq 0 ] \
  && ok "6: [ ]→[x] + --event → status/resolution derived, resolved_at stamped, summary shifted, changelog grew, scan_query carried" \
  || fail "6: resolve-oq simulation wrong (rc=$RC)"
sleep 1
bash "$DERIVE" --vault "$V5" </dev/null >/dev/null 2>&1
python3 -c "
import json,sys; d=json.load(open('$V5/vault.json'))
oq=[o for o in d['open_questions'] if o['tag']=='OQ-AR-1'][0]
sys.exit(0 if oq['resolved_at']=='$STAMP' else 1)" \
  && ok "6: transition-only stamping — resolved_at unchanged on re-derive" \
  || fail "6: resolved_at restamped without a transition"

# ── 7. defer_to patch: per-entry landing + binding orphan preserve (amendment §2) ──
echo '{"open_questions": {"OQ-AR-7": {"defer_to": "stakeholder"}}}' > "$WORK/defer.json"
bash "$DERIVE" --vault "$V5" --patch "$WORK/defer.json" </dev/null >/dev/null 2>&1
python3 -c "
import json,sys; d=json.load(open('$V5/vault.json'))
oq={o['tag']:o for o in d['open_questions']}
sys.exit(0 if oq['OQ-AR-7'].get('defer_to')=='stakeholder' and 'defer_to' not in oq['OQ-FL-2'] else 1)" \
  && ok "7: --patch defer_to lands in the named entry only" \
  || fail "7: defer_to patch leaked or missed"
echo '{"open_questions": {"OQ-013": {"defer_to": "binding", "status": "deferred", "priority": "P2", "text": "demoted CONFLICT-2", "deferred_reason": "DEFER at binding walk"}}}' > "$WORK/orphan.json"
bash "$DERIVE" --vault "$V5" --patch "$WORK/orphan.json" </dev/null >/dev/null 2>&1; RC=$?
ERR=$(bash "$DERIVE" --vault "$V5" </dev/null 2>&1 >/dev/null); RC2=$?
python3 -c "
import json,sys; d=json.load(open('$V5/vault.json'))
oq=[o for o in d['open_questions'] if o.get('tag')=='OQ-013']
sys.exit(0 if oq and oq[0]['defer_to']=='binding' and oq[0].get('deferred_at') else 1)" \
  && [ "$RC" -eq 0 ] && [ "$RC2" -eq 0 ] && echo "$ERR" | grep -qF "no markdown home (defer_to: binding)" \
  && ok "7: defer_to:binding orphan (numeric OQ-013 tag) created via patch, SURVIVES a later derive with WARN" \
  || fail "7: binding orphan dropped or WARN missing (rc=$RC/$RC2)"

# ── 8. at-generation pins stable across 5 derives; constitution drift WARNs ──
PIN1=$(python3 -c "import json;d=json.load(open('$V5/vault.json'));print(d['prd_sha256'],d['constitution_hash'])")
for i in 1 2 3 4 5; do bash "$DERIVE" --vault "$V5" </dev/null >/dev/null 2>&1; done
PIN2=$(python3 -c "import json;d=json.load(open('$V5/vault.json'));print(d['prd_sha256'],d['constitution_hash'])")
[ "$PIN1" = "$PIN2" ] && ok "8: prd_sha256 + constitution_hash byte-identical across 5 derives (never recomputed)" \
  || fail "8: an at-generation pin drifted across derives"
printf '\n- A-002: appended after generation (source: PRD)\n' >> "$V5/constitution.md"
ERR=$(bash "$DERIVE" --vault "$V5" </dev/null 2>&1 >/dev/null); RC=$?
PIN3=$(python3 -c "import json;print(json.load(open('$V5/vault.json'))['constitution_hash'])")
[ "$RC" -eq 0 ] && echo "$ERR" | grep -qF "constitution.md content differs from the pinned constitution_hash" \
  && [ "$PIN3" = "${PIN1##* }" ] \
  && ok "8: hand-edited constitution → WARN + hash CARRIED (drift telemetry, not re-baseline)" \
  || fail "8: constitution drift handling wrong (rc=$RC)"
V8="$WORK/v8"; seed_vault "$V8"
python3 - "$V8" <<'PY'
import json, os, sys
# prior json WITHOUT constitution fields → initial-generation compute path
json.dump({"title": "seed"}, open(os.path.join(sys.argv[1], "vault.json"), "w"))
PY
bash "$DERIVE" --vault "$V8" </dev/null >/dev/null 2>&1
python3 -c "
import hashlib, json, sys
d = json.load(open('$V8/vault.json'))
h = hashlib.sha256(open('$V8/constitution.md','rb').read()).hexdigest()
sys.exit(0 if d['constitution_hash']==h and d['constitution_version']=='1.0' else 1)" \
  && ok "8: absent pin → computed fresh from constitution.md (initial generation)" \
  || fail "8: fresh-compute path broken"

# ── 9. consumer-green sweep over the derived fixture ──
PROJ="$WORK/proj"; mkdir -p "$PROJ/.mega-sdd/vaults" "$PROJ/.mega-sdd/codebase"
cp -R "$V1" "$PROJ/.mega-sdd/vaults/demo"
printf '# Codebase Map\n\n## 1. Entities\n- user\n' > "$PROJ/.mega-sdd/codebase/codebase-map.md"
mkdir -p "$PROJ/.mega-sdd/vaults/demo/units"
printf -- '---\nmodule: "M-demo"\n---\n# Unit U-001\n\nPlaceholder.\n' > "$PROJ/.mega-sdd/vaults/demo/units/U-001.md"
bash "${PLUGIN_ROOT}/scripts/build-graph.sh" --root "$PROJ" </dev/null >/dev/null 2>&1; RC=$?
python3 -c "
import json,sys; g=json.load(open('$PROJ/.mega-sdd/graph.json'))
ids=[n.get('id','') for n in g.get('nodes',[])]
sys.exit(0 if any('F-U-001' in i for i in ids) and any('F-S-002' in i for i in ids) else 1)" \
  && [ "$RC" -eq 0 ] && ok "9: build-graph exits 0 and emits both flow nodes from the derived json" \
  || fail "9: build-graph consumer broken (rc=$RC)"
bash "${PLUGIN_ROOT}/scripts/validate-preflight.sh" --cwd="$PROJ" --skill=mega-sdd:bind-codebase --quiet </dev/null; RC=$?
[ "$RC" -eq 0 ] && ok "9: validate-preflight bind-codebase sees the derived vault" \
  || fail "9: preflight consumer broken (rc=$RC)"
bash "${PLUGIN_ROOT}/scripts/validate-vault-oqs.sh" --cwd="$PROJ" --file-path="$PROJ/.mega-sdd/vaults/demo/02-architecture.md" --quiet </dev/null; RC=$?
[ "$RC" -eq 0 ] && ok "9: validate-vault-oqs exits 0 on the good derived fixture" \
  || fail "9: validator rejects the good derived fixture (rc=$RC)"
python3 - "$PROJ/.mega-sdd/vaults/demo/vault.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
for oq in d["open_questions"]:
    if oq["tag"] == "OQ-AR-7":
        for k in ("recommendation", "rationale", "scan_citations", "fallback_if_wrong"):
            oq.pop(k, None)
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
PY
bash "${PLUGIN_ROOT}/scripts/validate-vault-oqs.sh" --cwd="$PROJ" --file-path="$PROJ/.mega-sdd/vaults/demo/02-architecture.md" --quiet </dev/null; RC=$?
python3 -c "
import json,sys; s=json.load(open('$PROJ/.mega-sdd/.vault-oqs-state.json'))
sys.exit(0 if any(i['halt_type']=='oq_recommend_underspecified' for i in s['issues']) else 1)" \
  && [ "$RC" -eq 1 ] && ok "9: stripped recommend fields → oq_recommend_underspecified fires (structured-authority tripwire for a lossy merge)" \
  || fail "9: lossy-merge tripwire dead (rc=$RC)"
bash "${PLUGIN_ROOT}/scripts/query-graph.sh" --modules "$PROJ/.mega-sdd/vaults/demo" --cwd="$PROJ" --format=json </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "9: the --modules rollup does not die on the derived json" || fail "9: the --modules rollup died (rc=$RC)"
bash "${PLUGIN_ROOT}/scripts/analyze-parallelism.sh" "$PROJ/.mega-sdd/vaults/demo" --cwd="$PROJ" --format=json </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "9: analyze-parallelism does not die on the derived json" || fail "9: analyze-parallelism died (rc=$RC)"

# ── 10. grammar parity (two-validators-one-grammar pins) ──
MEGA_SDD_LIB_DIR="${PLUGIN_ROOT}/scripts/_lib" python3 - <<'PY' && ok "10: OQ_TAG_RE + CATEGORY_BRACKET_RE byte-identical to the validator's pre-refactor strings; numeric OQ-001 parses" || fail "10: grammar parity pin broken"
import os, sys
sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_md
assert vault_md.OQ_TAG_RE.pattern == r"\bOQ-(?:[A-Z]+(?:-[A-Z0-9]+)*-)?\d+\b"
assert vault_md.CATEGORY_BRACKET_RE.pattern == '\\[\\s*tech\\b|"category"\\s*:\\s*"tech"'
assert vault_md.CATEGORY_BRACKET_BUSINESS_RE.pattern == '\\[\\s*business\\b|"category"\\s*:\\s*"business"'
m = vault_md.OQ_LINE_RE.match("- [ ] **OQ-001** [P1]: numeric bind-form tag")
assert m and m.group(2) == "OQ-001"
sys.exit(0)
PY
V10="$WORK/v10"; seed_vault "$V10"
printf '\n## Open Questions\n- [ ] **OQ-001** [P1]: numeric bind-form tag parses\n' >> "$V10/06-constraints.md"
OUT=$(bash "$DERIVE" --vault "$V10" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -qF "8 oqs" \
  && ok "10: numeric OQ-001 tag derives (no false cross-count exit 2 — amendment §3)" \
  || fail "10: numeric tag handling wrong (rc=$RC): $OUT"
REPO_ROOT="$(cd "${PLUGIN_ROOT}/../.." && pwd)"
if [ -d "$REPO_ROOT/tests/fixtures/code-delivery/operator-ux" ]; then
  for pair in good:0:PASS bad:1:FAIL; do
    fx="${pair%%:*}"; rest="${pair#*:}"; want_rc="${rest%%:*}"; want_st="${rest#*:}"
    SRC="$REPO_ROOT/tests/fixtures/code-delivery/operator-ux/$fx"
    DST="$WORK/oux-$fx"; mkdir -p "$DST"; cp -R "$SRC/.mega-sdd" "$DST/"
    bash "${PLUGIN_ROOT}/scripts/validate-vault-oqs.sh" --cwd="$DST" --file-path="$DST/.mega-sdd/vaults/demo-phase/02-architecture.md" --quiet </dev/null; RC=$?
    ST=$(python3 -c "import json;print(json.load(open('$DST/.mega-sdd/.vault-oqs-state.json'))['status'])")
    [ "$RC" -eq "$want_rc" ] && [ "$ST" = "$want_st" ] \
      && ok "10: validate-vault-oqs behavior UNCHANGED on operator-ux/$fx (rc=$RC status=$ST)" \
      || fail "10: post-refactor validator drift on operator-ux/$fx (rc=$RC status=$ST)"
  done
else
  ok "10: operator-ux fixtures not present in this checkout — repo-fixture behavior check skipped"
fi

# ── 11. usage ──
bash "$DERIVE" </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "11: missing --vault → exit 3" || fail "11: usage exit wrong (rc=$RC)"

if [ "$FAILED" -eq 0 ]; then echo "ALL W5 DERIVE OK"; exit 0; else echo "W5 derive FAILED"; exit 1; fi
