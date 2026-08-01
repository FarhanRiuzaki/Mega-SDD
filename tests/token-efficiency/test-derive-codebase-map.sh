#!/usr/bin/env bash
# test-derive-codebase-map.sh — tranche 5b (spec 2026-07-30 §5b).
# Pins scripts/derive-codebase-map.sh — the deterministic assembler that replaced
# the model-typed codebase-map.md write — and the 4 previously prose-trusted
# anti-hallucination rails it makes structural:
#
#   RAIL-1  carry-forward rows are byte-COPIES with their ORIGINAL
#           Last_Scanned_Sha256 — proven by mutating a carried file on disk and
#           asserting the carried row's sha does NOT refresh.
#   RAIL-2  an absent/corrupt prior in --mode=merge is exit 3 `fallback_full`,
#           nothing written.
#   RAIL-3  prior §2/§4 rows whose File vanished are dropped and counted.
#   RAIL-4  schema shape: 7 sections always present ("None detected"), script-
#           stamped generated_at/last_scanned_commit (omitted on a zero-commit
#           repo — the literal-HEAD poisoning rule), script-owned keys in the
#           delta ignored with a warning.
#
# Plus the chained write-path gates: secret-scan redaction on the assembled
# temp (planted AWS key → [REDACTED-SECRET] in the map + findings on stdout)
# and the validator refresh (exit 0 == validator PASS).
#
# Run: bash tests/token-efficiency/test-derive-codebase-map.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PLUGIN="${ROOT}/plugins/mega-sdd"
DERIVER="${PLUGIN}/scripts/derive-codebase-map.sh"
[ -f "$DERIVER" ] || { echo "missing $DERIVER"; exit 1; }

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t dcm)"
trap 'rm -rf "$WORK"' EXIT

jget() { python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d$1)"; }

mk_proj() { # $1=dir ; creates src files + git commit + files.z
  mkdir -p "$1/src/models" "$1/.mega-sdd/codebase/.scan"
  printf 'export class User {}\n' > "$1/src/models/user.ts"
  printf 'export function main() {}\n' > "$1/src/app.ts"
  # local identity is MANDATORY: CI runners have no global identity and newer
  # git no longer auto-constructs one — a silent commit failure here leaves a
  # zero-commit repo, and the deriver then (correctly) omits the stamp the
  # assertions below require. Masked on dev machines by the global config.
  (cd "$1" && git init -q . && git config user.email t@t && git config user.name t \
    && git add -A && git commit -qm init) >/dev/null 2>&1
  printf 'src/models/user.ts\0src/app.ts\0' > "$1/.mega-sdd/codebase/.scan/files.z"
}
mk_delta_full() { # $1=dir
  mkdir -p "$1"
  printf '{"scan_depth": 5, "languages_detected": ["typescript"], "package_managers": ["npm"], "test_frameworks": ["jest"], "engine": "regex", "precision_tier": "regex", "generated_at": "1999-01-01T00:00:00Z"}\n' > "$1/frontmatter.json"
  printf '| src/models/user.ts | class | User | { id: string } |\n| src/app.ts | function | main | () => void |\n' > "$1/s2.rows"
  printf '| POST | /api/leave | leave.submitLeave |\n' > "$1/s3.rows"
  printf '| User | src/models/user.ts | id, email |\n' > "$1/s4.rows"
  printf -- '- Case style: camelCase\n' > "$1/s5.md"
  printf -- '- Auth pattern: middleware\n' > "$1/s6.md"
  printf 'framework:\n  name: express\n  version: "4.x"\n  confidence: high\n  pack_path: _universal.md\n  detection_source: package.json express dependency\n' > "$1/s7.md"
}
run_deriver() { bash "$DERIVER" --cwd="$1" --mode="$2" --delta="$3" --plugin-root="$PLUGIN"; }

