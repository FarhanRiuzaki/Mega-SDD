#!/usr/bin/env bash
# The gateway observability contract (docs/gateway-contract.md) survives 9.0 — owner requirement
# 2026-09-27: "kontrak observability di gateway tetap wajib dipertahankan (mega-sdd-trace,
# mega-sdd-note, dll)". Behaviour of the hooks is pinned by tests/hooks/* and
# tests/session-note/*; this file pins the CONTRACT SURFACE across the 9.0 changes:
#   - the direct/assisted lanes (no .mega-sdd/, no skill) still tag the session and their one subagent;
#   - every skill with an "Announce at start" line ends it with its own verbatim tag, and the
#     contract's list of announcing skills matches the tree;
#   - the hook emitters of :turn and mega-sdd-note: are still wired.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; C="$ROOT/docs/gateway-contract.md"
rc=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; rc=1; }
for tag in 'mega-sdd-trace:direct' 'mega-sdd-trace:assisted' 'mega-sdd-trace:assisted-review'; do
  grep -qF "$tag" "$P/references/direct-lane.md" && ok "direct-lane.md emits $tag" || bad "direct-lane.md lost $tag"
  grep -qF "\`$tag\`" "$C" && ok "gateway-contract.md lists $tag" || bad "gateway-contract.md does not list $tag"
done
grep -qE '^\s*- the line `mega-sdd-trace:assisted-review`, on its own line' "$P/references/direct-lane.md" \
  && ok "the assisted review dispatch prompt carries the trace line" || bad "assisted review dispatch lost its trace line"
announcers=""
for d in "$P"/skills/*/; do
  s=$(basename "$d"); f="$d/SKILL.md"
  if grep -q 'Announce at start' "$f"; then
    grep -qE "Announce at start.*\`mega-sdd-trace:$s\`" "$f" && ok "$s announce ends with mega-sdd-trace:$s" || bad "$s announce line lacks its verbatim tag"
    announcers="$announcers $s"
  fi
done
n=$(echo $announcers | wc -w | tr -d ' ')
grep -q "ada $n skill yang ber-announce" "$C" && ok "contract count of announcing skills = $n" || bad "contract count of announcing skills != $n (tree:$announcers)"
for s in $announcers; do grep -q "$s" <(sed -n '/ada [0-9]* skill yang ber-announce/p' "$C") || bad "contract list misses announcing skill $s"; done
grep -qF 'mega-sdd-trace:turn' "$P/hooks/user-prompt-submit" && ok "user-prompt-submit still emits mega-sdd-trace:turn" || bad "user-prompt-submit lost mega-sdd-trace:turn"
grep -qF 'mega-sdd-note:' "$P/hooks/session-note" && grep -q 'session-note' "$P/hooks/hooks.json" && ok "session-note still emits mega-sdd-note: and is wired" || bad "mega-sdd-note emitter/wiring lost"
grep -qF 'mega-sdd-trace' "$P/scripts/build-dispatch-prompt.sh" && ok "bolt dispatch prompts still carry the trace line" || bad "build-dispatch-prompt.sh lost the trace line"
exit $rc
