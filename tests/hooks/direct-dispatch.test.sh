#!/usr/bin/env bash
# v7.5.0 Fase 7 №A — direct hook dispatch contract.
#
# hooks.json used to route every event through run-hook.sh (bash → dirname →
# uname → bash <body> = 4 procs per matched event, the Fase-7 audit's headline).
# Direct dispatch deletes the middle layer; what run-hook.sh used to do for
# Windows — normalize a backslash-separated $0 — must now live in EVERY body
# (HOOK_SELF). This suite pins:
#   D1  every hooks.json command targets an EXISTING hooks/<name> body directly
#       (no run-hook.sh reference anywhere) — existence-checked, so a renamed
#       body cannot pass silently (the p6 §D fail-open lesson);
#   D2  every body carries the HOOK_SELF normalization before any $0 use;
#   D3  functional Windows-separator proof (the ntpath-from-macOS pattern):
#       a body invoked with a BACKSLASH-separated $0 must still resolve its
#       helpers — the anti-forge deny (moat) fires identically to a
#       forward-slash $0. Proven by sourcing the real file with a mocked $0
#       whose hooks component uses '\' (macOS paths may contain backslashes,
#       so the normalized twin is a real path).
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGIN="$REPO/plugins/mega-sdd"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

HOOK_BODIES="pre-tool-use post-tool-use session-start stop user-prompt-submit user-prompt-expansion"

# ── D1: hooks.json → direct, existing targets, zero run-hook residue ─────────
if grep -q 'run-hook' "$PLUGIN/hooks/hooks.json"; then
  bad "D1: hooks.json still references run-hook.sh"
else
  ok "D1a: hooks.json carries no run-hook reference"
fi
MISS=0
while IFS= read -r target; do
  [ -f "$PLUGIN/hooks/$target" ] || { bad "D1: hooks.json targets hooks/$target which does NOT exist"; MISS=1; }
done < <(PLUGIN="$PLUGIN" python3 -c '
import json, os, re
h = json.load(open(os.environ["PLUGIN"] + "/hooks/hooks.json"))["hooks"]
seen = set()
for ev, groups in h.items():
    for g in groups:
        for hk in g["hooks"]:
            m = re.search(r"/hooks/([a-z-]+)\"", hk["command"])
            assert m, hk["command"]
            seen.add(m.group(1))
print("\n".join(sorted(seen)))
')
[ "$MISS" -eq 0 ] && ok "D1b: every hooks.json command targets an existing hooks/<name> body"
[ -f "$PLUGIN/hooks/run-hook.sh" ] && bad "D1: run-hook.sh still exists on disk" \
  || ok "D1c: run-hook.sh deleted"

# ── D2: HOOK_SELF guard present in every body, before any derived-path use ───
for b in $HOOK_BODIES; do
  if grep -q 'HOOK_SELF="${0//\\\\//}"' "$PLUGIN/hooks/$b"; then
    if grep -nE '\$\{0%/\*\}|dirname "\$0"|case "\$0" in' "$PLUGIN/hooks/$b" >/dev/null; then
      bad "D2: $b still derives paths from raw \$0"
    else
      ok "D2: $b normalizes \$0 (HOOK_SELF) and uses only the normalized form"
    fi
  else
    bad "D2: $b is missing the HOOK_SELF backslash guard"
  fi
done

# ── D3: functional — backslash-separated $0 behaves identically ──────────────
# Fixture: SDD project; the probe event is a FORGED-VERDICT Write (moat deny,
# always-on even un-armed) — it exercises the $0-derived resolver walk, so a
# broken derivation shows up as a missing deny, not a silent pass.
FIX="$WORK/proj"; mkdir -p "$FIX/.mega-sdd"
JSON="{\"session_id\":\"s\",\"cwd\":\"$FIX\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$FIX/.mega-sdd/.validation-blockers.json\",\"content\":\"{}\"}}"
REAL="$PLUGIN/hooks/pre-tool-use"
FWD0="$PLUGIN/hooks/pre-tool-use"
BCK0="$PLUGIN/hooks"$'\\'"pre-tool-use"   # last separator as backslash — the Windows shape
OUT_FWD=$(printf '%s' "$JSON" | REAL="$REAL" bash -c '. "$REAL"' "$FWD0" 2>/dev/null)
OUT_BCK=$(printf '%s' "$JSON" | REAL="$REAL" bash -c '. "$REAL"' "$BCK0" 2>/dev/null)
printf '%s' "$OUT_FWD" | grep -q '"deny"' && F=1 || F=0
printf '%s' "$OUT_BCK" | grep -q '"deny"' && B=1 || B=0
if [ "$F" -eq 1 ] && [ "$B" -eq 1 ] && [ "$OUT_FWD" = "$OUT_BCK" ]; then
  ok "D3: forged-verdict Write DENIED identically under forward- and backslash-separated \$0"
else
  bad "D3: \$0 separator changed behavior (fwd deny=$F bck deny=$B, identical=$([ "$OUT_FWD" = "$OUT_BCK" ] && echo yes || echo no))"
fi
# Tier-S silence must also survive the backslash shape (no spurious output).
mkdir -p "$FIX/src"; echo x > "$FIX/src/app.js"
JSON2="{\"session_id\":\"s\",\"cwd\":\"$FIX\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$FIX/src/app.js\",\"old_string\":\"a\",\"new_string\":\"b\"}}"
OUT2=$(printf '%s' "$JSON2" | REAL="$REAL" bash -c '. "$REAL"' "$BCK0" 2>/dev/null)
[ -z "$OUT2" ] && ok "D3b: tier-S Edit silent under backslash-separated \$0" \
  || bad "D3b: tier-S Edit produced output under backslash \$0: [$OUT2]"

echo
if [ "$fail" -eq 0 ]; then echo "PASS direct-dispatch contract"; exit 0
else echo "direct-dispatch contract FAILED"; exit 1; fi
