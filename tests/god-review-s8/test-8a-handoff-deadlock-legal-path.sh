#!/usr/bin/env bash
# S8-a — moat class "model bypasses Skill dispatch on a handoff deadlock" (owner
# amendment 3, v8 P2; live instances: clinic arm 2026-09-10, xs-classic arm 2026-09-11).
# A halted handoff with a populated blockers[] MUST be passable through the LEGAL
# path (producer re-run + the corrected handoff as the last assistant TEXT → the
# gate recomputes → PASS), and every NON-Skill way around the gate MUST stay denied.
#   1 validator: the live bad shape → FAIL handoff_type_mismatch (state written, retry 1)
#   2 hook: downstream Skill (resolve-oq) DENIED while FAIL; the deny names the legal path
#   3 hook: the producer (bind-codebase) is ALLOWED to re-run (self-fix)
#   4 hook: corrected handoff (the xs-classic NESTED shape) as the last assistant TEXT →
#     gate recompute → state PASS → resolve-oq ALLOWED
#   5 hook: a narration-only last text keeps the prior verdict (no recompute) — PASS stays
#   6 bypass: Write / Edit / Bash-rm of .handoff-validation-state.json → DENIED
#   7 bypass: writing bolt evidence (bolts/U-001/binding.json) by Bash or Write → DENIED
# Run: bash tests/god-review-s8/test-8a-handoff-deadlock-legal-path.sh </dev/null
set -uo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"; PLUGIN="$REPO/plugins/mega-sdd"; HOOK="$PLUGIN/hooks/pre-tool-use"; V="$PLUGIN/scripts/validate-handoff-yaml.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
rc=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; rc=1; }
F="$WORK/proj"; VD="$F/.mega-sdd/vaults/v"; mkdir -p "$VD/units" "$VD/bolts/U-001" "$F/src"
echo "# v" > "$VD/vault.md"; echo "# binding" > "$VD/binding.md"; printf -- '---\nunit_id: U-001\ntask_type: create\ntarget_files:\n  - path: src/a.js\n    operation: create\n---\n# U-001\n' > "$VD/units/U-001.md"
( cd "$F" && git init -q . && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m seed )
SID="s8a"; TR="$WORK/transcript.jsonl"; STATE="$F/.mega-sdd/.handoff-validation-state.json"
# the chain is ENGAGED (every mega-sdd:* Skill dispatch writes this marker in a real run) — the Write/Edit guards arm on it
printf '{"session_id":"%s","chain_engaged":true,"entries":{},"engaged_sessions":{"%s":true}}' "$SID" "$SID" > "$F/.mega-sdd/.gateguard-state.json"
drive() { printf '%s' "$1" | bash "$HOOK" 2>/dev/null; }
# payload <tool_name> key=value… — built by python (json.dumps): a bash printf of `{a,b}`
# text trips BRACE EXPANSION and silently corrupts the JSON (the hook then exits 0 on a
# parse failure — which would read as "not denied"). Never build hook payloads by hand.
payload() { python3 - "$SID" "$F" "$TR" "$@" <<'PYX'
import json, sys
sid, cwd, tr, tool = sys.argv[1:5]
ti = {}
for kv in sys.argv[5:]:
    k, _, v = kv.partition("="); ti[k] = v
print(json.dumps({"session_id": sid, "cwd": cwd, "transcript_path": tr, "tool_name": tool, "tool_input": ti}))
PYX
}
skill() { payload Skill "skill=$1" "args=${2:-}"; }
asst()  { python3 -c 'import json,sys; print(json.dumps({"message":{"role":"assistant","content":[{"type":"text","text":sys.argv[1]}]}}))' "$1" >> "$TR"; }
BAD=$'```yaml\nhandoff:\n  schema_version: "1.0"\n  emitted_by: bind-codebase\n  emitted_at: "2026-09-11T01:14:47Z"\n  status: halted\n  vault: .mega-sdd/vaults/v\n  artifacts: [".mega-sdd/vaults/v/binding.md"]\n  next_action:\n    suggested_skill: "mega-sdd:resolve-oq"\n    suggested_args: ["--binding", "--auto"]\n    rationale: "one CONFLICT"\n  blockers:\n    emitted_by: bind-codebase\n    details: "CONFLICT-1"\n```'
GOOD=$'```yaml\nhandoff:\n  schema_version: "1.0"\n  emitted_by: bind-codebase\n  emitted_at: "2026-09-11T01:15:43Z"\n  status: halted\n  vault: .mega-sdd/vaults/v\n  artifacts: [".mega-sdd/vaults/v/binding.md"]\n  next_action:\n    suggested_skill: "mega-sdd:resolve-oq"\n    suggested_args: ["--binding", "--auto"]\n    rationale: "one CONFLICT"\n  blockers:\n    - type: bind_conflict\n      emitted_by: bind-codebase\n      details:\n        conflicts:\n          - id: CONFLICT-1\n            claim: "three public pages without login"\n            code: src/proxy.ts:11\n        summary: one active conflict\n      next_action: "resolve-oq --binding"\n```'