note "== 1. FULL mode: assembly, §1 render, sha join, stamp, validator chain =="
P="$WORK/p1"; mk_proj "$P"; D="$WORK/d1"; mk_delta_full "$D"
OUT=$(run_deriver "$P" full "$D"); RC=$?
MAP="$P/.mega-sdd/codebase/codebase-map.md"
[ "$RC" = "0" ] && ok "exit 0 (map written + validator PASS)" || fail "full mode rc=$RC"
[ "$(printf '%s' "$OUT" | jget "['validator']")" = "PASS" ] && ok "validate-codebase-map.sh chained and PASSED" || fail "validator not PASS"
grep -q '└── src/' "$MAP" && ok "§1 tree rendered from files.z (model never types the tree)" || fail "§1 render missing"
grep -qE '\| src/app\.ts \| function \| main \| \(\) => void \| [0-9a-f]{64} \|' "$MAP" && ok "sha256 joined onto delta §2 rows (model never types 64-hex)" || fail "sha join missing"
grep -qE '^last_scanned_commit: [0-9a-f]{40}$' "$MAP" && ok "staleness stamp minted by the script (real 40-hex)" || fail "stamp missing/malformed"
ORDER_OK=1; PREV=0
for n in 1 2 3 4 5 6 7; do
  LN=$(grep -n "^## $n\." "$MAP" | head -1 | cut -d: -f1)
  [ -n "$LN" ] || { fail "section $n missing"; ORDER_OK=0; continue; }
  [ "$LN" -gt "$PREV" ] || ORDER_OK=0
  PREV=$LN
done
[ "$ORDER_OK" = "1" ] && ok "all 7 sections present AND in order (line positions ascending)" || fail "sections missing or out of order"
if grep -q '^generated_at: 1999-01-01' "$MAP"; then fail "RAIL-4: delta overrode script-owned generated_at"; else ok "RAIL-4: script-owned generated_at ignored from the delta"; fi
printf '%s' "$OUT" | jget "['warnings']" | grep -q 'ignored_script_owned_frontmatter:generated_at' && ok "RAIL-4: ignored key named in warnings" || fail "warning for ignored script-owned key missing"

note "== 2. RAIL-4: zero-commit repo → stamp OMITTED (literal-HEAD poisoning rule) =="
P="$WORK/p2"; mkdir -p "$P/src" "$P/.mega-sdd/codebase/.scan"
printf 'export const x = 1\n' > "$P/src/a.ts"; printf 'src/a.ts\0' > "$P/.mega-sdd/codebase/.scan/files.z"
(cd "$P" && git init -q .) >/dev/null 2>&1   # repo exists, ZERO commits
D="$WORK/d2"; mk_delta_full "$D"
run_deriver "$P" full "$D" >/dev/null; RC=$?
[ "$RC" = "0" ] || fail "zero-commit full run rc=$RC"
if grep -q 'last_scanned_commit' "$P/.mega-sdd/codebase/codebase-map.md"; then fail "RAIL-4: zero-commit repo got a stamp (poisoned)"; else ok "RAIL-4: stamp omitted on a zero-commit repo"; fi

note "== 3. MERGE: byte-copy carry (RAIL-1), replace-set, vanished drop (RAIL-3), §3 carry =="
P="$WORK/p3"; mk_proj "$P"; D="$WORK/d3"; mk_delta_full "$D"
run_deriver "$P" full "$D" >/dev/null || fail "seed full run failed"
MAP="$P/.mega-sdd/codebase/codebase-map.md"
ORIG_APP_ROW=$(grep '| src/app.ts |' "$MAP")
# mutate app.ts ON DISK (its content hash changes) but do NOT re-extract it —
# rail 1 says the carried row keeps the ORIGINAL sha, proving no re-hash/retype
printf 'export function main() { /* changed */ }\n' >> "$P/src/app.ts"
rm "$P/src/models/user.ts"                      # user.ts vanishes → its rows must drop
DM="$WORK/d3m"; mkdir -p "$DM"; printf '{}' > "$DM/frontmatter.json"
OUT=$(run_deriver "$P" merge "$DM"); RC=$?
[ "$RC" = "0" ] && ok "merge exit 0" || fail "merge rc=$RC"
NOW_APP_ROW=$(grep '| src/app.ts |' "$MAP")
[ "$NOW_APP_ROW" = "$ORIG_APP_ROW" ] && ok "RAIL-1: carried row byte-identical — ORIGINAL sha kept though the file changed on disk" || fail "RAIL-1 broken: carried row was re-rendered/re-hashed"
grep -q '| src/models/user.ts |' "$MAP" && fail "RAIL-3: vanished file's rows survived" || ok "RAIL-3: vanished file's §2/§4 rows dropped"
[ "$(printf '%s' "$OUT" | jget "['dropped_rows']['s2']")" = "1" ] && ok "RAIL-3: drop counted on stdout (s2=1)" || fail "drop count wrong"
[ "$(printf '%s' "$OUT" | jget "['sections']['s3']")" = "carried" ] && ok "§3 carried when delta omits it" || fail "§3 not carried"
grep -q '| POST | /api/leave |' "$MAP" && ok "carried §3 rows intact" || fail "carried §3 rows lost"
# replace-set: re-extract app.ts now → new signature + FRESH sha
DM2="$WORK/d3m2"; mkdir -p "$DM2"; printf '{}' > "$DM2/frontmatter.json"
printf '| src/app.ts | function | main | () => void (changed) |\n' > "$DM2/s2.rows"
printf 'src/app.ts\n' > "$DM2/s2.files"
OUT=$(run_deriver "$P" merge "$DM2"); RC=$?
[ "$RC" = "0" ] || fail "replace-set merge rc=$RC"
NEW_ROW=$(grep '| src/app.ts |' "$MAP")
[ "$NEW_ROW" != "$ORIG_APP_ROW" ] && printf '%s' "$NEW_ROW" | grep -qE '[0-9a-f]{64}' && ok "replace-set: re-extracted row got a FRESH sha" || fail "replace-set row not refreshed"

