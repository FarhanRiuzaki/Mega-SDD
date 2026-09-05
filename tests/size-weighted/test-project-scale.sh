#!/usr/bin/env bash
# test-project-scale.sh — size-weighted spec §2 (approved 2026-09-05) pins:
#   - derive-project-scale.sh: deterministic structure count; xs ONLY from
#     structural evidence (1..3 screens AND <=2 entities AND <=3 flows);
#     no evidence / unreadable / over-threshold -> standard (fail-open);
#   - CALIBRATION pin against the real corpus PRD (sample-prd-clinic.md);
#   - the verb false-positive class ("Doctor views schedule") never counts;
#   - deriver mirror: vault.md frontmatter project_scale -> vault.json.
# CI-safe: bash + python3 only.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
P="$REPO_ROOT/plugins/mega-sdd"
DPS="$P/scripts/derive-project-scale.sh"
fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

jget() { python3 -c "import json,sys;print(json.load(sys.stdin).get('$1'))"; }
scale_of() { bash "$DPS" --prd="$1" | jget project_scale; }

# 1. CALIBRATION: the clinic corpus PRD is a full product — standard, with the
# exact structural counts pinned (7 surfaces-table rows, 4 data-model items,
# 6 F-X-NNN flows). A drift here means the counter or the corpus changed.
OUT=$(bash "$DPS" --prd="$REPO_ROOT/tests/scenarios/sample-prd-clinic.md")
echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['project_scale']=='standard' and d['screens']==7 and d['entities']==4 and d['flows']==6, d" \
  && pass "calibration: clinic PRD -> standard (7 screens / 4 entities / 6 flows)" \
  || fail "clinic calibration: $OUT"

# 2. The target class: 3 static screens, no entities, no flows -> xs
printf '# PRD Company Profile\n\n## Halaman Beranda\nkonten statis.\n\n## Halaman Tentang Kami\nprofil.\n\n## Halaman Kontak\nform kontak.\n' > "$WORK/xs.md"
[ "$(scale_of "$WORK/xs.md")" = "xs" ] && pass "3 static screens -> xs" || fail "3-screen xs"

# 3. Screens over threshold -> standard
printf '## Page A\n\n## Page B\n\n## Page C\n\n## Page D\n\n## Page E\n' > "$WORK/5s.md"
[ "$(scale_of "$WORK/5s.md")" = "standard" ] && pass "5 screens -> standard" || fail "5-screen ceiling"

# 4. Entities over threshold (DBML) -> standard
printf '## Halaman Dashboard\n\n```dbml\nTable users {\n id int\n}\nTable orders {\n id int\n}\nTable items {\n id int\n}\n```\n' > "$WORK/3e.md"
[ "$(scale_of "$WORK/3e.md")" = "standard" ] && pass "3 DBML entities -> standard" || fail "entity ceiling"

# 5. Flow guard (calibration amendment): 2 screens but 4 F-X-NNN flows -> standard
printf '## Page A\n\n## Page B\n\n### F-U-001 x\n### F-U-002 x\n### F-U-003 x\n### F-S-001 x\n' > "$WORK/4f.md"
[ "$(scale_of "$WORK/4f.md")" = "standard" ] && pass "4 flows -> standard (flow guard)" || fail "flow guard"

# 6. DOCTRINE: no structural screen evidence -> standard, never xs
printf '# PRD\n\nProsa panjang tanpa struktur layar sama sekali.\n' > "$WORK/none.md"
OUT=$(bash "$DPS" --prd="$WORK/none.md")
echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['project_scale']=='standard' and d['reason']=='no_screen_evidence', d" \
  && pass "no structure -> standard (unknown never gets the diet)" || fail "no-evidence doctrine: $OUT"

# 7. FAIL-OPEN: missing file -> exit 0, standard, reason recorded
OUT=$(bash "$DPS" --prd="$WORK/does-not-exist.md"); rc=$?
[ "$rc" -eq 0 ] && echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['project_scale']=='standard' and d['reason']=='prd_unreadable', d" \
  && pass "missing file -> exit 0 standard (fail-open)" || fail "fail-open: rc=$rc $OUT"

# 8. Verb false-positive pin: "views" in a flow heading is NOT a screen
printf '### F-S-001 Doctor views schedule\nisi.\n' > "$WORK/verb.md"
OUT=$(bash "$DPS" --prd="$WORK/verb.md")
echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['screens']==0 and d['project_scale']=='standard', d" \
  && pass "'Doctor views schedule' -> 0 screens (verb class pinned)" || fail "verb false-positive: $OUT"

# 9. Section-scoped counting: a Surfaces table names the screens
printf '## Surfaces\n\n| Surface | Route |\n|---|---|\n| Home | / |\n| About | /about |\n' > "$WORK/surf.md"
OUT=$(bash "$DPS" --prd="$WORK/surf.md")
echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['screens']==2 and d['project_scale']=='xs', d" \
  && pass "Surfaces table rows counted -> xs at 2" || fail "surfaces table: $OUT"

# 10. Deriver mirror: layout-2 frontmatter project_scale -> vault.json
V="$WORK/vault"; mkdir -p "$V"
cp "$P/tests/graph/fixtures/derive-vault-v2/"*.md "$V/"
python3 - "$V/vault.md" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("output_mode: compact", "output_mode: compact\nproject_scale: xs")
open(p, "w").write(s)
EOF
bash "$P/scripts/derive-vault-json.sh" --vault "$V" >/dev/null 2>&1
PS=$(jget project_scale < "$V/vault.json")
[ "$PS" = "xs" ] && pass "deriver mirrors frontmatter project_scale into vault.json" || fail "mirror: project_scale=$PS"

# 11. Absent scalar stays absent-or-null (legacy tolerance; never invented)
V2="$WORK/vault2"; mkdir -p "$V2"
cp "$P/tests/graph/fixtures/derive-vault-v2/"*.md "$V2/"
bash "$P/scripts/derive-vault-json.sh" --vault "$V2" >/dev/null 2>&1
PS2=$(jget project_scale < "$V2/vault.json")
{ [ "$PS2" = "None" ] || [ "$PS2" = "null" ] || [ -z "$PS2" ]; } \
  && pass "absent frontmatter -> no invented project_scale" || fail "absent case: '$PS2'"

echo
if [ "$fails" -eq 0 ]; then echo "OK: all project-scale pins green"; exit 0
else echo "FAILURES: $fails"; exit 1; fi
