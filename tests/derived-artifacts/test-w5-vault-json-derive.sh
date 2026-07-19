#!/usr/bin/env bash
# test-w5-vault-json-derive.sh — batch2 W5 end-to-end (spec
# 2026-07-19-batch2-derive-and-diet.md): vault.json exits the model write-lane.
# On a COPY of tests/fixtures/sample-project (the checked-in fixture is never
# touched), upgrade the sample-vault markdown to the canonical grammar and:
#
#   1  derive with a patch reproducing the fixture's authored fields → the
#      derived top-level keys SUPERSET-match the checked-in fixture vault.json;
#      the legacy `mode: existing` (contradicting md `implementation_mode: new`)
#      is carried verbatim; OQ status 'open' preserved (G3 vocabulary)
#   2  every fixture entities/flows/adrs/open_questions entry is reproduced
#      by the deriver (per-entry field match)
#   3  run-analyze.sh entities_count_sync + oq_count_sync report PASS against
#      the derived json (the loose independent cross-check stays green)
#   4  the doc-control stamp input — sha256(vault.json bytes), what
#      build-citation-map stamps into the FSD Source-vault line — is STABLE
#      across a no-op re-derive (generated_at preserved)
#   5  writer-handoff sweep: no writer surface still instructs a model-side
#      vault.json write (lock-dance prose gone from the 4 writer skills +
#      multi-scope/setup-flow/generation-guide) — TWO signatures per file:
#      the lock-acquisition dance AND direct write/emit-vault.json phrasing
#      (allowlisted for 'never …'/deriver-context sentences)
#   6  OQ annotation position pins: a resolved OQ that is NOT the last line of
#      its doc keeps its resolution; bold '**Deferred**' inside a question
#      text stays status=open with the text intact; a genuinely deferred OQ
#      mid-doc keeps its deferred_reason; an unrelated '**Deferred**:' line
#      under a LATER heading never steals a last-OQ's status
#
# Run: bash tests/derived-artifacts/test-w5-vault-json-derive.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/mega-sdd"
DERIVE="$PLUGIN_ROOT/scripts/derive-vault-json.sh"
SRC_PROJ="$REPO_ROOT/tests/fixtures/sample-project"
[ -f "$DERIVE" ] || { echo "missing $DERIVE"; exit 1; }
[ -d "$SRC_PROJ" ] || { echo "missing $SRC_PROJ"; exit 1; }

FAILED=0
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t w5e2e)"
trap 'rm -rf "$WORK"' EXIT

echo "== W5: vault.json derive (top-level e2e) =="

PROJ="$WORK/proj"
cp -R "$SRC_PROJ" "$PROJ"
V="$PROJ/.mega-sdd/vaults/sample-vault"
FIXTURE_JSON="$SRC_PROJ/.mega-sdd/vaults/sample-vault/vault.json"

# Upgrade the COPY's markdown to the canonical vault grammar, mirroring the
# checked-in vault.json content (the fixture md is a minimal validator stub).
cat > "$V/00-index.md" <<'MD'
# Sample Vault — Index

## Vault Lock Status

- **Vault version**: v1.0
- **Project shape**: `web-app`
- **Implementation mode**: `new`
- **PRD status**: `approved`
- **Output mode**: `compact`

## Open Questions roll-up

### Tech stack & architecture (PRIORITY-2)
- [ ] **OQ-AR-1** [P2] [tech]: Which caching strategy? Redis vs Memcached. `[02-architecture.md]`

### Data model (PRIORITY-1)
- [x] **OQ-DM-1** [P1] [business]: Which ID type for users? → Resolved v1.0: Use UUID for user IDs. `[03-data-model.md]`
MD
cat > "$V/02-architecture.md" <<'MD'
# Sample Vault — Architecture

## Open Questions

- [ ] **OQ-AR-1** [P2] [tech]: Which caching strategy? Redis vs Memcached.
MD
cat > "$V/03-data-model.md" <<'MD'
# Sample Vault — Data Model

