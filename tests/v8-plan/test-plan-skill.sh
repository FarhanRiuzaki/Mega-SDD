#!/usr/bin/env bash
# test-plan-skill.sh — v8 P2 `skills/plan` (spec 2026-09-10 §3 / App. C3): structural
# pins + the script-derived pins (derive-plan-pins.sh). Run: bash tests/v8-plan/test-plan-skill.sh </dev/null
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"
SK="$P/skills/plan/SKILL.md"; PR="$P/skills/plan/references/plan-procedure.md"; TPL="$P/skills/plan/references/templates/context.md"
rc=0; fail() { echo "FAIL: $1"; rc=1; }; pass() { echo "PASS: $1"; }

# a — SKILL.md: exists, ≤500 lines, valid frontmatter (name/version/description, no colon-space in the description)
[ -f "$SK" ] && pass "a: SKILL.md exists" || fail "a: SKILL.md missing"
n=$(wc -l < "$SK" | tr -d ' '); [ "$n" -le 500 ] && pass "a: SKILL.md $n lines ≤ 500" || fail "a: SKILL.md $n lines > 500"
python3 - "$SK" <<'PYX' || rc=1
import re, sys
s = open(sys.argv[1], encoding="utf-8").read(); m = re.match(r'^---\n(.*?)\n---\n', s, re.S)
assert m, "no frontmatter"; fm = m.group(1); keys = {}
for ln in fm.split("\n"):
    k, _, v = ln.partition(":"); keys[k.strip()] = v.strip()
assert keys.get("name") == "plan", keys.get("name"); assert re.match(r"^\d+\.\d+\.\d+$", keys.get("version", "")), keys.get("version")
d = keys.get("description", ""); assert d and ": " not in d, "description carries a bare colon-space (invalid YAML) or is empty"
assert "lite" in d and "context.md" in d and "units" in d, "description census: lite / context.md / units"
print("PASS: a: frontmatter valid (name=plan, semver, description without colon-space, census words present)")
PYX
grep -qF 'mega-sdd-trace:plan' "$SK" && pass "a: gateway tag mega-sdd-trace:plan" || fail "a: gateway tag missing"
grep -q '^\*\*Announce at start:\*\*.*mega-sdd-trace:plan' "$SK" && pass "a: announce line carries the tag" || fail "a: announce line untagged"

# b — the moat + the one-ask contract are in the skill body
for k in 'never auto-answers a P1 business OQ' 'validate-plan-coverage.sh' 'plan_coverage_gap' 'JIT bind' 'derive-plan-pins.sh' 'ONE batched ask' 'context_source: context.md#' 'prd_source' 'No handoff YAML in this lane' 'xs body diet'; do
  grep -qF "$k" "$SK" && pass "b: SKILL.md says: $k" || fail "b: SKILL.md lacks: $k"
done
# references one level deep from the skill dir (own references/) + cross-skill pointers use the ../<skill>/references form
grep -q 'references/plan-procedure.md' "$SK" && grep -q 'references/templates/context.md' "$SK" && pass "b: own references cited" || fail "b: own references missing"
grep -q '\.\./generate-units/references/unit-schema.md' "$SK" && grep -q '\.\./generate-intent/references/vault-core.md' "$SK" && pass "b: cross-skill pointers (unit-schema, vault-core)" || fail "b: cross-skill pointers missing"

