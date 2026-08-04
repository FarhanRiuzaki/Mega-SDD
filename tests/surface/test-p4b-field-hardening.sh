#!/usr/bin/env bash
# test-p4b-field-hardening.sh — 6.0.1 field-test hardening
# (spec 2026-08-04-v6-field-test-hardening.md; source: the simkredit run).
#
# Pins:
#   F1  the dirty journal records ONLY in-repo writes (writer), and the probe
#       counts only relative-path rows (consumer heals poisoned journals).
#   F2  orphan scan: a unit-attributed commit with ZERO target_files overlap
#       is an advisory generation-mismatch extra, never a FAIL; an overlapping
#       commit without a bolt-report still BLOCKS; empty-target units stay
#       blocking (unknown != mismatch).
#   F3  starterkit-conformance: prose/multi-root location values skip with a
#       note; path-shaped values still enforce; `a | b` alternation passes on
#       either root.
#   F4  constitution-propagation: binding claim ids (C-NNN) not present in
#       constitution.md are NOT propagation obligations; a §-style
#       constitution yields SKIP; a real census still enforces.
#   F5  derive-vault-json: JSON-only OQ fields present as md hint lines are
#       derived (lowest precedence); a patched value wins over a hint.
#
# CI-safe: bash + python3 + git. Run with </dev/null.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
fails=0
ok()   { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

mkrepo() { # $1=dir — a minimal grounded project (git + .mega-sdd/codebase)
  mkdir -p "$1/.mega-sdd/codebase" "$1/src"
  ( cd "$1" && git init -q . && git config user.email t@t && git config user.name t \
    && git config commit.gpgsign false )
}

echo "── F1: journal writer skips out-of-tree; probe ignores absolute rows ──"
PR="$W/f1"; mkrepo "$PR"
drive_ptu() { # $1=cwd $2=file_path
  printf '{"session_id":"t","cwd":"%s","hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"%s"},"tool_response":{}}' "$1" "$2" \
    | bash "$P/hooks/post-tool-use" >/dev/null 2>&1 || true
}
drive_ptu "$PR" "$PR/src/app.ts"
drive_ptu "$PR" "/private/tmp/somewhere-else/scratch.py"
drive_ptu "$PR" "$HOME/.claude/projects/x/memory/note.md"
J="$PR/.mega-sdd/codebase/.dirty-paths.jsonl"
if [ -f "$J" ]; then
  grep -qF '"src/app.ts"' "$J" && ok "F1 writer: in-repo write journaled (relative)" || fail "F1 writer: in-repo write missing"
  grep -qF 'somewhere-else' "$J" && fail "F1 writer: out-of-tree scratchpad write journaled" || ok "F1 writer: scratchpad write skipped"
  grep -qF '.claude/projects' "$J" && fail "F1 writer: memory write journaled" || ok "F1 writer: memory write skipped"
else
  fail "F1 writer: journal never created for the in-repo write"
fi
# consumer: seed a poisoned journal (pre-fix rows) + one real row
printf '{"ts":"t","path":"/private/tmp/x/scratch.py","tool":"Write","session":"s"}\n{"ts":"t","path":"src/app.ts","tool":"Write","session":"s"}\n{"ts":"t","path":"C:\\\\Users\\\\x\\\\y.py","tool":"Write","session":"s"}\n' > "$J"
N=$(PYTHONPATH="$P/scripts/_lib" python3 -c "
import state_probes
print(state_probes.probe_dirty_journal('$PR'))")
[ "$N" = "1" ] && ok "F1 probe: absolute rows (posix + windows) ignored, relative counted (rows=$N)" || fail "F1 probe: expected 1 counted row, got $N"

echo "── F2: orphan scan generation scoping ──"
PR2="$W/f2"; mkrepo "$PR2"
V2="$PR2/.mega-sdd/vaults/v1"; mkdir -p "$V2/units" "$V2/bolts"
printf '{"project_name":"p"}\n' > "$V2/vault.json"
cat > "$V2/units/U-001.md" <<'EOF'
---
unit_id: U-001
title: Prisma migration
task_type: create
target_files:
  - path: prisma/schema.prisma
---
body
EOF
cat > "$V2/units/U-002.md" <<'EOF'
---
unit_id: U-002
title: Auth handler
task_type: create
target_files:
  - path: src/auth.ts
---
body
EOF
( cd "$PR2" \
  && git add -A && git commit -qm "init" \
  && printf 'lock\n' > pnpm-lock.yaml && git add pnpm-lock.yaml \
  && git commit -qm "chore(U-001): sync pnpm-lock.yaml (PRIOR vault generation)" \
  && printf 'auth\n' > src/auth.ts && git add src/auth.ts \
  && git commit -qm "feat(U-002): implement auth handler (CURRENT generation)" ) >/dev/null 2>&1
OUT2=$(bash "$P/scripts/validate-bolt-artifacts.sh" --cwd="$PR2" --orphan-scan --quiet </dev/null 2>&1; echo "rc=$?")
S2="$PR2/.mega-sdd/.bolt-orphans-state.json"
python3 - "$S2" <<'EOF' && ok "F2: zero-overlap U-001 -> advisory extra; overlapping U-002 without report -> blocking orphan" || fail "F2: state shape wrong (see $S2)"
import json, sys
d = json.load(open(sys.argv[1]))
orphan_ids = {i["unit_id"] for i in d.get("issues", [])}
extra_ids = {e["unit_id"] for e in d.get("extras", [])}
assert d["status"] == "FAIL", d["status"]
assert orphan_ids == {"U-002"}, orphan_ids
assert extra_ids == {"U-001"}, extra_ids
assert all(e.get("type") == "bolt_commit_generation_mismatch" for e in d.get("extras", []))
EOF
# resolve the real orphan -> PASS with the advisory extra still noted
mkdir -p "$V2/bolts/U-002" && printf -- '---\nstatus: completed\n---\nreport\n' > "$V2/bolts/U-002/bolt-report.md"
bash "$P/scripts/validate-bolt-artifacts.sh" --cwd="$PR2" --orphan-scan --quiet </dev/null >/dev/null 2>&1
python3 - "$S2" <<'EOF' && ok "F2: after the real report lands, PASS with the mismatch still an extra" || fail "F2: PASS-with-extra shape wrong"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["status"] == "PASS", d["status"]
assert {e["unit_id"] for e in d.get("extras", [])} == {"U-001"}
EOF
# round arms: extras-only + glob-target dodges stay BLOCKING
cat > "$V2/units/U-004.md" <<'EOF'
---
unit_id: U-004
title: Extras dodge
task_type: create
target_files:
  - path: src/thing.ts
---
body
EOF
cat > "$V2/units/U-005.md" <<'EOF'
---
unit_id: U-005
title: Glob target
task_type: create
target_files:
  - path: src/models/*.py
---
body
EOF
( cd "$PR2" \
  && mkdir -p tests src/models \
  && printf 't\n' > tests/thing.test.ts && git add tests/thing.test.ts \
  && git commit -qm "feat(U-004): tests only (extras-only dodge attempt)" \
  && printf 'u\n' > src/models/user.py && git add src/models/user.py \
  && git commit -qm "feat(U-005): model (glob-declared target)" ) >/dev/null 2>&1
bash "$P/scripts/validate-bolt-artifacts.sh" --cwd="$PR2" --orphan-scan --quiet </dev/null >/dev/null 2>&1
python3 - "$S2" <<'EOF' && ok "F2 round: extras-only commit AND glob-target commit both stay BLOCKING orphans" || fail "F2 round: a dodge shape escaped the gate"
import json, sys
d = json.load(open(sys.argv[1]))
ids = {i["unit_id"] for i in d.get("issues", [])}
assert "U-004" in ids, ids   # extras-only touched set -> blocking
assert "U-005" in ids, ids   # glob target matched via _glob_match -> blocking
extra_ids = {e["unit_id"] for e in d.get("extras", [])}
assert "U-004" not in extra_ids and "U-005" not in extra_ids, extra_ids
EOF
mkdir -p "$V2/bolts/U-004" "$V2/bolts/U-005"
printf -- '---\nstatus: completed\n---\nr\n' > "$V2/bolts/U-004/bolt-report.md"
printf -- '---\nstatus: completed\n---\nr\n' > "$V2/bolts/U-005/bolt-report.md"

# empty-target unit stays BLOCKING (unknown != mismatch)
cat > "$V2/units/U-003.md" <<'EOF'
---
unit_id: U-003
title: Verify config
task_type: verify
target_files: []
---
body
EOF
( cd "$PR2" && printf 'x\n' > note.txt && git add -A && git commit -qm "chore(U-003): verify pass" ) >/dev/null 2>&1
bash "$P/scripts/validate-bolt-artifacts.sh" --cwd="$PR2" --orphan-scan --quiet </dev/null >/dev/null 2>&1
python3 - "$S2" <<'EOF' && ok "F2: empty-target unit without report stays a BLOCKING orphan" || fail "F2: empty-target unit escaped the gate"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["status"] == "FAIL", d["status"]
assert "U-003" in {i["unit_id"] for i in d.get("issues", [])}
EOF

echo "── F3: prose-location guard ──"
PR3="$W/f3"; mkrepo "$PR3"
V3="$PR3/.mega-sdd/vaults/v1"; mkdir -p "$V3/units"
printf '{"project_name":"p"}\n' > "$V3/vault.json"
mkdir -p "$PR3/.mega-sdd/codebase"
cat > "$PR3/.mega-sdd/codebase/starterkit-context.yaml" <<'EOF'
patterns:
  test:
    location: "colocated — a module with a test lives in a folder holding index.ts + index.test.ts"
  controller:
    location: "apps/web/src/app/api/ | apps/api/src/"
  data_model:
    location: "src/models/"
EOF
cat > "$V3/units/U-001.md" <<'EOF'
---
unit_id: U-001
title: Engine
task_type: create
target_files:
  - path: apps/api/src/simulations/engine/index.test.ts
  - path: apps/api/src/simulations/engine/index.ts
  - path: lib/models/stray.ts
  - path: packages/legacy/src/models/user.ts
  - path: apps/api/src/things/ThingController.ts
---
body
EOF
bash "$P/scripts/validate-starterkit-conformance.sh" --cwd="$PR3" </dev/null > "$W/out3.json" 2>/dev/null || true
python3 - "$W/out3.json" <<'EOF' && ok "F3: prose test-location skipped w/ note; alternation matches apps/api/src/; path-shaped data_model still enforces" || fail "F3: guard behavior wrong"
import json, sys
d = json.load(open(sys.argv[1]))
sk = d.get("location_checks_skipped", {})
assert "test.location" in sk, sk
viol = [v["pattern"] for v in d.get("violations", [])]
assert "test.location" not in viol, viol
assert "controller.location" not in viol, viol
# the path-shaped data_model check STILL enforces (lib/models/stray.ts wrong dir)
assert "data_model.location" in viol, viol
# round: data_model stays STARTSWITH-ONLY — the substring shape
# packages/legacy/src/models/user.ts must STILL violate (it contains
# "src/models/" as a substring; the first cut wrongly passed it)
files_violating = [v["file"] for v in d.get("violations", []) if v["pattern"] == "data_model.location"]
assert "packages/legacy/src/models/user.ts" in files_violating, files_violating
# round: the alternation arm is actually EXERCISED — a controller-classified
# file under apps/api/src/ passes via the second root
assert "apps/api/src/things/ThingController.ts" not in [v["file"] for v in d.get("violations", [])], d.get("violations")
EOF

echo "── F4: constitution-propagation census gate ──"
PR4="$W/f4"; mkrepo "$PR4"
V4="$PR4/.mega-sdd/vaults/v1"; mkdir -p "$V4/units"
printf '{"project_name":"p"}\n' > "$V4/vault.json"
# §-style constitution + a binding full of C-NNN CLAIM ids
printf '# Constitution\n\n## §A1 Naming\n\nRules.\n' > "$V4/constitution.md"
printf '# Binding\n\n- **C-009** claim CONFIRMED\n- **C-012** claim OQ\n' > "$V4/binding.md"
printf -- '---\nunit_id: U-001\ntitle: x\n---\nbody\n' > "$V4/units/U-001.md"
OUT4=$(bash "$P/scripts/validate-constitution-propagation.sh" --cwd="$PR4" </dev/null 2>&1)
echo "$OUT4" | grep -q '"status": "SKIP"' \
  && ok "F4: claim ids + §-style constitution -> SKIP, not 19 phantom obligations" \
  || fail "F4: expected SKIP, got: $(echo "$OUT4" | head -2)"
# a REAL census still enforces
printf '# Constitution\n\n- B-001: All endpoints require auth.\n' > "$V4/constitution.md"
printf '# Binding\n\n- B-001 cited CONFIRMED\n- C-009 claim row\n' > "$V4/binding.md"
bash "$P/scripts/validate-constitution-propagation.sh" --cwd="$PR4" </dev/null > "$W/out4b.json" 2>/dev/null || true
python3 - "$W/out4b.json" <<'EOF' && ok "F4: census-listed B-001 still enforced; C-009 excluded" || fail "F4: real census enforcement broken"
import json, sys
d = json.load(open(sys.argv[1]))
dropped = {x.get("clause_id") or x.get("clause") for x in d.get("drops", [])}
assert "B-001" in dropped, (d.get("status"), dropped)
assert "C-009" not in dropped, dropped
EOF

echo "── F5: md-hint OQ fields derive; patch wins ──"
PR5="$W/f5"; V5="$PR5/.mega-sdd/vaults/v1"; mkdir -p "$V5"
mkrepo "$PR5"
printf '# Index\n\n## Vault Lock Status\n\n- **Vault version**: 1.0\n\n## Open Questions (roll-up)\n' > "$V5/00-index.md"
printf '# Overview\n\n## Product\n\nX.\n' > "$V5/01-overview.md"
cat > "$V5/02-architecture.md" <<'EOF'
# Architecture

## Routes

- [ ] **OQ-AR-1** [P2] [tech / scan]: which route prefix? — resolve: scan
  `scan_query: "app/api/v1 route handler path prefix in apps/web"`
- [ ] **OQ-AR-2** [P3] [tech / recommend]: which ORM?
  `recommendation: prisma`
  `rationale: already in the lockfile`
  `scan_citations: package.json, prisma/schema.prisma`
  `fallback_if_wrong: swap to drizzle`
- [ ] **OQ-AR-3** [P3] [business]: should we follow the vendor recommendation: keep REST or move to gRPC?

  ```yaml
  scan_query: "FENCED-EXAMPLE-NEVER-A-HINT"
  ```
EOF
printf '# Data\n' > "$V5/03-data-model.md"
printf '# Flows\n' > "$V5/04-flows.md"
printf '# Decisions\n' > "$V5/05-decisions.md"
printf '# Constraints\n' > "$V5/06-constraints.md"
bash "$P/scripts/derive-vault-json.sh" --vault "$V5" </dev/null >/dev/null 2>&1
python3 - "$V5/vault.json" <<'EOF' && ok "F5: md hint lines derive (scan_query + the 4 recommend fields; citations = array)" || fail "F5: md hints not derived"
import json, sys
d = json.load(open(sys.argv[1]))
oqs = {q["tag"]: q for q in d["open_questions"]}
assert oqs["OQ-AR-1"].get("scan_query") == "app/api/v1 route handler path prefix in apps/web", oqs["OQ-AR-1"]
q2 = oqs["OQ-AR-2"]
assert q2.get("recommendation") == "prisma", q2
assert q2.get("scan_citations") == ["package.json", "prisma/schema.prisma"], q2
assert q2.get("fallback_if_wrong") == "swap to drizzle", q2
# round: prose "the vendor recommendation: ..." in QUESTION TEXT is never
# captured (anchored regex), and a fenced yaml example is never a hint
q3 = oqs["OQ-AR-3"]
assert "recommendation" not in q3, q3
assert "scan_query" not in q3, q3
EOF
# patch precedence: a patched scan_query must beat the md hint
cat > "$W/patch5.json" <<'EOF'
{"open_questions": {"OQ-AR-1": {"scan_query": "PATCHED-VALUE"}}}
EOF
bash "$P/scripts/derive-vault-json.sh" --vault "$V5" --patch "$W/patch5.json" </dev/null >/dev/null 2>&1
python3 - "$V5/vault.json" <<'EOF' && ok "F5: patched value wins over the md hint (and survives a re-derive)" || fail "F5: precedence broken"
import json, sys
d = json.load(open(sys.argv[1]))
oqs = {q["tag"]: q for q in d["open_questions"]}
assert oqs["OQ-AR-1"].get("scan_query") == "PATCHED-VALUE", oqs["OQ-AR-1"]
EOF
bash "$P/scripts/derive-vault-json.sh" --vault "$V5" </dev/null >/dev/null 2>&1
python3 - "$V5/vault.json" <<'EOF' && ok "F5: carried patched value survives the next plain derive" || fail "F5: carry-forward lost to the hint"
import json, sys
d = json.load(open(sys.argv[1]))
oqs = {q["tag"]: q for q in d["open_questions"]}
assert oqs["OQ-AR-1"].get("scan_query") == "PATCHED-VALUE", oqs["OQ-AR-1"]
EOF
# round: a carried NULL is absence — the md hint must heal it
python3 - "$V5/vault.json" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
for q in d["open_questions"]:
    if q["tag"] == "OQ-AR-2":
        q["recommendation"] = None
json.dump(d, open(sys.argv[1], "w"), indent=1)
EOF
bash "$P/scripts/derive-vault-json.sh" --vault "$V5" </dev/null >/dev/null 2>&1
python3 - "$V5/vault.json" <<'EOF' && ok "F5 round: a carried null is healed by the md hint (null = absence)" || fail "F5 round: null blocked the hint (inert fix)"
import json, sys
d = json.load(open(sys.argv[1]))
oqs = {q["tag"]: q for q in d["open_questions"]}
assert oqs["OQ-AR-2"].get("recommendation") == "prisma", oqs["OQ-AR-2"]
EOF

echo
if [ "$fails" -eq 0 ]; then echo "test-p4b-field-hardening: ALL PASS"; exit 0
else echo "test-p4b-field-hardening: $fails FAILURE(S)"; exit 1; fi
