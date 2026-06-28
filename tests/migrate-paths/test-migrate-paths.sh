#!/usr/bin/env bash
# Fixture test for plugins/mega-sdd/scripts/migrate-paths.sh (audit finding C6).
# Builds a throwaway multi-vault legacy-layout git repo and asserts the vetted
# migration script: dry-run no-op, real migration (moves + git-history marker +
# sed reference rewrites + .bak cleanup + config.yaml), idempotent re-run,
# dirty-tree refusal, and target-exists conflict.
set -u
err=0

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/plugins/mega-sdd/scripts/migrate-paths.sh"
[ -f "$SCRIPT" ] || { echo "FATAL: script not found at $SCRIPT"; exit 1; }

GIT="git -c user.email=t@t -c user.name=t"

# mk_legacy_repo DIR — populate DIR with a clean, committed legacy layout whose
# vault.json carries EVERY legacy path pattern the rewrite touches.
mk_legacy_repo() {
  local d="$1"
  mkdir -p "$d"
  ( cd "$d" && git init -q . )
  mkdir -p "$d/docs/mega-sdd/vaults/alpha/.mega-sdd/checkpoints" \
           "$d/docs/mega-sdd/vaults/beta" \
           "$d/docs/knowledge-base" \
           "$d/.mega-sdd-memory"
  cat > "$d/docs/mega-sdd/vaults/alpha/vault.json" <<'JSON'
{
  "vault_source": "docs/mega-sdd/vaults/alpha/vault.json",
  "kb_ref": "docs/knowledge-base/kb.md",
  "memory_ref": "/.mega-sdd-memory/notes.md",
  "internal_ref": "<vault>/.mega-sdd/checkpoints"
}
JSON
  cat > "$d/docs/mega-sdd/vaults/beta/vault.json" <<'JSON'
{ "vault_source": "docs/mega-sdd/vaults/beta/vault.json" }
JSON
  echo "checkpoint" > "$d/docs/mega-sdd/vaults/alpha/.mega-sdd/checkpoints/c.txt"
  echo "kb" > "$d/docs/knowledge-base/kb.md"
  echo "map" > "$d/codebase-map.md"
  echo "note" > "$d/.mega-sdd-memory/notes.md"
  ( cd "$d" && $GIT add -A && $GIT commit -qm "legacy layout" )
}

# ---- Scenario A: --dry-run mutates nothing ----
A=$(mktemp -d); trap 'rm -rf "$A"' EXIT
mk_legacy_repo "$A"
outA=$(bash "$SCRIPT" --dry-run --cwd="$A" 2>&1); rcA=$?
[ $rcA -eq 0 ] || { echo "A: dry-run expected exit 0, got $rcA"; err=1; }
[ -d "$A/docs/mega-sdd/vaults" ] || { echo "A: dry-run moved legacy vaults (should not)"; err=1; }
[ -f "$A/codebase-map.md" ] || { echo "A: dry-run moved codebase-map.md (should not)"; err=1; }
[ ! -d "$A/.mega-sdd/vaults" ] || { echo "A: dry-run created .mega-sdd/vaults (should not)"; err=1; }
echo "$outA" | grep -q 'plan:' || { echo "A: dry-run output lacks a plan line"; err=1; }
[ $err -eq 0 ] && echo "A PASS (dry-run is a no-op)"

# ---- Scenario B: real migration ----
B=$(mktemp -d); trap 'rm -rf "$A" "$B"' EXIT
mk_legacy_repo "$B"
errB=0
outB=$(bash "$SCRIPT" --cwd="$B" 2>&1); rcB=$?
[ $rcB -eq 0 ] || { echo "B: migrate expected exit 0, got $rcB"; errB=1; }
# moves
[ -f "$B/.mega-sdd/vaults/alpha/vault.json" ] || { echo "B: alpha vault not moved"; errB=1; }
[ -f "$B/.mega-sdd/vaults/beta/vault.json" ]  || { echo "B: beta vault not moved"; errB=1; }
[ ! -f "$B/codebase-map.md" ]                 || { echo "B: codebase-map.md not moved out of root"; errB=1; }
[ -f "$B/.mega-sdd/codebase/codebase-map.md" ]|| { echo "B: codebase-map.md not at canonical path"; errB=1; }
[ -f "$B/.mega-sdd/memory/notes.md" ]         || { echo "B: memory not moved"; errB=1; }
[ ! -d "$B/.mega-sdd-memory" ]                || { echo "B: legacy memory dir remains"; errB=1; }
[ -f "$B/.mega-sdd/knowledge-base/kb.md" ]    || { echo "B: kb not moved"; errB=1; }
# internal rename (on post-move location)
[ -f "$B/.mega-sdd/vaults/alpha/.internal/checkpoints/c.txt" ] || { echo "B: <vault>/.mega-sdd not renamed to .internal"; errB=1; }
[ ! -d "$B/.mega-sdd/vaults/alpha/.mega-sdd" ]                 || { echo "B: stale <vault>/.mega-sdd remains"; errB=1; }
# sed reference rewrites in vault.json
vj="$B/.mega-sdd/vaults/alpha/vault.json"
grep -q '\.mega-sdd/vaults/alpha/vault.json' "$vj" || { echo "B: vault_source ref not rewritten"; errB=1; }
grep -q '\.mega-sdd/knowledge-base/kb.md' "$vj"    || { echo "B: kb ref not rewritten"; errB=1; }
grep -q '/\.mega-sdd/memory/notes.md' "$vj"        || { echo "B: memory ref not rewritten"; errB=1; }
grep -q '<vault>/.internal/checkpoints' "$vj"      || { echo "B: internal ref not rewritten"; errB=1; }
grep -q 'docs/mega-sdd/vaults/' "$vj"              && { echo "B: legacy vault path still in vault.json"; errB=1; }
grep -q '\.mega-sdd-memory' "$vj"                  && { echo "B: legacy memory path still in vault.json"; errB=1; }
# .bak cleanup
[ -z "$(find "$B/.mega-sdd" -name '*.bak' 2>/dev/null)" ] || { echo "B: leftover .bak files"; errB=1; }
# config.yaml
[ -f "$B/.mega-sdd/config.yaml" ] || { echo "B: config.yaml not created"; errB=1; }
# git history preserved — staged rename marker (R old -> new); codebase-map.md is
# moved but NOT content-edited, so git detects a clean rename.
porc=$( cd "$B" && $GIT status --porcelain 2>/dev/null )
echo "$porc" | grep -Eq '^R.*codebase-map\.md' || { echo "B: no staged-rename (R) marker — git history not preserved"; errB=1; }
[ $errB -eq 0 ] && echo "B PASS (migration: moves + rewrites + rename marker + config + .bak cleanup)"
[ $errB -ne 0 ] && { err=1; echo "---- B output ----"; echo "$outB"; }