# c — template: layout-3 marker + four hard headers, killed sections absent as real headers, OQ rules
grep -q '^vault_layout: 3' "$TPL" && pass "c: template vault_layout: 3" || fail "c: template layout marker"
for h in '## Flows' '## Data model' '## Constraints' '## Open Questions'; do grep -qx "$h" "$TPL" && pass "c: template header $h" || fail "c: template header missing: $h"; done
for h in '## Architecture' '## Glossary' '## Sources' '## Last updated' '## Phase context'; do grep -qx "$h" "$TPL" && fail "c: killed header written: $h" || pass "c: killed header absent: $h"; done
grep -q '^prd_sha256:' "$TPL" && grep -q '^author:' "$TPL" && grep -q '^stakeholders:' "$TPL" && grep -q '^prd_path_at_generation:' "$TPL" && pass "c: frontmatter pins present" || fail "c: frontmatter pins missing"
grep -qF '[origin: context.md#' "$TPL" && grep -qF 'Deferred (plan)' "$TPL" && pass "c: OQ rules (origin grammar, xs born-deferred)" || fail "c: OQ rules missing"
grep -qF 'NEVER asked' "$TPL" && pass "c: author/stakeholders never asked" || fail "c: never-asked rule missing"
# the template, as written, satisfies the layout-3 hard-header contract of the resolver
python3 - "$P/scripts/_lib" "$TPL" <<'PYX' || rc=1
import sys; sys.path.insert(0, sys.argv[1]); import vault_md
md = open(sys.argv[2], encoding="utf-8").read()
assert vault_md.vault_layout(md) == 3 and vault_md.v3_missing_headers(md) == [], vault_md.v3_missing_headers(md)
print("PASS: c: template passes vault_md layout-3 detection + hard-header contract")
PYX

# d — procedure: the ask shape, keterangan, overflow, headless honesty, brownfield query, validator order
for k in '≤4 questions' 'Keterangan is mandatory' 'ask the top 4' 'never auto-answer' 'query-symbol-index.sh' 'validate-plan-coverage.sh' 'never answers an OQ on the user' 'Rail A1' 'Self-slice' 'must-not-exist'; do
  grep -qF "$k" "$PR" && pass "d: procedure says: $k" || fail "d: procedure lacks: $k"
done

# e — derive-plan-pins.sh: usage, unreadable PRD, JSON shape, sha, slug, vault default, mode, vault_exists
S="$P/scripts/derive-plan-pins.sh"
bash "$S" </dev/null >/dev/null 2>&1; [ $? -eq 2 ] && pass "e: usage → exit 2" || fail "e: usage exit"
T=$(mktemp -d); mkdir -p "$T/PRD"; cp "$ROOT/tests/scenarios/sample-prd-clinic.md" "$T/PRD/prd-klinik-demo.md"; git -C "$T" init -q >/dev/null 2>&1; git -C "$T" config user.name "Pin Tester"
bash "$S" --cwd="$T" --prd=PRD/missing.md </dev/null >/dev/null 2>&1; [ $? -eq 3 ] && pass "e: missing PRD → exit 3" || fail "e: missing PRD exit"
J=$(bash "$S" --cwd="$T" --prd=PRD/prd-klinik-demo.md </dev/null 2>/dev/null); R=$?
SHA=$(shasum -a 256 "$T/PRD/prd-klinik-demo.md" | awk '{print $1}')
python3 - "$J" "$SHA" "$R" <<'PYX' || rc=1
import json, sys
j = json.loads(sys.argv[1]); sha = sys.argv[2]; assert sys.argv[3] == "0"
assert j["schema"] == "plan-pins/1" and j["prd_path"] == "PRD/prd-klinik-demo.md", j
assert j["prd_sha256"] == sha, "sha mismatch"
assert j["author"] == "Pin Tester" and j["slug"] == "klinik-demo" and j["vault"] == ".mega-sdd/vaults/klinik-demo", j
assert j["project_scale"] in ("xs", "standard") and j["implementation_mode"] == "new" and j["vault_exists"] is False, j
assert j["project_scale"] == "standard", "clinic PRD is the standard-scale calibration fixture"
print("PASS: e: pins JSON (schema, rel path, sha256, git author, slug, vault default, scale standard, mode new, vault_exists false)")
PYX
mkdir -p "$T/.mega-sdd/vaults/klinik-demo"; : > "$T/.mega-sdd/vaults/klinik-demo/context.md"
J2=$(bash "$S" --cwd="$T" --prd=PRD/prd-klinik-demo.md --mode=existing </dev/null 2>/dev/null)
echo "$J2" | grep -q '"implementation_mode": "existing"' && echo "$J2" | grep -q '"vault_exists": true' && pass "e: --mode=existing + vault_exists true" || fail "e: mode/vault_exists ($J2)"
bash "$S" --cwd="$T" --prd=PRD/prd-klinik-demo.md --mode=weird </dev/null >/dev/null 2>&1; [ $? -eq 2 ] && pass "e: bad --mode → exit 2" || fail "e: bad mode exit"
rm -rf "$T"
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