note "== 4. RAIL-2: absent/corrupt prior in merge → exit 3, nothing written =="
P="$WORK/p4"; mk_proj "$P"; DM="$WORK/d4"; mkdir -p "$DM"; printf '{}' > "$DM/frontmatter.json"
run_deriver "$P" merge "$DM" >/dev/null 2>&1; RC=$?
[ "$RC" = "3" ] && ok "no prior map → exit 3 fallback_full" || fail "expected 3 on absent prior, got $RC"
[ ! -f "$P/.mega-sdd/codebase/codebase-map.md" ] && ok "nothing written on fallback" || fail "fallback wrote a map"
D="$WORK/d4f"; mk_delta_full "$D"; run_deriver "$P" full "$D" >/dev/null
printf 'garbage, not a map\n' > "$P/.mega-sdd/codebase/codebase-map.md"
cp "$P/.mega-sdd/codebase/codebase-map.md" "$P/.before"
run_deriver "$P" merge "$DM" >/dev/null 2>&1; RC=$?
[ "$RC" = "3" ] && cmp -s "$P/.mega-sdd/codebase/codebase-map.md" "$P/.before" && ok "corrupt prior → exit 3, prior file untouched" || fail "corrupt-prior handling wrong (rc=$RC)"

note "== 5. Secret-scan gate chained (Step 10a structural) =="
P="$WORK/p5"; mk_proj "$P"; D="$WORK/d5"; mk_delta_full "$D"
printf '| src/app.ts | const | AWS_KEY | AKIAIOSFODNN7EXAMPLE |\n' >> "$D/s2.rows"
OUT=$(run_deriver "$P" full "$D"); RC=$?
MAP="$P/.mega-sdd/codebase/codebase-map.md"
grep -q 'REDACTED-SECRET' "$MAP" && ok "planted AWS key REDACTED in the assembled map" || fail "secret survived into the map"
if grep -q 'AKIAIOSFODNN7EXAMPLE' "$MAP"; then fail "raw secret value present in the map"; else ok "raw secret value absent from the map"; fi
NFIND=$(printf '%s' "$OUT" | jget "['secret_findings'].__len__()" 2>/dev/null)
case "$NFIND" in (''|*[!0-9]*) fail "secret_findings count unreadable (stdout: ${OUT:0:120})";; (0) fail "secret_findings empty despite redaction";; (*) ok "findings surfaced on stdout ($NFIND) for SECRET-FINDINGS.md routing";; esac

note "== 6. contract: incomplete delta, unknown arg, atomicity =="
P="$WORK/p6"; mk_proj "$P"; D="$WORK/d6"; mkdir -p "$D"; printf '{}' > "$D/frontmatter.json"
run_deriver "$P" full "$D" >/dev/null 2>&1; RC=$?
[ "$RC" = "2" ] && ok "full mode without judgment sections → exit 2 (no half map)" || fail "incomplete delta rc=$RC"
[ ! -f "$P/.mega-sdd/codebase/codebase-map.md" ] && ok "nothing written on incomplete delta" || fail "half map written"
LEFT=$(find "$P" -name 'codebase-map.md.tmp.*' | wc -l | tr -d ' ')
[ "$LEFT" = "0" ] && ok "no orphaned temp file" || fail "$LEFT orphaned temp file(s)"
bash "$DERIVER" --bogus >/dev/null 2>&1; RC=$?
[ "$RC" = "2" ] && ok "unknown arg → exit 2" || fail "unknown arg rc=$RC"