# 1 — the live bad shape → FAIL state
printf '{"message":{"role":"user","content":"lanjut"}}\n' > "$TR"; asst "$BAD"
printf '%s' "$BAD" > "$WORK/bad.md"; bash "$V" --cwd="$F" --response-file="$WORK/bad.md" --skill-name=mega-sdd:bind-codebase >/dev/null 2>&1; R1=$?
[ "$R1" -eq 1 ] && python3 -c "import json;d=json.load(open('$STATE'));assert d['status']=='FAIL' and d['halt_type']=='handoff_type_mismatch' and d['skill_name']=='mega-sdd:bind-codebase',d" \
  && ok "1: bad blockers shape → FAIL handoff_type_mismatch, producer recorded" || bad "1: validator rc=$R1 / state wrong"
# 2 — downstream Skill denied; deny names the legal path
OUT=$(drive "$(skill mega-sdd:resolve-oq --binding)")
printf '%s' "$OUT" | grep -q '"deny"' && printf '%s' "$OUT" | grep -q 'blocked by handoff validation' && ok "2: resolve-oq DENIED while the handoff verdict is FAIL" || bad "2: resolve-oq not denied ($(printf '%s' "$OUT" | head -c 160))"
printf '%s' "$OUT" | grep -q 'LAST assistant TEXT' && ok "2: deny message names the legal path (corrected handoff = last assistant TEXT)" || bad "2: deny message silent on the transcript-text requirement"
printf '%s' "$OUT" | grep -q 'Do NOT delete or edit' && ! printf '%s' "$OUT" | grep -qi 'rm .*handoff-validation-state' && ok "2: deny message never invites a state reset" || bad "2: deny message invites a reset"
# 3 — producer self-fix allowed
OUT=$(drive "$(skill mega-sdd:bind-codebase --express)")
printf '%s' "$OUT" | grep -q '"deny"' && bad "3: producer re-run DENIED (self-fix path closed)" || ok "3: producer (bind-codebase) re-run ALLOWED"
# 4 — legal path: corrected NESTED-shape handoff as the LAST assistant text → recompute → PASS → allowed
asst "$GOOD"
OUT=$(drive "$(skill mega-sdd:resolve-oq --binding)")
python3 -c "import json;d=json.load(open('$STATE'));assert d['status']=='PASS',d" 2>/dev/null && ! printf '%s' "$OUT" | grep -q '"deny"' \
  && ok "4: corrected handoff as last assistant TEXT → gate recompute → PASS → resolve-oq ALLOWED" || bad "4: legal path blocked (state=$(python3 -c "import json;print(json.load(open('$STATE'))['status'])" 2>/dev/null) out=$(printf '%s' "$OUT" | head -c 160))"
# 5 — narration-only last text keeps the verdict
asst "Bind selesai; lanjut resolve-oq."
OUT=$(drive "$(skill mega-sdd:resolve-oq --binding)")
python3 -c "import json;d=json.load(open('$STATE'));assert d['status']=='PASS',d" 2>/dev/null && ! printf '%s' "$OUT" | grep -q '"deny"' && ok "5: narration-only last text → prior PASS stays authoritative" || bad "5: narration flipped the verdict"
# 6 — re-establish FAIL, then every non-Skill way around the gate is denied
bash "$V" --cwd="$F" --response-file="$WORK/bad.md" --skill-name=mega-sdd:bind-codebase >/dev/null 2>&1
printf '{"message":{"role":"user","content":"lanjut"}}\n' > "$TR"; asst "$BAD"
OUT=$(drive "$(payload Write "file_path=$STATE" 'content={"status":"PASS"}')")
printf '%s' "$OUT" | grep -q '"deny"' && ok "6: Write of a forged PASS into .handoff-validation-state.json DENIED" || bad "6: Write forge NOT denied ($(printf '%s' "$OUT" | head -c 120))"
OUT=$(drive "$(payload Edit "file_path=$STATE" old_string=FAIL new_string=PASS)")
printf '%s' "$OUT" | grep -q '"deny"' && ok "6: Edit of the handoff verdict DENIED" || bad "6: Edit forge NOT denied"
OUT=$(drive "$(payload Bash "command=rm $STATE")")
printf '%s' "$OUT" | grep -q '"deny"' && ok "6: Bash rm of the handoff verdict DENIED (retry counter cannot be reset)" || bad "6: Bash rm NOT denied ($(printf '%s' "$OUT" | head -c 120))"
OUT=$(drive "$(payload Bash "command=echo '{\"status\":\"PASS\"}' > $STATE")")
printf '%s' "$OUT" | grep -q '"deny"' && ok "6: Bash redirect into the handoff verdict DENIED" || bad "6: Bash redirect NOT denied"
[ -f "$STATE" ] && python3 -c "import json;d=json.load(open('$STATE'));assert d['status']=='FAIL'" && ok "6: state file intact (FAIL) after every bypass attempt" || bad "6: state file changed"
# 7 — manual procedure writing bolt evidence is denied (artefact gate, not who executes)
OUT=$(drive "$(payload Bash "command=echo '{}' > $VD/bolts/U-001/binding.json")")
printf '%s' "$OUT" | grep -q '"deny"' && ok "7: Bash write of bolts/U-001/binding.json DENIED (evidence rail)" || bad "7: Bash evidence write NOT denied ($(printf '%s' "$OUT" | head -c 120))"
OUT=$(drive "$(payload Write "file_path=$VD/bolts/U-001/binding.json" 'content={}')")
printf '%s' "$OUT" | grep -q '"deny"' && ok "7: Write of bolts/U-001/binding.json DENIED (evidence rail)" || bad "7: Write evidence NOT denied"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
