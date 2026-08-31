#!/usr/bin/env bash
# test-update-plugin-sweep.sh — 7.15.0 (spec 2026-08-31-update-plugin-cache-sweep.md).
#
# The update-plugin one-timer sweeps dormant cache version dirs — confirm-first,
# never silent. Structural pins on the command procedure:
#   A  Step 5.5 exists and derives the referenced set from installed_plugins.json
#      across ANY scope (never entry [0] — the historical wrapper bug)
#   B  deletion is confirm-first: ONE AskUserQuestion, keterangan, and the
#      other-sessions warning (parallel long-lived sessions may hold a dormant path)
#   C  the path guard: only exact cache/mega-sdd/mega-sdd/<version> prefixes,
#      and a referenced version is NEVER deleted
#   D  the honesty clause: the sweep is hygiene, not the latest-version guarantee
#      (that stays /plugin marketplace update + /reload-plugins)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CMD="$ROOT/plugins/mega-sdd/commands/update-plugin.md"
err=0; ok(){ echo "  ok: $*"; }; bad(){ echo "  FAIL: $*"; err=1; }

[ -f "$CMD" ] || { echo "  FAIL: command file missing"; exit 1; }

echo "── A: the sweep step + referenced-set derivation ──"
grep -q "Step 5.5 — Dormant-cache sweep" "$CMD" && ok "A1 Step 5.5 present" || bad "A1 sweep step missing"
grep -q "installed_plugins.json" "$CMD" && grep -q "ANY scope" "$CMD" && ok "A2 referenced set = installed_plugins.json, any scope" || bad "A2 referenced-set rule missing"
grep -qF 'never just entry `[0]`' "$CMD" && ok "A3 the [0] wrapper-bug lesson is pinned in the procedure" || bad "A3 [0] lesson missing"

echo "── B: confirm-first ──"
grep -q "confirm-first, NEVER silent" "$CMD" && ok "B1 never-silent rail stated" || bad "B1 never-silent rail missing"
grep -q "AskUserQuestion" "$CMD" && grep -q "keterangan in Indonesian" "$CMD" && ok "B2 one AskUserQuestion with keterangan" || bad "B2 confirmation contract missing"
grep -q "sesi Claude Code lain yang masih jalan" "$CMD" && ok "B3 parallel-session warning present" || bad "B3 other-sessions warning missing"

echo "── C: the path guard ──"
grep -qF 'cache/mega-sdd/mega-sdd/<version>' "$CMD" && grep -q "no globs outside that prefix" "$CMD" && ok "C1 exact-prefix guard" || bad "C1 path guard missing"
grep -q "referenced version is NEVER in the list" "$CMD" && ok "C2 referenced versions never deleted" || bad "C2 referenced-kept clause missing"

echo "── D: honesty clause ──"
grep -q "Honesty clause" "$CMD" && grep -q "never present the sweep as that guarantee" "$CMD" && ok "D1 sweep = hygiene, not the latest guarantee" || bad "D1 honesty clause missing"

echo; [ $err -eq 0 ] && { echo "test-update-plugin-sweep: ALL PASS"; exit 0; } || { echo "test-update-plugin-sweep: FAILED"; exit 1; }