note "== 7. prose pins: the write path routes through the deriver =="
SP="$PLUGIN/skills/scan-codebase/references/scan-procedure.md"
SK="$PLUGIN/skills/scan-codebase/SKILL.md"
SC="$PLUGIN/skills/scan-codebase/references/codebase-map-schema.md"
grep -qF 'via the deriver — never type the map' "$SP" && ok "Step 10 routes through the deriver" || fail "Step 10 prose stale"
grep -qF 'CHAINED BY THE DERIVER' "$SP" && ok "Step 10a secret-scan reframed as deriver-chained" || fail "10a prose stale"
grep -qF 'STRUCTURAL since the deriver' "$SP" && ok "anti-halu rail marked structural" || fail "anti-halu rail prose stale"
grep -qF 'exit 3 `fallback_full`' "$SP" && ok "fallback_full exit documented in the procedure" || fail "fallback exit missing"
grep -qF 'derive-codebase-map.sh' "$SK" && grep -qF -- '--mode=merge' "$SK" && ok "SKILL.md Step 10 carries the runnable deriver form (both modes)" || fail "SKILL.md stale"
grep -qF 'ASSEMBLED by `scripts/derive-codebase-map.sh`' "$SC" && ok "schema doc notes the deriver (consumers unchanged)" || fail "schema note missing"
if grep -qF 'Resolve $PLUGIN_ROOT to the LATEST cached version' "$SP" && grep -qF 'secret-scan.sh" --redact <assembled-artifact-tmp-file>' "$SP"; then fail "old manual scrub block survives in Step 10a"; else ok "old manual temp/scrub/rename block gone"; fi

note "== 8. review-round pins (F1-F18): variant headers, citations, pairing, padding, joins =="
# F1 — variant column order: untouched merge carries verbatim (NO drops); touched merge = exit 3
P="$WORK/p8"; mk_proj "$P"; D="$WORK/d8"; mk_delta_full "$D"
run_deriver "$P" full "$D" >/dev/null
MAP="$P/.mega-sdd/codebase/codebase-map.md"
python3 - "$MAP" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
t = t.replace("| File | Type | Symbol | Signature | Last_Scanned_Sha256 |",
              "| Symbol | Signature | File |")
t = re.sub(r"\|---\|---\|---\|---\|---\|", "|---|---|---|", t, count=1)
t = re.sub(r"\| (src/\S+) \| (\w+) \| (\w+) \| ([^|]+) \| [0-9a-f]*\s*\|",
           r"| \3 | \4 | \1 |", t)
open(sys.argv[1], "w").write(t)
PY
DM="$WORK/d8m"; mkdir -p "$DM"; printf '{}' > "$DM/frontmatter.json"
OUT=$(run_deriver "$P" merge "$DM"); RC=$?
[ "$RC" = "0" ] && grep -q '| Symbol | Signature | File |' "$MAP" \
  && ok "F1: variant-order prior UNTOUCHED merge → carried verbatim (header preserved)" || fail "F1: variant untouched carry broken (rc=$RC)"
printf '%s' "$OUT" | jget "['warnings']" | grep -q 's2_drops_skipped_noncanonical' && ok "F1: drops SKIPPED on variant order, named in warnings (never a positional guess)" || fail "F1: variant-order drop-skip warning missing"
printf '| src/app.ts | function | main | x |\n' > "$DM/s2.rows"; printf 'src/app.ts\n' > "$DM/s2.files"
run_deriver "$P" merge "$DM" >/dev/null 2>&1; RC=$?
[ "$RC" = "3" ] && ok "F1: variant-order prior TOUCHED merge → exit 3 (silent-§2-wipe class dead)" || fail "F1: touched variant merge rc=$RC (expected 3)"

