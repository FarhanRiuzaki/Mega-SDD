#!/usr/bin/env bash
# v8 P0 live finding (clinic baseline arm, 2026-09-10): generate-intent wrote ONE
# blocker envelope body as a MAPPING under `blockers:`; the validator FAILed
# handoff_type_mismatch with a hint that did not say how to fix it, the contract
# pointed at a `§blocker envelope` section that does not exist, and the hook's
# deny message invited deleting the state file (which resets the retry counter).
# Pins: mapping → FAIL with the "wrap it" hint; documented list shape → PASS;
# contract + teacher define the entry shape; hook never suggests the rm.
# Run: bash tests/handoff/test-blockers-shape.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; V="$P/scripts/validate-handoff-yaml.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; mkdir -p "$T/.mega-sdd/vaults/clinic"; echo x > "$T/.mega-sdd/vaults/clinic/vault.md"
mk() { cat > "$T/resp.md" <<MD
done.

\`\`\`yaml
handoff:
  schema_version: "1.0"
  emitted_by: generate-intent
  emitted_at: "2026-09-10T15:28:55Z"
  status: halted
  vault: .mega-sdd/vaults/clinic
  artifacts: [".mega-sdd/vaults/clinic/vault.md"]
  next_action:
    suggested_skill: "mega-sdd:resolve-oq"
    suggested_args: ["--auto"]
    rationale: "two business OQs block units"
$1
\`\`\`
MD
}
mk $'  blockers:\n    emitted_by: generate-intent\n    details: "{ oq_ids: [OQ-CN-1, OQ-CN-2], resolver_route: user }"'
bash "$V" --cwd="$T" --response-file="$T/resp.md" --skill-name=mega-sdd:generate-intent >/dev/null 2>&1; RC=$?
python3 - "$T/.mega-sdd/.handoff-validation-state.json" "$RC" <<'EOF2' && pass "a: mapping under blockers → FAIL handoff_type_mismatch with the 'wrap it' hint (exit 1)" || fail "a: mapping shape not caught / hint missing"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
assert d["status"] == "FAIL" and rc == 1 and d["halt_type"] == "handoff_type_mismatch", (d["status"], rc, d.get("halt_type"))
errs = " ".join(d["details"].get("type_errors", []))
assert "blockers must be a LIST of envelope bodies" in errs and "wrap it" in errs, errs
EOF2
rm -f "$T/.mega-sdd/.handoff-validation-state.json"
mk $'  blockers:\n    - type: oq_blocker\n      emitted_by: generate-intent\n      details: { oq_ids: [OQ-CN-1, OQ-CN-2], resolver_route: user }'
bash "$V" --cwd="$T" --response-file="$T/resp.md" --skill-name=mega-sdd:generate-intent >/dev/null 2>&1; RC=$?
[ $RC -eq 0 ] && python3 -c "import json;d=json.load(open('$T/.mega-sdd/.handoff-validation-state.json'));assert d['status']=='PASS',d" && pass "b: documented list-of-envelope-bodies shape → PASS (exit 0)" || fail "b: list shape rejected (rc=$RC)"
grep -q 'each entry is the body of ONE `blocker:` envelope' "$P/skills/orchestrate-flow/references/handoff-contract.md" && ! grep -q 'per halt-protocol `§blocker envelope`' "$P/skills/orchestrate-flow/references/handoff-contract.md" \
  && pass "c: handoff-contract §blockers defines the entry shape and no longer points at a non-existent section" || fail "c: contract still dangling"
grep -q 'a LIST of envelope bodies' "$P/skills/generate-intent/references/auto-and-handoff.md" && pass "d: generate-intent teacher shows the populated shape on halt" || fail "d: teacher still says only 'populated on halt'"
! grep -q 'delete the stale state file manually' "$P/hooks/pre-tool-use" && grep -q 'Do NOT delete or edit' "$P/hooks/pre-tool-use" && pass "e: hook deny message no longer invites a state-file reset" || fail "e: hook still suggests rm of the state file"
# ── v8 P2 live finding (xs-classic arm 2026-09-11, same seam) ────────────────
rm -f "$T/.mega-sdd/.handoff-validation-state.json"
mk $'  blockers:\n    - type: bind_conflict\n      emitted_by: bind-codebase\n      details:\n        conflicts:\n          - id: CONFLICT-1\n            claim: "three public pages without login"\n            code: src/proxy.ts:11\n        summary: one active conflict\n      next_action: "resolve-oq --binding"\n    - type: oq_blocker\n      emitted_by: bind-codebase\n      details: { oq_ids: [OQ-AR-2] }'
bash "$V" --cwd="$T" --response-file="$T/resp.md" --skill-name=mega-sdd:bind-codebase >/dev/null 2>&1; RC=$?
[ $RC -eq 0 ] && python3 -c "import json;d=json.load(open('$T/.mega-sdd/.handoff-validation-state.json'));assert d['status']=='PASS',d" \
  && pass "f: a block list NESTED inside a blocker body + an outer key after it → still ONE blocker each, PASS (exit 0)" || fail "f: nested list inside blocker body rejected (rc=$RC) — the xs-classic deadlock shape"
grep -q 'MUST be the LAST assistant TEXT of your reply' "$P/hooks/pre-tool-use" && pass "g: hook deny message names the legal path (corrected handoff = last assistant TEXT)" || fail "g: hook deny message silent on the transcript-text requirement"
n_bad=$(grep -rn '^\s*blockers: \[\]' "$P/skills" --include='*.md' | grep -vc 'LIST of envelope bodies'); [ "$n_bad" -eq 0 ] && pass "h: every handoff teacher's blockers line carries the flat-shape pointer" || fail "h: $n_bad teacher(s) still show blockers: [] without the shape pointer"
grep -q 'nested inside an entry' "$P/skills/orchestrate-flow/references/handoff-contract.md" && pass "i: contract documents the nested-list acceptance" || fail "i: contract silent on nested lists"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
