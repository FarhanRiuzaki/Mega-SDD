#!/usr/bin/env bash
# KB → plan — the legacy-rebuild hand-off stays buildable (spec docs/superpowers/specs/
# 2026-09-27-v9-simplification-design.md §0.2 + §4 + §7 decision 6; a P1 exit criterion).
# extract-intelligence writes a PRD-kontrak KB; `plan --kb=<kb-dir>` turns it into the
# layout-3 vault + units. Pinned here:
#   P  derive-plan-pins.sh --kb: prd_path = <kb>/README.md, prd_sha256 = sha256 of
#      <kb>/census.json (README when a numbered-tree KB has none), project_scale standard
#   C  validate-plan-coverage.sh --kb: every module heading of <kb>/modules/*.prd.md (a numbered-tree KB: 10-domains/*.md)
#      (minus §1 Purpose / §6 Open Questions) needs a unit prd_source or an OQ that
#      names the module file; a FAIL names the gap and its module
#   W  the wiring: extract-intelligence hands off to plan --kb, plan accepts --kb
# Fixtures are synthetic; no network, no model.
# Run: bash tests/v9/test-kb-to-plan.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$here/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
PINS="$P/scripts/derive-plan-pins.sh"; COV="$P/scripts/validate-plan-coverage.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/kb-plan.XXXXXX")"; trap 'rm -rf "$T"' EXIT
rc=0
ok() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; rc=1; }
jget() { python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(d[sys.argv[1]])' "$1"; }
sha() { python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }

# ── fixture: a project with an extract-intelligence KB (PRD-kontrak grammar) ──
W="$T/proj"; KB="$W/.mega-sdd/knowledge-base"; V="$W/.mega-sdd/vaults/legacy-billing"
mkdir -p "$KB/modules" "$V/units"
git -C "$W" init -q && git -C "$W" config user.name "KB Tester"
cat > "$KB/README.md" <<'EOF'
# Legacy Billing — Knowledge Base

## Reengineering Opportunities
- Replace the nightly batch with an event.

## Mutability Tier Distribution
| Module | LOCKED | INTENT | ARTIFACT |
|---|---|---|---|
| a | 1 | 1 | 0 |
EOF
echo '{"census_version": 1, "legacy_root": "/src/legacy-billing", "file_count": 1, "files": []}' > "$KB/census.json"
cat > "$KB/modules/a.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: a
---
# PRD — Invoicing

## 1. Purpose
Issues invoices.

## 2. Business Rules
| ID | Rule | Why | Source | Confidence | Mutability |
|---|---|---|---|---|---|
| BR-A-1 | Invoice total = sum of lines | contract | inv.rpg:12 | | [LOCKED] |

## 3. Flow
```mermaid
flowchart LR
  A["Order"] --> B["Invoice"]
```

## 6. Open Questions
_Tidak ada._
EOF

echo "── P: derive-plan-pins.sh --kb ──"
out="$(bash "$PINS" --cwd="$W" --kb=.mega-sdd/knowledge-base </dev/null)"; ec=$?
[ $ec -eq 0 ] && ok "P0 --kb → exit 0" || bad "P0 exit $ec: $out"
[ "$(echo "$out" | jget prd_path)" = ".mega-sdd/knowledge-base/README.md" ] && ok "P1 prd_path = <kb>/README.md" || bad "P1 $out"
[ "$(echo "$out" | jget prd_sha256)" = "$(sha "$KB/census.json")" ] && ok "P2 prd_sha256 = sha256 of <kb>/census.json (decision 6)" || bad "P2 $out"
[ "$(echo "$out" | jget project_scale)" = standard ] && ok "P3 project_scale = standard (a legacy rebuild is never xs)" || bad "P3 $out"
[ "$(echo "$out" | jget slug)" = legacy-billing ] && [ "$(echo "$out" | jget vault)" = ".mega-sdd/vaults/legacy-billing" ] \
  && ok "P4 slug from the census legacy_root; vault default .mega-sdd/vaults/<slug>" || bad "P4 $out"
[ "$(echo "$out" | jget author)" = "KB Tester" ] && [ "$(echo "$out" | jget vault_exists)" = False ] && ok "P5 author from git, vault_exists false" || bad "P5 $out"
N="$T/tree"; mkdir -p "$N/kb"; printf '# Old Tree KB\n\n## Reengineering Opportunities\n- x\n' > "$N/kb/README.md"
out="$(bash "$PINS" --cwd="$N" --kb=kb </dev/null)"
[ "$(echo "$out" | jget prd_sha256)" = "$(sha "$N/kb/README.md")" ] && [ "$(echo "$out" | jget slug)" = old-tree-kb ] \
  && ok "P6 no census.json (numbered-tree KB) → README is hashed; slug from the README title" || bad "P6 $out"
bash "$PINS" --cwd="$W" --kb=nope </dev/null >/dev/null 2>&1; [ $? -eq 3 ] && ok "P7 KB without README.md → exit 3" || bad "P7 exit"
bash "$PINS" --cwd="$W" --kb=.mega-sdd/knowledge-base --prd=x.md </dev/null >/dev/null 2>&1; [ $? -eq 2 ] && ok "P8 --kb with --prd → exit 2" || bad "P8 exit"

echo "── C: validate-plan-coverage.sh --kb ──"
mkunit() { cat > "$V/units/$1.md" <<EOF
---
id: $1
title: $1
task_type: create
context_source: context.md#F-U-001
prd_source: $2
target_files:
  - path: src/$1.ts
    operation: create
acceptance_test:
  - type: test
    command: x
    expects: ""
---
# $1
EOF
}
cov() { ( cd "$W" && bash "$COV" --cwd="$W" --kb=.mega-sdd/knowledge-base --vault="$V" --quiet </dev/null ); }
ST="$W/.mega-sdd/.plan-coverage-state.json"
echo '{"open_questions":[]}' > "$V/vault.json"
mkunit U-001 '.mega-sdd/knowledge-base/modules/a.prd.md#2-business-rules'
cov; ec=$?
python3 - "$ST" "$ec" <<'EOF' && ok "C1 one module heading uncovered → FAIL exit 1; the gap names the heading and its module; §1/§6 not counted" || bad "C1 wrong verdict"
import json, sys
d = json.load(open(sys.argv[1])); ec = int(sys.argv[2])
assert ec == 1 and d["status"] == "FAIL" and d["anchors"] == 2, d
assert [(g["file"], g["slug"]) for g in d["gaps"]] == [(".mega-sdd/knowledge-base/modules/a.prd.md", "3-flow")], d["gaps"]
assert d["gaps"][0]["halt_type"] == "plan_coverage_gap" and "a.prd.md#3-flow" in d["next_action"], d["next_action"]
assert d["prd"] == ".mega-sdd/knowledge-base/README.md" and d["sources"] == [".mega-sdd/knowledge-base/modules/a.prd.md"], d
EOF
echo '{"open_questions":[{"tag":"OQ-FL-1","text":"3. Flow — who approves?","status":"open"}]}' > "$V/vault.json"
cov; [ $? -eq 1 ] && ok "C2 an OQ quoting the heading but not the module file does not cover it (every module has a '3. Flow')" || bad "C2 bare-heading OQ counted"
echo '{"open_questions":[{"tag":"OQ-FL-1","text":"a.prd.md 3. Flow — who approves?","status":"open"}]}' > "$V/vault.json"
cov; [ $? -eq 0 ] && ok "C3 an OQ naming the module file + quoting the heading covers it" || bad "C3 module-scoped OQ not counted"
echo '{"open_questions":[]}' > "$V/vault.json"
mkunit U-002 '.mega-sdd/knowledge-base/modules/a.prd.md#3-flow'
cov; ec=$?
python3 - "$ST" "$ec" <<'EOF' && ok "C4 once a unit's prd_source cites it → PASS exit 0" || bad "C4 not PASS"
import json, sys
d = json.load(open(sys.argv[1])); ec = int(sys.argv[2])
assert ec == 0 and d["status"] == "PASS" and d["gaps"] == [] and d["covered"] == 2, d
EOF
cat > "$KB/modules/b.prd.md" <<'EOF'
# PRD — Payments

## 1. Purpose
Takes payments.

## 3. Flow
x
EOF
cov; ec=$?
python3 - "$ST" "$ec" <<'EOF' && ok "C5 a second module's same-named heading is its own anchor (a.prd.md#3-flow does not cover b.prd.md)" || bad "C5 cross-module leak"
import json, sys
d = json.load(open(sys.argv[1])); ec = int(sys.argv[2])
assert ec == 1 and [g["file"].rsplit("/", 1)[1] for g in d["gaps"]] == ["b.prd.md"], d["gaps"]
EOF
( cd "$W" && bash "$COV" --cwd="$W" --kb=.mega-sdd/knowledge-base --prd=x.md --vault="$V" --quiet </dev/null >/dev/null 2>&1 ); [ $? -eq 2 ] && ok "C6 --kb with --prd → exit 2" || bad "C6 exit"
# a legacy numbered-tree KB (no modules/) is censused over 10-domains/ — never a usage error
# (exit 2 writes no state, and the execute-bolts predictive gate is FATAL without it)
L="$N/kb"; LV="$N/.mega-sdd/vaults/t"; mkdir -p "$L/10-domains" "$LV/units"; echo '{"open_questions":[]}' > "$LV/vault.json"
printf '# Leave\n\n## 1. Purpose\nx\n\n## 7. Business Rules\nx\n\n## 10. Open Questions\nx\n\n## 11. Source References\nx\n' > "$L/10-domains/10-leave.md"
( cd "$N" && bash "$COV" --cwd="$N" --kb=kb --vault="$LV" --quiet </dev/null ); ec=$?
python3 - "$N/.mega-sdd/.plan-coverage-state.json" "$ec" <<'EOF' && ok "C7 numbered-tree KB → census over 10-domains/*.md (§1/§10/§11 meta); the gap names the domain file" || bad "C7 numbered-tree KB"
import json, sys
d = json.load(open(sys.argv[1])); ec = int(sys.argv[2])
assert ec == 1 and d["anchors"] == 1 and [(g["file"], g["slug"]) for g in d["gaps"]] == [("kb/10-domains/10-leave.md", "7-business-rules")], d
EOF

echo "── W: wiring (extract-intelligence → plan --kb) ──"
EI="$P/skills/extract-intelligence"; SK="$P/skills/plan/SKILL.md"
grep -qF 'plan --kb=<out>/knowledge-base/' "$EI/SKILL.md" && grep -qF 'mega-sdd:plan --kb=<kb> --auto' "$EI/SKILL.md" \
  && ok "W1 extract-intelligence announces and hands off to plan --kb" || bad "W1 extract-intelligence hand-off"
grep -qF 'suggested_skill: mega-sdd:plan' "$EI/references/handoff.md" && ok "W2 --auto handoff YAML names mega-sdd:plan" || bad "W2 handoff.md"
grep -qF -- '--kb=<kb-dir>' "$SK" && grep -qF 'references/kb-input.md' "$SK" && [ -f "$P/skills/plan/references/kb-input.md" ] \
  && ok "W3 plan accepts --kb and routes to references/kb-input.md" || bad "W3 plan --kb route"
grep -q 'generate-intent' "$SK" && bad "W4 plan still routes a KB to generate-intent" || ok "W4 plan names no generate-intent route (the KB refusal is gone)"
grep -qF 'skills/plan/references/templates/ai-consumer-guide.md' "$SK" && [ -f "$P/skills/plan/references/templates/ai-consumer-guide.md" ] \
  && ok "W5 the Step-3 consumer-guide cp source exists" || bad "W5 consumer-guide cp source"
grep -qF -- '--kb=<kb-dir>' "$P/skills/plan/references/plan-procedure.md" && grep -qF 'plan --kb=$APATH' "$P/scripts/certify-artifact.sh" \
  && ok "W6 plan-procedure + the certify kb rung name plan --kb" || bad "W6 procedure/certify"
exit $rc