# F2 — File cells carrying \`path\`:42 citations: no bogus drops, sha still joins
P="$WORK/p9"; mk_proj "$P"; D="$WORK/d9"; mk_delta_full "$D"
printf '| `src/app.ts:1` | function | cited | () => void |\n' >> "$D/s2.rows"
OUT=$(run_deriver "$P" full "$D"); MAP="$P/.mega-sdd/codebase/codebase-map.md"
grep -qE '\| `src/app\.ts:1` \| function \| cited \| \(\) => void \| [0-9a-f]{64} \|' "$MAP" \
  && ok "F2: backticked path:line citation → sha joined from the real file" || fail "F2: citation row sha join failed"
DM="$WORK/d9m"; mkdir -p "$DM"; printf '{}' > "$DM/frontmatter.json"
OUT=$(run_deriver "$P" merge "$DM")
[ "$(printf '%s' "$OUT" | jget "['dropped_rows']['s2']")" = "0" ] && ok "F2: cited rows NOT dropped as vanished on merge" || fail "F2: citation row wrongly dropped"

# F3 — s2.rows without s2.files: replace-set derived from the rows (no duplicates)
P="$WORK/p10"; mk_proj "$P"; D="$WORK/d10"; mk_delta_full "$D"
run_deriver "$P" full "$D" >/dev/null; MAP="$P/.mega-sdd/codebase/codebase-map.md"
DM="$WORK/d10m"; mkdir -p "$DM"; printf '{}' > "$DM/frontmatter.json"
printf '| src/app.ts | function | main | () => NEW |\n' > "$DM/s2.rows"   # NO s2.files
run_deriver "$P" merge "$DM" >/dev/null
N_APP=$(grep -c '| src/app.ts | function | main |' "$MAP")
[ "$N_APP" = "1" ] && grep -q '() => NEW' "$MAP" && ok "F3: forgotten s2.files → replace-set derived from delta rows, NO duplicate rows" || fail "F3: duplicate/stale rows (count=$N_APP)"

# F4 — a §4 Entity literally named 'File' survives a touched §4 merge
P="$WORK/p11"; mk_proj "$P"; D="$WORK/d11"; mk_delta_full "$D"
printf '| File | src/models/user.ts | id, path |\n' >> "$D/s4.rows"
run_deriver "$P" full "$D" >/dev/null; MAP="$P/.mega-sdd/codebase/codebase-map.md"
DM="$WORK/d11m"; mkdir -p "$DM"; printf '{}' > "$DM/frontmatter.json"
printf '| NewEnt | src/app.ts | a |\n' > "$DM/s4.rows"; printf 'src/app.ts\n' > "$DM/s4.files"
run_deriver "$P" merge "$DM" >/dev/null
grep -q '^| File | src/models/user.ts |' "$MAP" && ok "F4: Entity named 'File' survives a §4-touching merge (header keyed per section + position)" || fail "F4: 'File' entity row lost"

# F12 — legacy 4-column prior + touched merge → padded carried rows + warning, validator PASS
P="$WORK/p12"; mk_proj "$P"
mkdir -p "$P/.mega-sdd/codebase"
cat > "$P/.mega-sdd/codebase/codebase-map.md" <<'EOF'
---
generated_by: mega-sdd:scan-codebase
generated_at: 2026-05-27T00:00:00Z
repo_root: ./
languages_detected: ["typescript"]
engine: regex
precision_tier: regex
---

# Codebase Map

## 1. Top-level structure

```
src/
```

## 2. Public interfaces

| File | Type | Symbol | Signature |
|---|---|---|---|
| src/models/user.ts | class | User | { id } |
| src/app.ts | function | main | () => void |

## 3. Routes / Endpoints

None detected

## 4. Data models / Schemas

None detected

## 5. Naming conventions

- Case style: camelCase

## 6. Pattern signatures

- Auth pattern: none

## 7. Framework

framework:
  name: _universal
  confidence: fallback
EOF
DM="$WORK/d12m"; mkdir -p "$DM"; printf '{}' > "$DM/frontmatter.json"
printf '| src/app.ts | function | main | () => v2 |\n' > "$DM/s2.rows"; printf 'src/app.ts\n' > "$DM/s2.files"
OUT=$(run_deriver "$P" merge "$DM"); RC=$?
[ "$RC" = "0" ] && ok "F12: legacy 4-col prior + touched merge → exit 0 (validator PASS)" || fail "F12: rc=$RC"
grep -qE '^\| src/models/user\.ts \| class \| User \| \{ id \} \|  \|$' "$P/.mega-sdd/codebase/codebase-map.md" \
  && ok "F12: carried 4-col row padded with an EMPTY sha cell (re-extracts next shallow scan — never a minted sha)" || fail "F12: pad wrong: $(grep 'user.ts' "$P/.mega-sdd/codebase/codebase-map.md")"