```dbml
// Purpose: System user account
Table user {
  id uuid [pk]
  email varchar
  name varchar
  role varchar
  created_at timestamp
}

// Purpose: Leave request lifecycle
Table leave_request {
  id bigint [pk, increment]
  user_id uuid
  start_date date
  end_date date
  type varchar
  status varchar
  approved_by uuid
  notes text
}
```

## Open Questions

- [x] **OQ-DM-1** [P1] [business]: Which ID type for users? → **Resolved v1.0** (2026-05-27): Use UUID for user IDs.
MD
cat > "$V/04-flows.md" <<'MD'
# Sample Vault — Flows

### F-U-001: Submit leave request

**Flow**:
```mermaid
flowchart TD
    A["Fill form"] --> B["Validate dates"]
    B --> C["Create leave_request"]
    C --> D["Notify manager"]
```

**Definition of Done**:
- [ ] leave_request row created
- [ ] dates validated
- [ ] manager notified

**Source**: PRD §3
MD
cat > "$V/05-decisions.md" <<'MD'
# Sample Vault — Decisions

### D-001: Use PostgreSQL
Relational store for the leave domain. **Decision**: PostgreSQL. **Source**: PRD §2.
MD

# The authored patch reproduces the fixture's model-authored fields; the legacy
# `mode: existing` + `phase`/`phase_total` ride the CARRY-FORWARD lane from the
# prior vault.json already present in the copy.
cat > "$WORK/patch.json" <<'JP'
{
  "source_documents": [
    {"type": "PRD", "path": "tests/fixtures/sample-project/PRD.md", "version": "1.0", "date": "2026-05-27"}
  ]
}
JP

