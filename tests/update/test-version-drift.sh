#!/usr/bin/env bash
# test-version-drift.sh — an update must land the newest version, and a stale one
# must never go unnoticed. Observed 2026-09-29: installed_plugins.json and the
# marketplace clone both sat at 8.7.2 while GitHub main was 9.0.0; the manual
# `/plugin marketplace update` step was skipped and no session noticed.
#   A  hooks/session-start: installed > running -> one reload line;
#      available > installed -> one update line; equal -> silent
#   B  dotted versions compare numerically (10.0.0 > 9.9.0), highest entry wins
#   C  missing / unreadable / garbage files, or CLAUDE_PLUGIN_ROOT unset -> silent, exit 0
#   D  no output line starts with mega-sdd-trace (gateway tag namespace, docs/gateway-contract.md)
#   E  commands/update-plugin.md: both CLI commands, no auto-accept, the deterministic verify
#   F  the Step 5 VERIFY command, run for real: clone == installed == 8.7.2 but its remote at 9.0.0
#      (the observed case: the session-start notice is silent there) -> FAIL, never PASS
# Hermetic: every run uses a scratch HOME and a scratch CLAUDE_PLUGIN_ROOT.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/plugins/mega-sdd/hooks/session-start"
CMD="$ROOT/plugins/mega-sdd/commands/update-plugin.md"
err=0; ok(){ echo "PASS: $*"; }; bad(){ echo "FAIL: $*"; err=1; }
T="$(mktemp -d)"; trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/proj/.mega-sdd"   # SDD signal: the hook prints its notices only in an SDD cwd
ALL="$T/all.out"; : > "$ALL"; n=0