printf '%s' "$OUT" | jget "['warnings']" | grep -q 's2_padded_legacy_rows:1' && ok "F12: pad counted in warnings" || fail "F12: pad warning missing"

# F16 — a non-table annotation in §2 survives a touched merge
P="$WORK/p13"; mk_proj "$P"; D="$WORK/d13"; mk_delta_full "$D"
run_deriver "$P" full "$D" >/dev/null; MAP="$P/.mega-sdd/codebase/codebase-map.md"
python3 - "$MAP" <<'PY'
import sys
t = open(sys.argv[1]).read()
t = t.replace("## 3. Routes", "> annotation: kept-on-merge\n\n## 3. Routes")
open(sys.argv[1], "w").write(t)
PY
DM="$WORK/d13m"; mkdir -p "$DM"; printf '{}' > "$DM/frontmatter.json"
printf '| src/app.ts | function | main | () => v3 |\n' > "$DM/s2.rows"; printf 'src/app.ts\n' > "$DM/s2.files"
run_deriver "$P" merge "$DM" >/dev/null
grep -q 'annotation: kept-on-merge' "$MAP" && ok "F16: §2 prose annotation survives a touched merge" || fail "F16: annotation lost"

# F18 — hashes.txt present: the join takes the PLANTED hash (proves the join path runs)
P="$WORK/p14"; mk_proj "$P"; D="$WORK/d14"; mk_delta_full "$D"
FAKE=$(printf 'f%.0s' $(seq 1 64))
printf '%s  ./src/app.ts\n' "$FAKE" > "$P/.mega-sdd/codebase/.scan/hashes.txt"
run_deriver "$P" full "$D" >/dev/null
grep -q "| $FAKE |" "$P/.mega-sdd/codebase/codebase-map.md" && ok "F18: hashes.txt join path exercised (planted hash used, ./-prefix normalized)" || fail "F18: join path not taken"

# F15 — sha256-object-format repo → 64-hex stamp accepted (skip when git too old)
if git init --object-format=sha256 -q "$WORK/p15" >/dev/null 2>&1; then
  P="$WORK/p15"; mkdir -p "$P/src" "$P/.mega-sdd/codebase/.scan"
  printf 'x\n' > "$P/src/a.ts"; printf 'src/a.ts\0' > "$P/.mega-sdd/codebase/.scan/files.z"
  (cd "$P" && git config user.email t@t && git config user.name t \
    && git add -A && git commit -qm i) >/dev/null 2>&1
  D="$WORK/d15"; mk_delta_full "$D"
  run_deriver "$P" full "$D" >/dev/null
  grep -qE '^last_scanned_commit: [0-9a-f]{64}$' "$P/.mega-sdd/codebase/codebase-map.md" \
    && ok "F15: 64-hex OID stamp accepted (sha256 object format)" || fail "F15: 64-hex stamp rejected"
else
  ok "F15: git lacks --object-format=sha256 here — case skipped (documented)"
fi

note "== 9. execution-review pins: fail-closed scrub, exit-4 surface, placeholder leak, BOM =="
# broken secret-scan (rc!=0 = malfunction, never a verdict) → fail CLOSED, nothing renamed
P="$WORK/p16"; mk_proj "$P"; D="$WORK/d16"; mk_delta_full "$D"
FAKEPR="$WORK/fake-plugin"; mkdir -p "$FAKEPR/scripts"
printf '#!/usr/bin/env bash\nexit 49\n' > "$FAKEPR/scripts/secret-scan.sh"; chmod +x "$FAKEPR/scripts/secret-scan.sh"
bash "$DERIVER" --cwd="$P" --mode=full --delta="$D" --plugin-root="$FAKEPR" >/dev/null 2>&1; RC=$?
[ "$RC" = "2" ] && ok "secret-scan MALFUNCTION (rc=49) → deriver fails CLOSED at exit 2 (never ships unscrubbed)" || fail "broken scrubber rc=$RC (expected 2)"
[ ! -f "$P/.mega-sdd/codebase/codebase-map.md" ] && ok "nothing renamed when the scrubber is broken" || fail "map written past a broken scrubber"
LEFT=$(find "$P" -name 'codebase-map.md.tmp.*' | wc -l | tr -d ' ')
[ "$LEFT" = "0" ] && ok "no temp orphan on the fail-closed path" || fail "$LEFT temp orphan(s)"

