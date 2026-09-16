#!/usr/bin/env bash
# test-bounded-probe-rail.sh — spec docs/superpowers/specs/2026-09-16-bounded-network-probes.md (8.2.1).
#
# Field (F.4 run xs-lite-8.0.0-commentdiet): implementer U-004 ran `curl --retry 40 --retry-delay 3
# --retry-connrefused --max-time 120 http://localhost:3457/kontak` against a dev server that was never
# started — 72 min lost, the run's wall became NOT DATA. The acceptance runner was already bounded; the
# implementer's OWN Bash was not. This pins the mechanism, the same shape as the wave commit rail:
# while ANY unit is in flight, `curl --retry N` / `wget --tries N` with N >= 4 is DENIED naming the
# unit(s); bounded probes and non-probe commands pass; a quoted message never trips it; the rail is
# off once the in-flight window closes and in plugin-dev mode; both rails read ONE in-flight helper.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO/plugins/mega-sdd/hooks/pre-tool-use"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail=0
ok()  { echo "  ok: $1"; }
bad() { echo "  FAIL: $1"; fail=1; }

F="$WORK/proj"; V="$F/.mega-sdd/vaults/app"
mkdir -p "$V/bolts/U-007" "$F/src"
echo "dispatch" > "$V/bolts/U-007/dispatch-prompt.md"     # in flight (no postflight)

drive_armed() { # $1=command (subagent context — the implementer itself)
  printf '{"session_id":"s","agent_id":"a1","cwd":"%s","tool_name":"Bash","tool_input":{"command":%s}}' "$F" "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
    | bash "$HOOK" 2>/dev/null
}
deny()  { printf '%s' "$1" | grep -q '"deny"'; }
names() { printf '%s' "$1" | grep -q 'U-007'; }
probe() { printf '%s' "$1" | grep -q 'UNBOUNDED network probe'; }

echo "── unbounded probes DENIED while U-007 is in flight ──"
for c in "curl -s -o /tmp/x.html -w 'HTTP %{http_code}\n' --retry 40 --retry-delay 3 --retry-connrefused --max-time 120 http://localhost:3457/kontak" \
         "curl --retry 4 http://localhost:3000/health" "curl --retry=10 -sf http://localhost:8080/" \
         "wget --tries 20 http://localhost:3000/" "wget -t 5 -O /dev/null http://localhost:3000/" \
         "cd $F && curl --retry 3 http://a/ && curl --retry 8 http://b/"; do
  OUT=$(drive_armed "$c")
  deny "$OUT" && names "$OUT" && probe "$OUT" && ok "deny: $c" || bad "ALLOWED (should deny, naming U-007): $c → $(printf '%s' "$OUT" | head -c 120)"
done

echo "── bounded probes and non-probe commands PASS ──"
for c in "curl --retry 3 --max-time 60 http://localhost:3000/health" "curl -sf --max-time 30 http://localhost:3000/" \
         "curl http://localhost:3000/" "wget --tries 3 --timeout 60 http://localhost:3000/" \
         "git commit -m 'fix(U-007): stop using curl --retry 40 in tests'" "echo 'curl --retry 40' > notes.txt" \
         "pnpm test:run src/features" "npm run dev"; do
  OUT=$(drive_armed "$c")
  if deny "$OUT" && probe "$OUT"; then bad "false DENY: $c"; else ok "allow: $c"; fi
done

echo "── both hazards in one command: the wave rail message wins (one deny, sweeping verb is the worse hazard) ──"
OUT=$(drive_armed "git add -A && curl --retry 40 http://localhost:3000/")
deny "$OUT" && names "$OUT" && printf '%s' "$OUT" | grep -q 'sweeping git verb' && ok "combined hazard → single wave-rail deny" || bad "combined hazard not denied as wave rail: $(printf '%s' "$OUT" | head -c 160)"

echo "── in-flight window closes when postflight lands ──"
sleep 1; echo '{"status":"pass"}' > "$V/bolts/U-007/postflight.json"
OUT=$(drive_armed "curl --retry 40 http://localhost:3000/")
if deny "$OUT" && probe "$OUT"; then bad "rail still on after postflight.json is newer than dispatch-prompt"; else ok "unbounded probe allowed once no unit is in flight (not the adversary outside a bolt)"; fi

echo "── plugin-dev mode is exempt ──"
PD="$WORK/plugdev"; mkdir -p "$PD/plugins/mega-sdd/hooks" "$PD/.mega-sdd/vaults/app/bolts/U-001"
echo d > "$PD/.mega-sdd/vaults/app/bolts/U-001/dispatch-prompt.md"
OUT=$(printf '{"session_id":"s","agent_id":"a1","cwd":"%s","tool_name":"Bash","tool_input":{"command":"curl --retry 40 http://x/"}}' "$PD" | bash "$HOOK" 2>/dev/null)
if deny "$OUT"; then bad "plugin-dev tree denied the probe"; else ok "plugin-dev tree: rail off"; fi

echo "── contracts ──"
grep -q 'Bounded probes' "$REPO/plugins/mega-sdd/agents/bolt-implementer.md" && grep -q -- '--retry` ≤ 3' "$REPO/plugins/mega-sdd/agents/bolt-implementer.md" \
  && ok "implementer contract carries the bounded-probe rule (--retry ≤ 3, --max-time ≤ 60, NEEDS_CONTEXT not a wait)" || bad "implementer contract lacks the bounded-probe rule"
[ "$(grep -c 'vault_layouts.inflight_units' "$HOOK")" -ge 1 ] && grep -q 'PROBE_HAZARD' "$HOOK" && ok "hook classifies PROBE_HAZARD in the parse interpreter and reads the shared in-flight helper" || bad "hook lacks PROBE_HAZARD / shared helper"
grep -q 'bounded timeout (default 120s' "$REPO/plugins/mega-sdd/scripts/run-acceptance-tests.sh" && ok "acceptance runner stays bounded (120 s default) — the rail covers the implementer's OWN probes only" || bad "acceptance runner bound contract moved"

echo
[ "$fail" -eq 0 ] && { echo "bounded probe rail: ALL PASS"; exit 0; } || { echo "bounded probe rail: FAILED"; exit 1; }