OUT=$(bash "$DERIVE" --vault "$V" --patch "$WORK/patch.json" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -qF "PASS: derived vault.json (2 entities, 1 flows, 1 adrs, 2 oqs)" \
  && ok "1: derive over the upgraded copy exits 0 with matching counts" \
  || fail "1: derive rc=$RC out: $(echo "$OUT" | head -3)"

python3 - "$V/vault.json" "$FIXTURE_JSON" <<'PY' && ok "1+2: top-level keys superset-match; legacy mode + status 'open' preserved; every fixture entity/flow/adr/OQ entry reproduced" || fail "1+2: derived json diverges from the checked-in fixture contract"
import json, sys
d = json.load(open(sys.argv[1]))
f = json.load(open(sys.argv[2]))
# superset: every fixture top-level key exists in the derived json
missing = [k for k in f if k not in d]
assert not missing, f"missing top-level keys: {missing}"
# amendment §3 pin: contradictory legacy mode carried verbatim, never reconciled
assert d["mode"] == "existing" and d["implementation_mode"] == "new"
assert d["prd_status"] == "approved" and d["vault_version"] == "1.0"
assert d["phase"] == 1 and d["phase_total"] == 1
assert d["source_documents"] == f["source_documents"]
# per-entry reproduction of the fixture arrays
def by(key, arr): return {e[key]: e for e in arr}
for fx in f["entities"]:
    de = by("name", d["entities"])[fx["name"]]
    for k, v in fx.items():
        assert de.get(k) == v, f"entity {fx['name']}.{k}: {de.get(k)!r} != {v!r}"
for fx in f["flows"]:
    de = by("id", d["flows"])[fx["id"]]
    for k, v in fx.items():
        assert de.get(k) == v, f"flow {fx['id']}.{k}: {de.get(k)!r} != {v!r}"
for fx in f["adrs"]:
    de = by("id", d["adrs"])[fx["id"]]
    for k, v in fx.items():
        assert de.get(k) == v, f"adr {fx['id']}.{k}: {de.get(k)!r} != {v!r}"
for fx in f["open_questions"]:
    de = by("tag", d["open_questions"])[fx["tag"]]
    for k, v in fx.items():
        assert de.get(k) == v, f"oq {fx['tag']}.{k}: {de.get(k)!r} != {v!r}"
# G3 vocabulary: statuses stay in the unified open/resolved set
assert {o["status"] for o in d["open_questions"]} == {"open", "resolved"}
assert d["open_questions_summary"]["by_status"]["open"] == 1
assert d["open_questions_summary"]["by_status"]["resolved"] == 1
sys.exit(0)
PY

# ── 3. run-analyze count-sync stays green (independent loose cross-check) ──
bash "$PLUGIN_ROOT/scripts/run-analyze.sh" --cwd="$PROJ" --quiet </dev/null >/dev/null 2>&1
python3 - "$PROJ/.mega-sdd/.analyze-state.json" <<'PY' && ok "3: run-analyze entities_count_sync + oq_count_sync PASS against the derived json" || fail "3: run-analyze count-sync not PASS"
import json, sys
s = json.load(open(sys.argv[1]))
found = {}
def walk(o):
    if isinstance(o, dict):
        if o.get("check") in ("entities_count_sync", "oq_count_sync"):
            found[o["check"]] = o.get("status")
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
walk(s)
assert found.get("entities_count_sync") == "PASS", found
assert found.get("oq_count_sync") == "PASS", found
sys.exit(0)
PY

# ── 4. doc-control stamp input stable across a no-op re-derive ──
SHA1=$(python3 -c "import hashlib;print(hashlib.sha256(open('$V/vault.json','rb').read()).hexdigest())")
sleep 1
bash "$DERIVE" --vault "$V" --patch "$WORK/patch.json" </dev/null >/dev/null 2>&1 || fail "4: no-op re-derive failed"
SHA2=$(python3 -c "import hashlib;print(hashlib.sha256(open('$V/vault.json','rb').read()).hexdigest())")
[ "$SHA1" = "$SHA2" ] && ok "4: sha256(vault.json) — build-citation-map's doc-control stamp input — stable across a no-op re-derive" \
  || fail "4: no-op re-derive drifted the doc-control sha"

# ── 5. writer-handoff sweep: no model-side vault.json write instruction left ──
SWEEP_FILES=(
  "$PLUGIN_ROOT/skills/generate-intent/SKILL.md"
  "$PLUGIN_ROOT/skills/generate-intent/references/generation-guide.md"
  "$PLUGIN_ROOT/skills/generate-intent/references/multi-scope.md"
  "$PLUGIN_ROOT/skills/generate-intent/references/setup-flow.md"
  "$PLUGIN_ROOT/skills/resolve-oq/SKILL.md"
  "$PLUGIN_ROOT/skills/resolve-oq/references/interactive-walk.md"
  "$PLUGIN_ROOT/skills/resolve-oq/references/binding-mode.md"
  "$PLUGIN_ROOT/skills/diff-vault/SKILL.md"
  "$PLUGIN_ROOT/skills/diff-vault/references/diff-procedure.md"
  "$PLUGIN_ROOT/skills/bind-codebase/SKILL.md"
  "$PLUGIN_ROOT/skills/bind-codebase/references/auto-memory-handoff.md"
)
SWEEP_OK=1
for f in "${SWEEP_FILES[@]}"; do
  [ -f "$f" ] || { fail "5: sweep file missing: $f"; SWEEP_OK=0; continue; }
  # signature 1: the model-side lock dance
  if grep -qiE "acquire (an |the )?(exclusive )?(advisory |file )*lock" "$f"; then
    fail "5: $f still instructs a model-side vault.json lock acquisition"
    SWEEP_OK=0
  fi
  # signature 2: direct write/emit-vault.json phrasing (a hand-write fallback
  # needs no lock prose to regress W5). Allowlist: negations ('never write…')
  # and deriver-context sentences (the script IS the sanctioned writer).
  HW=$(grep -inE "(writ(e|es|ing)|emit(s|ting)?|generat(e|es|ing)|creat(e|es|ing)|updat(e|es|ing)) (the |a |an )?(full |complete |new )?\`?vault\.json\`?" "$f" \
       | grep -viE "never|not |derive|deriver|script|sanctioned|hand-" || true)
  if [ -n "$HW" ]; then
    fail "5: $f carries a model-side vault.json write instruction: $(echo "$HW" | head -1 | cut -c1-160)"
    SWEEP_OK=0
  fi
done
grep -q "derive-vault-json.sh" \
  "$PLUGIN_ROOT/skills/generate-intent/SKILL.md" \
  && grep -q "derive-vault-json.sh" "$PLUGIN_ROOT/skills/resolve-oq/SKILL.md" \
  && grep -q "derive-vault-json.sh" "$PLUGIN_ROOT/skills/diff-vault/SKILL.md" \
  && grep -q "derive-vault-json.sh" "$PLUGIN_ROOT/skills/bind-codebase/SKILL.md" \
  || { fail "5: a writer SKILL.md lost its derive-vault-json.sh Run instruction"; SWEEP_OK=0; }
grep -q "SCRIPT-DERIVED" "$PLUGIN_ROOT/skills/generate-intent/references/vault-contract.md" \
  || { fail "5: vault-contract.md lost the SCRIPT-DERIVED declaration"; SWEEP_OK=0; }
[ "$SWEEP_OK" -eq 1 ] && ok "5: all 4 writers run the script; no surface instructs a model-side vault.json write/lock (2-signature sweep)"

# ── 6. OQ annotation position pins (vault_md.py mid-doc extraction) ──
V6="$WORK/v6"; mkdir -p "$V6"
cat > "$V6/00-index.md" <<'MD'
# Annotation Pin Vault

## Vault Lock Status

- **Vault version**: v1.0
- **Project shape**: `web-app`
- **Implementation mode**: `new`
- **PRD status**: `draft`
- **Output mode**: `compact`
MD
cat > "$V6/02-architecture.md" <<'MD'
# Architecture

## Open Questions

- [ ] **OQ-AR-2** [P2]: how should **Deferred** settlement deep-links batch?
- [ ] **OQ-AR-3** [P3]: retention period? **Deferred (v1.1)**: waiting on legal
  (follow-up booked)
- [x] **OQ-AR-1** [P1]: session store? → **Resolved v1.1** (2026-07-19): Redis.

## Retention

- Rows kept 7 years (the resolved OQ is NOT the last line of this doc).
MD
cat > "$V6/06-constraints.md" <<'MD'
# Constraints

## Open Questions

- [ ] **OQ-CN-1** [P2]: rate limit per tenant?

## Notes

**Deferred (v1.2)**: the migration plan itself is deferred to phase 2.
MD
OUT=$(bash "$DERIVE" --vault "$V6" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "6: annotation-pin vault derives (rc=0)" || fail "6: derive rc=$RC out: $(echo "$OUT" | head -3)"
python3 - "$V6/vault.json" <<'PY' && ok "6: mid-doc resolution kept; bold-Deferred-in-text stays open; mid-doc deferred_reason kept; later-heading Deferred never steals status" || fail "6: OQ annotation position pin broken"
import json, sys
oq = {o["tag"]: o for o in json.load(open(sys.argv[1]))["open_questions"]}
# resolved OQ NOT the last line of its doc → resolution still extracted
assert oq["OQ-AR-1"]["status"] == "resolved" and oq["OQ-AR-1"]["resolution"] == "Redis."
# bold '**Deferred**' inside the question text → status open, text intact
assert oq["OQ-AR-2"]["status"] == "open"
assert oq["OQ-AR-2"]["text"] == "how should **Deferred** settlement deep-links batch?"
assert "deferred_reason" not in oq["OQ-AR-2"] and "deferred_at" not in oq["OQ-AR-2"]
# genuinely deferred OQ mid-doc (a continuation line follows) → reason kept
assert oq["OQ-AR-3"]["status"] == "deferred"
assert oq["OQ-AR-3"]["deferred_reason"] == "waiting on legal"
assert oq["OQ-AR-3"]["text"] == "retention period?"
# an unrelated '**Deferred**:' under a LATER heading never fabricates status
assert oq["OQ-CN-1"]["status"] == "open"
assert "deferred_reason" not in oq["OQ-CN-1"] and "deferred_at" not in oq["OQ-CN-1"]
s = json.load(open(sys.argv[1]))["open_questions_summary"]["by_status"]
assert s == {"open": 2, "resolved": 1, "deferred": 1, "out_of_scope": 0}, s
sys.exit(0)
PY

if [ "$FAILED" -eq 0 ]; then echo "ALL W5 E2E OK"; exit 0; else echo "W5 e2e FAILED"; exit 1; fi