# exit-4 surface: validator-rejected assembly → prior intact + .rejected + NO project state poisoning
P="$WORK/p17"; mk_proj "$P"; D="$WORK/d17"; mk_delta_full "$D"
run_deriver "$P" full "$D" >/dev/null
MAP="$P/.mega-sdd/codebase/codebase-map.md"
python3 - "$MAP" <<'PY'
import sys
t = open(sys.argv[1]).read()
t = t.replace("languages_detected: [\"typescript\"]\n", "")  # strip a validator-required key
open(sys.argv[1], "w").write(t)
PY
cp "$MAP" "$P/.before"
DM="$WORK/d17m"; mkdir -p "$DM"; printf '{}' > "$DM/frontmatter.json"
printf '| src/app.ts | function | main | () => v4 |\n' > "$DM/s2.rows"; printf 'src/app.ts\n' > "$DM/s2.files"
OUT=$(run_deriver "$P" merge "$DM" 2>/dev/null); RC=$?
[ "$RC" = "4" ] && ok "validator-rejected assembly → exit 4" || fail "expected 4, got $RC"
cmp -s "$MAP" "$P/.before" && ok "exit 4: prior map INTACT (nothing renamed)" || fail "exit 4 clobbered the prior map"
[ -f "$MAP.rejected" ] && ok "rejected assembly kept at <out>.rejected for forensics" || fail ".rejected missing"
printf '%s' "$OUT" | jget "['rejected_path']" 2>/dev/null | grep -q '.rejected' && ok "rejected_path reported on stdout" || fail "rejected_path missing from JSON"
if [ -f "$P/.mega-sdd/.codebase-map-state.json" ] && grep -q 'tmp\.' "$P/.mega-sdd/.codebase-map-state.json" 2>/dev/null; then fail "exit-4 gate poisoned the canonical state with a tmp verdict"; else ok "canonical state NOT poisoned by the gate (scratch-cwd scribble)"; fi

# placeholder leak: prior §4 'None detected' + a §4-populating merge → no leaked placeholder
P="$WORK/p18"; mk_proj "$P"; D="$WORK/d18"; mk_delta_full "$D"
rm "$D/s4.rows"; printf '' > "$D/s4.rows"   # full map with EMPTY §4 → "None detected"
run_deriver "$P" full "$D" >/dev/null
MAP="$P/.mega-sdd/codebase/codebase-map.md"
DM="$WORK/d18m"; mkdir -p "$DM"; printf '{}' > "$DM/frontmatter.json"
printf '| Fresh | src/app.ts | a, b |\n' > "$DM/s4.rows"; printf 'src/app.ts\n' > "$DM/s4.files"
run_deriver "$P" merge "$DM" >/dev/null
S4=$(sed -n '/## 4\./,/## 5\./p' "$MAP")
printf '%s' "$S4" | grep -q 'None detected' && fail "placeholder 'None detected' leaked above the populated §4 table" || ok "placeholder removed when the section gains rows (regression pin)"
printf '%s' "$S4" | grep -q '| Fresh |' && ok "populated §4 rows present" || fail "§4 rows missing"

# BOM'd frontmatter.json (Windows-authored delta) → parsed fine
P="$WORK/p19"; mk_proj "$P"; D="$WORK/d19"; mk_delta_full "$D"
printf '\xef\xbb\xbf' | cat - "$D/frontmatter.json" > "$D/fm.tmp" && mv "$D/fm.tmp" "$D/frontmatter.json"
run_deriver "$P" full "$D" >/dev/null 2>&1; RC=$?
[ "$RC" = "0" ] && ok "UTF-8 BOM in frontmatter.json tolerated (utf-8-sig)" || fail "BOM'd delta rc=$RC"

if [ "$FAILED" -eq 0 ]; then note "ALL DERIVE-CODEBASE-MAP PINS OK"; else note "derive-codebase-map pins FAILED"; fi
exit $FAILED