# ---- Scenario C: idempotent re-run (guard ordering: no-op BEFORE dirty guard) ----
# B left the tree DIRTY (staged renames). A re-run must detect "no legacy paths"
# and exit 0, NOT trip the dirty-tree guard (exit 2). This is the C6 ordering fix.
outC=$(bash "$SCRIPT" --cwd="$B" 2>&1); rcC=$?
[ $rcC -eq 0 ] || { echo "C: idempotent re-run expected exit 0, got $rcC (dirty guard fired before no-op?)"; err=1; }
echo "$outC" | grep -qi 'no-op\|already canonical' || { echo "C: re-run not reported as no-op"; err=1; }
[ $rcC -eq 0 ] && echo "C PASS (idempotent re-run no-ops before the dirty guard)"

# ---- Scenario D: dirty-tree refused ----
D=$(mktemp -d); trap 'rm -rf "$A" "$B" "$D"' EXIT
mk_legacy_repo "$D"
echo "uncommitted" > "$D/dirty.txt"   # untracked change → dirty tree
outD=$(bash "$SCRIPT" --cwd="$D" 2>&1); rcD=$?
[ $rcD -eq 2 ] || { echo "D: dirty tree expected exit 2, got $rcD"; err=1; }
echo "$outD" | grep -qi 'dirty' || { echo "D: refusal message lacks 'dirty'"; err=1; }
[ -d "$D/docs/mega-sdd/vaults" ] || { echo "D: refused run still moved legacy vaults"; err=1; }
[ $rcD -eq 2 ] && echo "D PASS (dirty tree refused before any mutation)"

# ---- Scenario E: target-exists conflict under --from=auto ----
E=$(mktemp -d); trap 'rm -rf "$A" "$B" "$D" "$E"' EXIT
mk_legacy_repo "$E"
mkdir -p "$E/.mega-sdd/vaults/preexisting"
echo "x" > "$E/.mega-sdd/vaults/preexisting/x.md"
( cd "$E" && $GIT add -A && $GIT commit -qm "preexisting target" )
outE=$(bash "$SCRIPT" --cwd="$E" 2>&1); rcE=$?
[ $rcE -eq 1 ] || { echo "E: target-exists expected exit 1, got $rcE"; err=1; }
echo "$outE" | grep -qi 'non-empty\|from=legacy' || { echo "E: conflict message lacks guidance"; err=1; }
[ $rcE -eq 1 ] && echo "E PASS (non-empty target refused under --from=auto)"

# ---- Scenario F: advertised --to flags must not crash the strict parser ----
# The command advertises --to=new / --to=legacy; the parser must accept them
# (not exit 2). Run under --dry-run so it stays a no-op.
F=$(mktemp -d); trap 'rm -rf "$A" "$B" "$D" "$E" "$F"' EXIT
mk_legacy_repo "$F"
errF=0
bash "$SCRIPT" --dry-run --to=new    --cwd="$F" >/dev/null 2>&1 || { echo "F: --to=new crashed the parser (exit $?)"; errF=1; }
bash "$SCRIPT" --dry-run --to=legacy --cwd="$F" >/dev/null 2>&1 || { echo "F: --to=legacy crashed the parser (exit $?)"; errF=1; }
bash "$SCRIPT" --dry-run --bogus     --cwd="$F" >/dev/null 2>&1 && { echo "F: --bogus should be rejected (exit 2) but exited 0"; errF=1; }
[ $errF -eq 0 ] && echo "F PASS (advertised --to flags accepted; unknown flags still rejected)" || err=1

echo "──────────────────────────────"
[ $err -eq 0 ] && echo "ALL PASS" || echo "FAILED"
exit $err