# drift <running> <installed-versions, space-separated> <available> -> sets OUT, RC
drift() {
  n=$((n+1)); local H="$T/h$n" R="$T/r$n" e="" v
  mkdir -p "$H/.claude/plugins/marketplaces/mega-sdd/plugins/mega-sdd/.claude-plugin" "$R/.claude-plugin"
  printf '{"name":"mega-sdd","version":"%s"}\n' "$1" > "$R/.claude-plugin/plugin.json"
  printf '{"name":"mega-sdd","version":"%s"}\n' "$3" > "$H/.claude/plugins/marketplaces/mega-sdd/plugins/mega-sdd/.claude-plugin/plugin.json"
  for v in $2; do
    mkdir -p "$H/.claude/plugins/cache/mega-sdd/mega-sdd/$v"
    e="$e${e:+,}{\"scope\":\"user\",\"installPath\":\"$H/.claude/plugins/cache/mega-sdd/mega-sdd/$v\",\"version\":\"$v\"}"
  done
  # decoys on both sides: a sibling plugin's entries must never be read as mega-sdd@mega-sdd
  printf '{"version":2,"plugins":{"mega-sdd-extras@mega-sdd":[{"scope":"user","version":"99.0.0"}],"mega-sdd@mega-sdd":[%s],"superpowers@x":[{"version":"77.0.0"}]}}\n' "$e" \
    > "$H/.claude/plugins/installed_plugins.json"
  HD="$H"; RD="$R"
}
run() { OUT="$(cd "$T/proj" && printf '{"source":"startup","session_id":"t"}' | HOME="$HD" CLAUDE_PLUGIN_ROOT="$RD" bash "$HOOK" 2>/dev/null)"; RC=$?; printf '%s\n' "$OUT" >> "$ALL"; }
line() { printf '%s\n' "$OUT" | grep -E '^mega-sdd: (sesi ini masih|versi )' || true; }
quiet() { [ -z "$(line)" ] && [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q EXTREMELY_IMPORTANT; }  # silent, anchor intact
RELOAD() { echo "mega-sdd: sesi ini masih $1, versi $2 sudah ter-install — jalankan /reload-plugins (atau restart Claude Code)."; }
UPDATE() { echo "mega-sdd: versi $1 tersedia (ter-install $2) — jalankan /mega-sdd:update-plugin."; }

echo "── A: the three drift outcomes ──"
drift 9.0.0 "9.1.0" 9.1.0; run
[ "$(line)" = "$(RELOAD 9.0.0 9.1.0)" ] && [ "$RC" -eq 0 ] && ok "A1 installed > running -> reload line" || bad "A1 got [$(line)] rc=$RC"
drift 8.7.2 "8.7.2" 9.0.0; run
[ "$(line)" = "$(UPDATE 9.0.0 8.7.2)" ] && ok "A2 clone ahead of installed (after a marketplace refresh) -> update line" || bad "A2 got [$(line)]"
drift 9.0.0 "9.0.0" 9.0.0; run
[ -z "$(line)" ] && printf '%s' "$OUT" | grep -q EXTREMELY_IMPORTANT && ok "A3 all equal -> no drift line, anchor intact" || bad "A3 got [$(line)]"
drift 9.0.0 "9.1.0" 9.2.0; run
[ "$(line)" = "$(RELOAD 9.0.0 9.1.0)" ] && ok "A4 both drifts -> the reload line only (one line)" || bad "A4 got [$(line)]"

echo "── B: numeric, not lexical ──"
drift 9.9.0 "10.0.0" 10.0.0; run
[ "$(line)" = "$(RELOAD 9.9.0 10.0.0)" ] && ok "B1 10.0.0 > 9.9.0" || bad "B1 got [$(line)]"
drift 10.0.0 "9.9.0" 9.9.0; run
[ -z "$(line)" ] && ok "B2 running 10.0.0 vs installed 9.9.0 -> silent (lexical would flag it)" || bad "B2 got [$(line)]"
drift 9.2.0 "9.0.0 9.10.0 9.2.0" 9.10.0; run
[ "$(line)" = "$(RELOAD 9.2.0 9.10.0)" ] && ok "B3 highest of several entries (9.10.0) wins" || bad "B3 got [$(line)]"

echo "── C: fail-silent ──"
drift 8.7.2 "8.7.2" 9.0.0; rm "$HD/.claude/plugins/installed_plugins.json"; run
quiet && ok "C1 missing installed_plugins.json -> silent, exit 0, anchor intact" || bad "C1 got [$(line)] rc=$RC"
drift 8.7.2 "8.7.2" 9.0.0; printf 'not json {{{' > "$HD/.claude/plugins/installed_plugins.json"; run
quiet && ok "C2 garbage installed_plugins.json -> silent, exit 0, anchor intact" || bad "C2 got [$(line)] rc=$RC"
drift 8.7.2 "8.7.2" 9.0.0; chmod 000 "$HD/.claude/plugins/marketplaces/mega-sdd/plugins/mega-sdd/.claude-plugin/plugin.json"; run
quiet && ok "C3 unreadable clone plugin.json -> silent, exit 0, anchor intact" || bad "C3 got [$(line)] rc=$RC"
drift 9.0.0 "9.1.0" 9.1.0; chmod 000 "$RD/.claude-plugin/plugin.json"; run
quiet && ok "C4 unreadable running plugin.json -> silent, exit 0, anchor intact" || bad "C4 got [$(line)] rc=$RC"
drift 9.0.0 "9.1.0" 9.1.0; RD=""; run
quiet && ok "C5 CLAUDE_PLUGIN_ROOT unset -> silent, exit 0, anchor intact" || bad "C5 got [$(line)] rc=$RC"

echo "── D: gateway namespace ──"
grep -q '^mega-sdd-trace' "$ALL" && bad "D1 a line starts with mega-sdd-trace" || ok "D1 no output line starts with mega-sdd-trace"

echo "── E: update-plugin.md is a forced, verified update ──"
grep -qF 'claude plugin marketplace update mega-sdd' "$CMD" && ok "E1 refreshes the marketplace via the CLI" || bad "E1 marketplace update command missing"
grep -qF 'claude plugin update mega-sdd@mega-sdd -s user' "$CMD" && grep -qF 'claude plugin update mega-sdd-extras@mega-sdd -s user' "$CMD" \
  && ok "E2 updates mega-sdd (+ extras when installed) via the CLI" || bad "E2 plugin update commands missing"
grep -qE 'plugin update [^`]*(-y|--yes|--accept-command)' "$CMD" && bad "E3 an update command auto-accepts" || ok "E3 no -y / --accept-command on the update commands"
grep -qF 'installed == available' "$CMD" && grep -qF 'installPath' "$CMD" && grep -qF 'VERIFY: FAIL' "$CMD" \
  && ok "E4 deterministic verify: installed == available + installPath exists, FAIL reported" || bad "E4 verify step missing"
grep -qF '/reload-plugins' "$CMD" && ok "E5 closes with /reload-plugins" || bad "E5 reload instruction missing"
grep -qF 'If it exits non-zero, do NOT continue' "$CMD" && ok "E6 a failed marketplace update stops with VERIFY: FAIL" || bad "E6 non-zero-exit stop rule missing"

echo "── F: VERIFY checks the clone against its remote ──"
V="$(grep -m1 '^C=~/.claude/plugins/marketplaces/mega-sdd; ' "$CMD")"
G() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@" >/dev/null 2>&1; }
H="$T/hv"; PJ=plugins/mega-sdd/.claude-plugin/plugin.json; M="$H/.claude/plugins/marketplaces/mega-sdd"
mkdir -p "$T/up/plugins/mega-sdd/.claude-plugin" "$H/.claude/plugins/cache/mega-sdd/mega-sdd/8.7.2" "$H/.claude/plugins/cache/mega-sdd/mega-sdd/9.0.0"
printf '{"version":"8.7.2"}\n' > "$T/up/$PJ"; G -C "$T/up" init; G -C "$T/up" add -A; G -C "$T/up" commit -m 8.7.2
G clone "$T/up" "$M"
printf '{"version":"9.0.0"}\n' > "$T/up/$PJ"; G -C "$T/up" commit -am 9.0.0   # GitHub main moves on; the clone is never refreshed
inst() { printf '{"plugins":{"mega-sdd@mega-sdd":[{"scope":"user","version":"%s","installPath":"%s"}]}}\n' "$1" "$H/.claude/plugins/cache/mega-sdd/mega-sdd/$1" > "$H/.claude/plugins/installed_plugins.json"; }
verify() { (cd "$T" && HOME="$H" bash -c "$V" 2>&1); }
inst 8.7.2
[ -n "$V" ] && verify | grep -q '^VERIFY: FAIL remote=NOT-CURRENT installed=8.7.2 available=8.7.2' \
  && ok "F1 stale clone (8.7.2, remote 9.0.0) -> VERIFY: FAIL remote=NOT-CURRENT" || bad "F1 got [$(verify)]"
G -C "$M" pull --ff-only; inst 9.0.0
verify | grep -q '^VERIFY: PASS remote=current installed=9.0.0 available=9.0.0' && ok "F2 refreshed clone + installed 9.0.0 -> VERIFY: PASS" || bad "F2 got [$(verify)]"
inst 8.7.2
verify | grep -q '^VERIFY: FAIL remote=current installed=8.7.2 available=9.0.0' && ok "F3 clone refreshed, plugin not updated -> FAIL" || bad "F3 got [$(verify)]"

echo; [ $err -eq 0 ] && { echo "test-version-drift: ALL PASS"; exit 0; } || { echo "test-version-drift: FAILED"; exit 1; }
