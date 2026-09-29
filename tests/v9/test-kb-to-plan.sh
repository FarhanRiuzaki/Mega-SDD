#!/usr/bin/env bash
# KB → plan — the legacy-rebuild hand-off stays buildable (spec docs/superpowers/specs/
# 2026-09-27-v9-simplification-design.md §0.2 + §4 + §7 decision 6; a P1 exit criterion).
# extract-intelligence writes a PRD-kontrak KB; `plan --kb=<kb-dir>` turns it into the
# layout-3 vault + units. Pinned here:
#   P  derive-plan-pins.sh --kb: prd_path = <kb>/README.md, prd_sha256 = sha256 of
#      <kb>/census.json (README when a numbered-tree KB has none), project_scale standard
#   C  validate-plan-coverage.sh --kb: every module heading of <kb>/modules/*.prd.md (a numbered-tree KB: 10-domains/*.md)
#      (minus §1 Purpose / §6 Open Questions) needs a unit prd_source (a path from the project root —
#      a bare module basename is no ref, as in validate-unit-spec.sh), an open OQ carrying
#      [covers: <kb>/modules/<m>.prd.md#<slug>] (a quote, a mention, an [origin:] or a resolved OQ
#      decides nothing), or a module-qualified line in context.md "## Coverage exclusions";
#      a FAIL names the gap and its module
#   K  the --kb census excludes ONLY the template's own meta sections (numbered H2, EN/ID
#      name, whole heading) — never a prefix (V7 fail-open: 'Purpose code validation',
#      'Source reference number format', 'Tidak termasuk biaya admin …' were silently dropped)
#      and never by name: an 'Out of scope' section is an anchor until it is declared; fenced
#      code is not censused; a malformed fence, or one spanning a numbered section H2, never hides
#      a heading; K15-K19: zero anchors = FAIL, HTML comments / indented + setext H2s parsed, an H2
#      declaration covers no H3, an OQ cites a whole heading; K20-K21 (round 2): a forgotten '<!--'
#      is not closed by a Mermaid '-->' arrow, a list-item fence ends with its item; K22-K24 (round 3):
#      a bare 'transfer.prd.md' ref never covers 'scheduled-transfer.prd.md', an out-of-scope H2
#      opens no region, a forgotten fence closer is caught when a later fence reads as another opener;
#      K25-K27 (declared coverage): a --kb declaration must name its module file, covers only that
#      module's heading, and needs a real reason
#   R  a realistic multi-module KB (frontmatter, tables, AC, mermaid, a quoted legacy
#      banner, §7, Indonesian meta headings, an Out-of-scope section, extractor-added
#      [LOCKED] H3s) — the gaps are exactly the undecided headings
#   W  the wiring: extract-intelligence hands off to plan --kb, plan accepts --kb
# Fixtures are synthetic; no network, no model.
# Run: bash tests/v9/test-kb-to-plan.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$here/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
PINS="$P/scripts/derive-plan-pins.sh"; COV="$P/scripts/validate-plan-coverage.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/kb-plan.XXXXXX")"; trap 'rm -rf "$T"' EXIT
rc=0
ok() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; rc=1; }
jget() { python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(d[sys.argv[1]])' "$1"; }
sha() { python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }

# ── fixture: a project with an extract-intelligence KB (PRD-kontrak grammar) ──
W="$T/proj"; KB="$W/.mega-sdd/knowledge-base"; V="$W/.mega-sdd/vaults/legacy-billing"
mkdir -p "$KB/modules" "$V/units"
git -C "$W" init -q && git -C "$W" config user.name "KB Tester"
cat > "$KB/README.md" <<'EOF'
# Legacy Billing — Knowledge Base

## Reengineering Opportunities
- Replace the nightly batch with an event.

## Mutability Tier Distribution
| Module | LOCKED | INTENT | ARTIFACT |
|---|---|---|---|
| a | 1 | 1 | 0 |
EOF
echo '{"census_version": 1, "legacy_root": "/src/legacy-billing", "file_count": 1, "files": []}' > "$KB/census.json"
cat > "$KB/modules/a.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: a
---
# PRD — Invoicing

## 1. Purpose
Issues invoices.

## 2. Business Rules
| ID | Rule | Why | Source | Confidence | Mutability |
|---|---|---|---|---|---|
| BR-A-1 | Invoice total = sum of lines | contract | inv.rpg:12 | | [LOCKED] |

## 3. Flow
```mermaid
flowchart LR
  A["Order"] --> B["Invoice"]
```

## 6. Open Questions
_Tidak ada._
EOF

echo "── P: derive-plan-pins.sh --kb ──"
out="$(bash "$PINS" --cwd="$W" --kb=.mega-sdd/knowledge-base </dev/null)"; ec=$?
[ $ec -eq 0 ] && ok "P0 --kb → exit 0" || bad "P0 exit $ec: $out"
[ "$(echo "$out" | jget prd_path)" = ".mega-sdd/knowledge-base/README.md" ] && ok "P1 prd_path = <kb>/README.md" || bad "P1 $out"
[ "$(echo "$out" | jget prd_sha256)" = "$(sha "$KB/census.json")" ] && ok "P2 prd_sha256 = sha256 of <kb>/census.json (decision 6)" || bad "P2 $out"
[ "$(echo "$out" | jget project_scale)" = standard ] && ok "P3 project_scale = standard (a legacy rebuild is never xs)" || bad "P3 $out"
[ "$(echo "$out" | jget slug)" = legacy-billing ] && [ "$(echo "$out" | jget vault)" = ".mega-sdd/vaults/legacy-billing" ] \
  && ok "P4 slug from the census legacy_root; vault default .mega-sdd/vaults/<slug>" || bad "P4 $out"
[ "$(echo "$out" | jget author)" = "KB Tester" ] && [ "$(echo "$out" | jget vault_exists)" = False ] && ok "P5 author from git, vault_exists false" || bad "P5 $out"
N="$T/tree"; mkdir -p "$N/kb"; printf '# Old Tree KB\n\n## Reengineering Opportunities\n- x\n' > "$N/kb/README.md"
out="$(bash "$PINS" --cwd="$N" --kb=kb </dev/null)"
[ "$(echo "$out" | jget prd_sha256)" = "$(sha "$N/kb/README.md")" ] && [ "$(echo "$out" | jget slug)" = old-tree-kb ] \
  && ok "P6 no census.json (numbered-tree KB) → README is hashed; slug from the README title" || bad "P6 $out"
bash "$PINS" --cwd="$W" --kb=nope </dev/null >/dev/null 2>&1; [ $? -eq 3 ] && ok "P7 KB without README.md → exit 3" || bad "P7 exit"
bash "$PINS" --cwd="$W" --kb=.mega-sdd/knowledge-base --prd=x.md </dev/null >/dev/null 2>&1; [ $? -eq 2 ] && ok "P8 --kb with --prd → exit 2" || bad "P8 exit"

echo "── C: validate-plan-coverage.sh --kb ──"
mkunit() { cat > "$V/units/$1.md" <<EOF
---
id: $1
title: $1
task_type: create
context_source: context.md#F-U-001
prd_source: $2
target_files:
  - path: src/$1.ts
    operation: create
acceptance_test:
  - type: test
    command: x
    expects: ""
---
# $1
EOF
}
cov() { ( cd "$W" && bash "$COV" --cwd="$W" --kb=.mega-sdd/knowledge-base --vault="$V" --quiet </dev/null ); }
ST="$W/.mega-sdd/.plan-coverage-state.json"
echo '{"open_questions":[]}' > "$V/vault.json"
mkunit U-001 '.mega-sdd/knowledge-base/modules/a.prd.md#2-business-rules'
cov; ec=$?
python3 - "$ST" "$ec" <<'EOF' && ok "C1 one module heading uncovered → FAIL exit 1; the gap names the heading and its module; §1/§6 not counted" || bad "C1 wrong verdict"
import json, sys
d = json.load(open(sys.argv[1])); ec = int(sys.argv[2])
assert ec == 1 and d["status"] == "FAIL" and d["anchors"] == 2, d
assert [(g["file"], g["slug"]) for g in d["gaps"]] == [(".mega-sdd/knowledge-base/modules/a.prd.md", "3-flow")], d["gaps"]
assert d["gaps"][0]["halt_type"] == "plan_coverage_gap" and "a.prd.md#3-flow" in d["next_action"], d["next_action"]
assert d["prd"] == ".mega-sdd/knowledge-base/README.md" and d["sources"] == [".mega-sdd/knowledge-base/modules/a.prd.md"], d
EOF
echo '{"open_questions":[{"tag":"OQ-FL-1","text":"\"3. Flow\" — who approves?","status":"open"}]}' > "$V/vault.json"
cov; [ $? -eq 1 ] && ok "C2 an OQ quoting the heading decides nothing (every module has a '3. Flow')" || bad "C2 bare-heading OQ counted"
echo '{"open_questions":[{"tag":"OQ-FL-1","text":"a.prd.md 3. Flow — who approves?","status":"open"}]}' > "$V/vault.json"
cov; [ $? -eq 1 ] && ok "C3 an OQ that only MENTIONS the heading words (not quoted, no §, no ref) covers nothing, file named or not" || bad "C3 a bare mention counted"
echo '{"open_questions":[{"tag":"OQ-FL-1","text":"a.prd.md \"3. Flow\" — who approves?","origin":".mega-sdd/knowledge-base/modules/a.prd.md#3-flow","status":"open"}]}' > "$V/vault.json"
cov; [ $? -eq 1 ] && ok "C3 the module file + the quoted heading, or an [origin:] ref, decide nothing — only [covers:] does (RED)" || bad "C3 an incidental citation counted"
echo '{"open_questions":[{"tag":"OQ-FL-1","text":"who approves? [covers: .mega-sdd/knowledge-base/modules/a.prd.md#3-flow]","status":"resolved"}]}' > "$V/vault.json"
cov; [ $? -eq 1 ] && ok "C3 a resolved OQ covers nothing, even with [covers:]" || bad "C3 a resolved OQ counted"
echo '{"open_questions":[{"tag":"OQ-FL-1","text":"who approves? [covers: .mega-sdd/knowledge-base/modules/a.prd.md#3-flow]","status":"open"}]}' > "$V/vault.json"
cov; [ $? -eq 0 ] && ok "C3 an open OQ carrying [covers: <kb>/modules/a.prd.md#3-flow] decides it" || bad "C3 [covers:] not counted"
echo '{"open_questions":[{"tag":"OQ-FL-1","text":"who approves? [covers: a.prd.md#3-flow]","status":"open"}]}' > "$V/vault.json"
cov; [ $? -eq 1 ] && ok "C3 ... a bare module basename in [covers:] is no ref (refs are paths from the project root)" || bad "C3 basename ref counted"
echo '{"open_questions":[]}' > "$V/vault.json"
mkunit U-002 'a.prd.md#3-flow'
cov; ec=$?
python3 - "$ST" "$ec" <<'EOF2' && ok "M5 a unit prd_source 'a.prd.md#3-flow' (bare basename) decides nothing — validate-unit-spec.sh rejects it too; the notes say so (RED)" || bad "M5 basename prd_source counted"
import json, sys
d = json.load(open(sys.argv[1])); ec = int(sys.argv[2])
assert ec == 1 and [g["slug"] for g in d["gaps"]] == ["3-flow"] and any("U-002.md → a.prd.md#3-flow" in n for n in d["notes"]), d
EOF2
( cd "$W" && bash "$P/scripts/validate-unit-spec.sh" --cwd="$W" --quiet </dev/null >/dev/null 2>&1 )
python3 -c "import json,sys; d=json.load(open('$W/.mega-sdd/.unit-spec-state.json')); sys.exit(0 if [i for i in d.get('issues', []) if i.get('halt_type') == 'prd_source_unresolvable' and i.get('unit_id') == 'U-002'] else 1)" \
  && ok "M5 ... validate-unit-spec.sh: prd_source_unresolvable for the same ref (the two agree)" || bad "M5 unit-spec disagrees"
echo '{"open_questions":[]}' > "$V/vault.json"
mkunit U-002 '.mega-sdd/knowledge-base/modules/a.prd.md#3-flow'
cov; ec=$?
python3 - "$ST" "$ec" <<'EOF' && ok "C4 once a unit's prd_source cites it → PASS exit 0" || bad "C4 not PASS"
import json, sys
d = json.load(open(sys.argv[1])); ec = int(sys.argv[2])
assert ec == 0 and d["status"] == "PASS" and d["gaps"] == [] and d["covered"] == 2, d
EOF
cat > "$KB/modules/b.prd.md" <<'EOF'
# PRD — Payments

## 1. Purpose
Takes payments.

## 3. Flow
x
EOF
cov; ec=$?
python3 - "$ST" "$ec" <<'EOF' && ok "C5 a second module's same-named heading is its own anchor (a.prd.md#3-flow does not cover b.prd.md)" || bad "C5 cross-module leak"
import json, sys
d = json.load(open(sys.argv[1])); ec = int(sys.argv[2])
assert ec == 1 and [g["file"].rsplit("/", 1)[1] for g in d["gaps"]] == ["b.prd.md"], d["gaps"]
EOF
( cd "$W" && bash "$COV" --cwd="$W" --kb=.mega-sdd/knowledge-base --prd=x.md --vault="$V" --quiet </dev/null >/dev/null 2>&1 ); [ $? -eq 2 ] && ok "C6 --kb with --prd → exit 2" || bad "C6 exit"
# a legacy numbered-tree KB (no modules/) is censused over 10-domains/ — never a usage error
# (exit 2 writes no state, and the execute-bolts predictive gate is FATAL without it)
L="$N/kb"; LV="$N/.mega-sdd/vaults/t"; mkdir -p "$L/10-domains" "$LV/units"; echo '{"open_questions":[]}' > "$LV/vault.json"
printf '# Leave\n\n## 1. Purpose\nx\n\n## 7. Business Rules\nx\n\n## 10. Open Questions\nx\n\n## 11. Source References\nx\n' > "$L/10-domains/10-leave.md"
( cd "$N" && bash "$COV" --cwd="$N" --kb=kb --vault="$LV" --quiet </dev/null ); ec=$?
python3 - "$N/.mega-sdd/.plan-coverage-state.json" "$ec" <<'EOF' && ok "C7 numbered-tree KB → census over 10-domains/*.md (§1/§10/§11 meta); the gap names the domain file" || bad "C7 numbered-tree KB"
import json, sys
d = json.load(open(sys.argv[1])); ec = int(sys.argv[2])
assert ec == 1 and d["anchors"] == 1 and [(g["file"], g["slug"]) for g in d["gaps"]] == [("kb/10-domains/10-leave.md", "7-business-rules")], d
EOF

echo "── K: --kb census = the template's sections, never a prefix (V7 fail-open) ──"
# Each case is its own project; the gap list (and, where given, the anchor set) is exact.
MD=.mega-sdd/knowledge-base/modules
kproj() {  # kproj <name> → prints a fresh project root (KB README + empty vault k)
  local r="$T/k-$1"; mkdir -p "$r/$MD" "$r/.mega-sdd/vaults/k/units"
  printf '# K\n\n## Reengineering Opportunities\n- x\n' > "$r/.mega-sdd/knowledge-base/README.md"
  echo '{"open_questions":[]}' > "$r/.mega-sdd/vaults/k/vault.json"; echo "$r"
}
kunit() {  # kunit <root> <U-id> <prd_source ref>...
  local r="$1" id="$2" s; shift 2; s="$(printf '%s, ' "$@")"
  printf -- '---\nid: %s\ntitle: %s\ntask_type: create\ncontext_source: context.md#flows\nprd_source: [%s]\ntarget_files:\n  - path: src/%s.ts\n    operation: create\nacceptance_test:\n  - type: test\n    command: x\n    expects: ""\n---\n# %s\n' \
    "$id" "$id" "${s%, }" "$id" "$id" > "$r/.mega-sdd/vaults/k/units/$id.md"
}
kmod() {  # kmod <root> <module> — a template-shaped module PRD; stdin = extra lines at the end of §2
  { printf -- '---\ngenerated_by: mega-sdd:extract-intelligence\ndomain: %s\n---\n# PRD — %s\n\n## 1. Purpose\nKirim uang (a.php:1).\n\n## 2. Business Rules\n| ID | Rule | Source | Mutability |\n|---|---|---|---|\n| BR-1 | r | a.php:2 | [LOCKED] |\n\n' "$2" "$2"
    cat; printf '\n## 3. Flow\nx\n\n## 6. Open Questions\n_Tidak ada._\n'; } > "$1/$MD/$2.prd.md"
}
kbase() { kunit "$1" U-001 "$MD/$2.prd.md#2-business-rules" "$MD/$2.prd.md#3-flow"; }  # covers §2 + §3
kcov() { rm -f "$1/.mega-sdd/.plan-coverage-state.json"; ( cd "$1" && bash "$COV" --cwd="$1" --kb="${2:-.mega-sdd/knowledge-base}" --vault=.mega-sdd/vaults/k --quiet </dev/null ); }
kchk() {  # kchk <label> <root> <exit> <want-exit> '<want gaps: m.md#slug …>' ['<want anchors, exact set>']
  python3 - "$2/.mega-sdd/.plan-coverage-state.json" "$3" "$4" "$5" "${6-}" <<'EOF' && ok "$1" || bad "$1"
import json, sys
d = json.load(open(sys.argv[1])); ec, want_ec = int(sys.argv[2]), int(sys.argv[3])
want_gaps, want_anchors = sorted(sys.argv[4].split()), sorted(sys.argv[5].split())
key = lambda a: "%s#%s" % (a["file"].rsplit("/", 1)[-1], a["slug"])
gaps = sorted(key(g) for g in d["gaps"])  # declared exclusions are anchors too (decided, not covered)
anchors = sorted(gaps + [key(c) for c in d["covered_detail"]] + [key(x) for x in d["excluded"] if x.get("by") == "declared"])
assert ec == want_ec and d["status"] == ("PASS" if want_ec == 0 else "FAIL"), (ec, d["status"], gaps)
assert gaps == want_gaps, "gaps %s != want %s" % (gaps, want_gaps)
assert not want_anchors or anchors == want_anchors, "anchors %s != want %s" % (anchors, want_anchors)
assert d["anchors"] == len(anchors), d
EOF
}
r="$(kproj k1)"; kbase "$r" remit
kmod "$r" remit <<'EOF'
### Purpose code validation
Kode tujuan transaksi wajib sesuai daftar BI (a.php:10). [LOCKED]
EOF
kcov "$r"; kchk "K1 'Purpose code validation' is a requirement, not §1 Purpose (prefix match dropped it)" "$r" $? 1 'remit.prd.md#purpose-code-validation'
r="$(kproj k2)"; kbase "$r" remit
kmod "$r" remit <<'EOF'
### Source reference number format
Nomor referensi 16 digit (a.php:40). [LOCKED]
EOF
kcov "$r"; kchk "K2 'Source reference number format' is a requirement, not a Source References section" "$r" $? 1 'remit.prd.md#source-reference-number-format'
r="$(kproj k3)"; kbase "$r" remit
kmod "$r" remit <<'EOF'
### Open question tickets escalate after 3 days
Tiket pertanyaan nasabah yang belum dijawab naik ke supervisor setelah 3 hari (a.php:50). [LOCKED]
EOF
kcov "$r"; kchk "K3 'Open question tickets escalate …' is a requirement, not §6 Open Questions" "$r" $? 1 'remit.prd.md#open-question-tickets-escalate-after-3-days'
r="$(kproj k4)"; kbase "$r" remit; kunit "$r" U-002 "$MD/remit.prd.md#limit-harian"
kmod "$r" remit <<'EOF'
### Tidak termasuk biaya admin untuk nasabah prioritas
Nasabah prioritas bebas biaya (a.php:20). [LOCKED]
### Limit harian
Limit 100 juta (a.php:30).
EOF
kcov "$r"; kchk "K4 'Tidak termasuk biaya admin …' is a requirement, not an out-of-scope section" "$r" $? 1 'remit.prd.md#tidak-termasuk-biaya-admin-untuk-nasabah-prioritas'
r="$(kproj k5)"; kbase "$r" remit
kmod "$r" remit <<'EOF'
### Out of scope currency rejection
Mata uang di luar daftar ditolak dengan kode R07 (a.php:60). [LOCKED]
EOF
kcov "$r"; kchk "K5 'Out of scope currency rejection' is a requirement, not an out-of-scope section" "$r" $? 1 'remit.prd.md#out-of-scope-currency-rejection'
r="$(kproj k6)"; kbase "$r" remit
kmod "$r" remit <<'EOF'
## 7. Tidak termasuk hari libur dalam perhitungan jatuh tempo
Hari libur nasional tidak dihitung (a.php:70). [LOCKED]
### Geser ke hari kerja berikutnya
Jatuh tempo di hari libur digeser (a.php:71). [LOCKED]
EOF
kcov "$r"; kchk "K6 an out-of-scope-PREFIXED H2 is a requirement and so is every heading nested under it" "$r" $? 1 \
  'remit.prd.md#7-tidak-termasuk-hari-libur-dalam-perhitungan-jatuh-tempo remit.prd.md#geser-ke-hari-kerja-berikutnya'
r="$(kproj k7)"; kbase "$r" remit
kmod "$r" remit <<'EOF'
Banner yang dicetak job legacy (a.php:1):
```bash
## KOPERASI — REMIT v2.1 ##
### build 2009-04-01
```
~~~text
## tilde-fenced banner
~~~
````markdown
```md
## quoted markdown inside a 4-backtick fence
```
````
EOF
kcov "$r"; kchk "K7 headings inside fenced code (\`\`\` / ~~~ / 4-backtick) are not censused" "$r" $? 0 '' 'remit.prd.md#2-business-rules remit.prd.md#3-flow'
r="$(kproj k8)"; kbase "$r" a; kunit "$r" U-002 "$MD/b.prd.md#2-business-rules" "$MD/b.prd.md#3-flow"
printf '# PRD — A\n\n## 1. Tujuan\nx (a.php:1)\n\n## 2. Business Rules\nx\n\n## 3. Flow\nx\n\n## 6. Pertanyaan Terbuka\n_Tidak ada._\n' > "$r/$MD/a.prd.md"
printf '# PRD — B\n\n## 1. Purpose (Tujuan)\nx (b.php:1)\n\n## 2. Business Rules\nx\n\n## 3. Flow\nx\n\n## 6. Pertanyaan Terbuka (Open Questions)\n_Tidak ada._\n' > "$r/$MD/b.prd.md"
kcov "$r"; kchk "K8 Indonesian template meta ('1. Tujuan', '6. Pertanyaan Terbuka', bilingual 'X (Y)') is not censused" "$r" $? 0 '' \
  'a.prd.md#2-business-rules a.prd.md#3-flow b.prd.md#2-business-rules b.prd.md#3-flow'
r="$(kproj k9)"; kbase "$r" remit
printf '# PRD — R\n\n## 1. Purpose\nx (a.php:1)\n\n## 2. Business Rules\nx\n### Purpose\nKode tujuan ditentukan teller (a.php:5). [LOCKED]\n\n## 3. Flow\nx\n\n## 4. Open Questions\nx\n\n## 6. Open Questions\n_Tidak ada._\n' > "$r/$MD/remit.prd.md"
kcov "$r"; kchk "K9 a meta name counts only as its template H2 (§1/§6): an H3 'Purpose' or a '4. Open Questions' is censused" "$r" $? 1 \
  'remit.prd.md#purpose remit.prd.md#4-open-questions'
r="$(kproj k10)"; kbase "$r" remit
kmod "$r" remit <<'EOF'
### Tidak termasuk:
Biaya korespondensi bank luar.
## Out of scope
Tidak dibangun ulang.
### Kirim via SWIFT gpi
Belum dipakai.
## 8. Di luar lingkup
x
## Out of scope (Di luar lingkup)
x
## 9. Batch harian
Rekap jam 23:00 (a.php:90). [LOCKED]
EOF
kcov "$r"; kchk "K10 out-of-scope-named sections (EN/ID, numbered, bilingual) and their sub-headings are anchors until declared" "$r" $? 1 \
  'remit.prd.md#tidak-termasuk remit.prd.md#out-of-scope remit.prd.md#kirim-via-swift-gpi remit.prd.md#8-di-luar-lingkup remit.prd.md#out-of-scope-di-luar-lingkup remit.prd.md#9-batch-harian'
kctx() { printf '# ctx\n\n## Open Questions\n- none\n\n## Coverage exclusions\n' > "$1/.mega-sdd/vaults/k/context.md"; cat >> "$1/.mega-sdd/vaults/k/context.md"; }
kctx "$r" <<'EOF'
- remit.prd.md#"Tidak termasuk:" — correspondent-bank fees are billed outside this module
- remit.prd.md#out-of-scope — the rebuild drops these features (keputusan pengurus)
- remit.prd.md#"Kirim via SWIFT gpi" — not used by the legacy system
- .mega-sdd/knowledge-base/modules/remit.prd.md#8-di-luar-lingkup — legacy-only screens
- remit.prd.md#"Out of scope (Di luar lingkup)" - bilingual duplicate of the section above
EOF
kcov "$r"; kchk "K10 ... module-qualified declarations (quoted text, slug, full path; — – - after a quote, — after a slug) leave only '9. Batch harian'; the 5 declared stay anchors" "$r" $? 1 'remit.prd.md#9-batch-harian' \
  'remit.prd.md#2-business-rules remit.prd.md#3-flow remit.prd.md#tidak-termasuk remit.prd.md#out-of-scope remit.prd.md#kirim-via-swift-gpi remit.prd.md#8-di-luar-lingkup remit.prd.md#out-of-scope-di-luar-lingkup remit.prd.md#9-batch-harian'
r="$(kproj k11)"; kbase "$r" remit
kmod "$r" remit <<'EOF'
```bash
## banner (fence never closed)
## 4. Data In/Out
Input nominal (a.php:3).
```mermaid
flowchart LR
  A --> B
```
## 5. Edge Cases & Gotchas
- G-1 (a.php:4)
```
EOF
kcov "$r"; kchk "K11 a malformed fence (missing closer / unclosed at EOF) never hides a heading — fail closed" "$r" $? 1 \
  'remit.prd.md#banner-fence-never-closed remit.prd.md#4-data-in-out remit.prd.md#5-edge-cases-gotchas'
r="$(kproj k12)"; mkdir -p "$r/.mega-sdd/knowledge-base/10-domains"; kunit "$r" U-001 ".mega-sdd/knowledge-base/10-domains/20-remit.md#7-business-rules"
printf '# Remit\n\n## 1. Tujuan\nx\n\n## 7. Business Rules\nx\n### Source reference number format\n16 digit\n### Purpose code validation\nBI list\n\n## 10. Pertanyaan Terbuka\nx\n\n## 11. Source References\nx\n' > "$r/.mega-sdd/knowledge-base/10-domains/20-remit.md"
kcov "$r"; kchk "K12 numbered-tree KB: §1/§10/§11 (EN or ID) excluded by template number, 'Source reference …'/'Purpose …' H3s censused" "$r" $? 1 \
  '20-remit.md#source-reference-number-format 20-remit.md#purpose-code-validation'
# K13/K14: the fence skip must not re-open the fail-open it closes — validate-extract-census
# greps '## N.' fence-blind, so a module passes the census gate even when a fence swallows its
# template sections; a "fence" that spans a numbered H2 (a section boundary) is not a fence.
r="$(kproj k13)"
printf -- '---\ngenerated_by: mega-sdd:extract-intelligence\ndomain: remit\n---\n````markdown\n# PRD — Remit\n\n## 1. Purpose\nx (a.php:1)\n\n## 2. Business Rules\n| BR-REMIT-1 | r | a.php:2 | [LOCKED] |\n\n## 3. Flow\n```mermaid\nflowchart LR\n  A --> B\n```\n\n## 6. Open Questions\n_Tidak ada._\n````\n' > "$r/$MD/remit.prd.md"
kcov "$r"; kchk "K13 a module wrapped whole in a \`\`\`\`markdown fence, no unit → FAIL on its sections (not a 0-anchor PASS)" "$r" $? 1 \
  'remit.prd.md#2-business-rules remit.prd.md#3-flow'
r="$(kproj k14)"; kbase "$r" remit
printf '# PRD — R\n\n## 1. Purpose\nx\n\n## 2. Business Rules\nx\n\n## 3. Flow\n```mermaid\nflowchart LR\n  A --> B\n\n## 4. Data In/Out\nInput nominal (a.php:3).\n\n## 5. Edge Cases & Gotchas\n- G-1 banner:\n```\n## KOPERASI v2 ##\n```\n\n## 6. Open Questions\n_Tidak ada._\n' > "$r/$MD/remit.prd.md"
kcov "$r"; kchk "K14 an unclosed mermaid fence is not closed by a later bare fence across §4/§5 (only the real banner fence is skipped)" "$r" $? 1 \
  'remit.prd.md#4-data-in-out remit.prd.md#5-edge-cases-gotchas'
# K15-K19 (9.0 round 1): the shared markdown parser + fail-closed rules hold under --kb too
r="$(kproj k15)"
printf '# PRD — Stub\n\n## 1. Purpose\nx (a.php:1)\n\n#### Limit harian\nLimit 100 juta (a.php:3).\n\n## 6. Open Questions\n_Tidak ada._\n' > "$r/$MD/stub.prd.md"
kcov "$r"; ec=$?
python3 - "$r/.mega-sdd/.plan-coverage-state.json" "$ec" <<'EOF' && ok "K15 a KB with ZERO requirement anchors is a FAIL (was a 0-anchor PASS)" || bad "K15 zero-anchor KB passed"
import json, sys
d = json.load(open(sys.argv[1])); ec = int(sys.argv[2])
assert ec == 1 and d["status"] == "FAIL" and d["anchors"] == 0 and "no heading" in d["next_action"], d
EOF
r="$(kproj k16)"; kbase "$r" remit
kmod "$r" remit <<'EOF'
<!--
## Out of scope
-->
### Limit harian
Limit 100 juta (a.php:30).
EOF
kcov "$r"; kchk "K16 an '## Out of scope' inside an HTML comment opens no region" "$r" $? 1 'remit.prd.md#limit-harian'
r="$(kproj k17)"; kbase "$r" remit
kmod "$r" remit <<'EOF'
## Out of scope
### Ekspor Excel
Tidak dibangun.
 ## 8. Batch harian
Rekap jam 23:00 (a.php:90). [LOCKED]

Rekap bulanan
-------------
Rekap tiap akhir bulan (a.php:95).
EOF
kcov "$r"; kchk "K17 an indented ATX H2 and a setext H2 are headings, censused like the rest" "$r" $? 1 \
  'remit.prd.md#ekspor-excel remit.prd.md#8-batch-harian remit.prd.md#rekap-bulanan'  # the body-less 'Out of scope' is a container
r="$(kproj k18)"; kbase "$r" remit
kmod "$r" remit <<'EOF'
## Out of scope
### Kirim via SWIFT
Biaya korespondensi wajib dibebankan ke nasabah (a.php:77). [LOCKED]
### Ekspor Excel
Tidak dibangun ulang.
EOF
kctx "$r" <<'EOF'
- remit.prd.md#"Out of scope" — the rebuild drops the features listed here
EOF
kcov "$r"; kchk "K18 declaring the out-of-scope H2 covers none of its H3s: 'Kirim via SWIFT' and 'Ekspor Excel' stay gaps" "$r" $? 1 'remit.prd.md#kirim-via-swift remit.prd.md#ekspor-excel'
r="$(kproj k19)"; kunit "$r" U-001 "$MD/a.prd.md#2-business-rules"
kmod "$r" a </dev/null
echo '{"open_questions":[{"text":"a.prd.md \"3. Flowchart\" must be redrawn?"},{"text":"data.prd.md \"3. Flow\" — who approves?"}]}' > "$r/.mega-sdd/vaults/k/vault.json"
kcov "$r"; kchk "K19 an OQ quote is the WHOLE heading and the file name is word-bounded ('3. Flowchart' is not '3. Flow'; 'data.prd.md' is not 'a.prd.md')" "$r" $? 1 'a.prd.md#3-flow'
# K20-K21 (round 2): comment / fence ends follow CommonMark containers, a forgotten closer hides nothing
r="$(kproj k20)"; kunit "$r" U-001 "$MD/remit.prd.md#4-data-in-out"
printf -- '---\ndomain: remit\n---\n# PRD — Remit\n\n## 1. Purpose\nKirim uang.\n<!-- reviewer: cek ulang deskripsi\nmodul ini dengan tim core banking\n\n## 2. Business Rules\n| ID | Rule | Source | Tier |\n|---|---|---|---|\n| BR-1 | Limit harian WAJIB Rp50.000.000 | a.php:42 | [LOCKED] |\n\n### Acceptance criteria\n- Transfer di atas limit ditolak (E05).\n\n## 3. Flow\n```mermaid\nflowchart LR\n  A[Input] --> B[Validasi limit] --> C[Posting]\n```\n\n## 4. Data In/Out\nInput: amount.\n\n## 6. Open Questions\n- none\n' > "$r/$MD/remit.prd.md"
kcov "$r"; kchk "K20 a forgotten '<!--' under §1 is not closed by the §3 Mermaid arrow: §2, its AC and §3 are censused" "$r" $? 1 \
  'remit.prd.md#2-business-rules remit.prd.md#acceptance-criteria remit.prd.md#3-flow'
r="$(kproj k21)"; kbase "$r" remit
kmod "$r" remit <<'EOF'
- Contoh request legacy:
  ```json
  {"amount": 150000}
- Nominal divalidasi (a.php:9).

### Limit harian
Limit 100 juta per nasabah (a.php:30). [LOCKED]

Banner:
```
KOPERASI v2
```
EOF
kcov "$r"; kchk "K21 a fence opened in a list item ends with the item: '### Limit harian' is not swallowed up to the next bare fence" "$r" $? 1 'remit.prd.md#limit-harian'
# K22-K24 (round 3): the file match has a path boundary, a kept exclusion is a feature, a shifted fence pairing hides nothing
r="$(kproj k22)"; kbase "$r" transfer; kmod "$r" transfer </dev/null; kmod "$r" scheduled-transfer </dev/null
kunit "$r" U-002 "transfer.prd.md#2-business-rules" "transfer.prd.md#3-flow"
kcov "$r"; kchk "K22 a bare 'transfer.prd.md' ref covers nothing in 'scheduled-transfer.prd.md' (path-boundary file match)" "$r" $? 1 \
  'scheduled-transfer.prd.md#2-business-rules scheduled-transfer.prd.md#3-flow'
r="$(kproj k23)"; kbase "$r" remit
kmod "$r" remit <<'EOF'
## Out of scope
Rekonsiliasi otomatis belum dibangun, tetapi ops WAJIB menutup selisih H+1 (a.php:70).
### Laporan selisih harian
Ops melihat daftar selisih per rekening (a.php:71).
EOF
kcov "$r"; kchk "K23 an undeclared out-of-scope H2 and its H3 are both gaps (no name opens a region)" "$r" $? 1 \
  'remit.prd.md#out-of-scope remit.prd.md#laporan-selisih-harian'
r="$(kproj k24)"; kbase "$r" remit
kmod "$r" remit <<'EOF'
Contoh request legacy:
```bash
curl -X POST /legacy/transfer

### Limit harian
Limit 100 juta per nasabah (a.php:30).

Payload:
```
{"amount": 1}
```

```json
{"status": "ok"}
```
EOF
kcov "$r"; kchk "K24 a forgotten \`\`\`bash closer is caught when a later \`\`\`json reads as another opener (no EOF)" "$r" $? 1 'remit.prd.md#limit-harian'
# K25-K27 (declared coverage under --kb)
r="$(kproj k25)"; kbase "$r" remit
kmod "$r" remit <<'EOF'
## Out of scope
Rekonsiliasi otomatis tidak dibangun ulang.
EOF
kctx "$r" <<'EOF'
- "Out of scope" — the heading text alone names no module
EOF
kcov "$r"; ec=$?
python3 - "$r/.mega-sdd/.plan-coverage-state.json" "$ec" <<'EOF' && ok "K25 a --kb declaration without its module file is INVALID (FAIL naming the context.md line) and decides nothing" || bad "K25 unqualified --kb declaration"
import json, sys
d = json.load(open(sys.argv[1])); ec = int(sys.argv[2])
bad = [g for g in d["gaps"] if g["heading"].startswith("(invalid coverage exclusion)")]
assert ec == 1 and [g["slug"] for g in d["gaps"] if g["slug"]] == ["out-of-scope"], d["gaps"]
assert len(bad) == 1 and bad[0]["line"] == 7 and bad[0]["file"].endswith("vaults/k/context.md") and "name the module file" in bad[0]["why"], bad
EOF
r="$(kproj k26)"; kbase "$r" a; kunit "$r" U-002 "$MD/b.prd.md#2-business-rules" "$MD/b.prd.md#3-flow"
printf '## Out of scope\nx\n' | kmod "$r" a; printf '## Out of scope\nx\n' | kmod "$r" b
kctx "$r" <<'EOF'
- a.prd.md#out-of-scope — module a drops the batch export
EOF
kcov "$r"; kchk "K26 a module-qualified declaration covers that module's heading only (b.prd.md's same-named section stays a gap)" "$r" $? 1 'b.prd.md#out-of-scope'
kctx "$r" <<'EOF'
- a.prd.md#out-of-scope — module a drops the batch export
- b.prd.md#"Out of scope" — TBD
EOF
kcov "$r"; ec=$?
python3 - "$r/.mega-sdd/.plan-coverage-state.json" "$ec" <<'EOF' && ok "K27 a placeholder reason ('TBD') is INVALID under --kb too: FAIL naming line 8, the heading stays a gap" || bad "K27 placeholder reason"
import json, sys
d = json.load(open(sys.argv[1])); ec = int(sys.argv[2])
assert ec == 1 and sorted((g["slug"], g["line"], g.get("why", "")[:27]) for g in d["gaps"]) == [("", 8, "empty or placeholder reason"), ("out-of-scope", 15, "")], d["gaps"]
EOF

echo "── R: a realistic multi-module KB ──"
r="$(kproj real)"
cat > "$r/$MD/pinjaman.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
generated_at: 2026-09-27T10:00:00Z
domain: pinjaman
classification: workflow
criticality: high
depends_on: [angsuran]
rebuild_after: []
source_files:
  - pinjaman/ajukan.php
  - pinjaman/hitung_bunga.php
inferred_count: 0
open_count: 1
locked_count: 2
intent_count: 1
artifact_count: 0
source_files_cited: 2
---
# PRD — Pinjaman (Pengajuan Pinjaman Anggota)

## 1. Purpose
Menerima pengajuan pinjaman anggota koperasi dan mencatatnya berstatus DIAJUKAN (pinjaman/ajukan.php:4).

## 2. Business Rules
| ID | Rule | Why | Source | Confidence | Mutability |
|---|---|---|---|---|---|
| BR-PINJAMAN-1 | Plafon maksimal Rp 50.000.000 per pengajuan | batas risiko | pinjaman/ajukan.php:7 | | [LOCKED] |
| BR-PINJAMAN-2 | Tenor 3 sampai 36 bulan | kebijakan produk | pinjaman/ajukan.php:8 | | [INTENT] |

### Acceptance criteria
- AC-BR-PINJAMAN-1-1 — given plafon 50.000.001 · when diajukan · then ditolak "Plafon melebihi batas" · oracle: golden-master legacy run

### Purpose code validation
Kode tujuan pinjaman wajib PRODUKTIF, KONSUMTIF atau DARURAT (pinjaman/ajukan.php:12). [LOCKED]

## 3. Flow
```mermaid
flowchart TD
  A["Anggota isi form"] --> B{"Plafon <= 50 juta?"}
  B -->|tidak| X["Tolak"]
  B -->|ya| C["Catat DIAJUKAN"]
```

```mermaid
stateDiagram-v2
  [*] --> DIAJUKAN : submit — validasi lolos
  DIAJUKAN --> [*]
```

## 4. Data In/Out
- Input: identitas anggota, plafon, tenor (pinjaman/ajukan.php:4-6).
- Output: satu record pinjaman berstatus DIAJUKAN (pinjaman/ajukan.php:13).

## 5. Edge Cases & Gotchas
- G-1: validasi berhenti tanpa rollback (pinjaman/ajukan.php:7) — do-not-replicate.
- G-2: banner versi dicetak ke log setiap submit (pinjaman/ajukan.php:1) — do-not-replicate:
```bash
## KOPERASI SEJAHTERA — PINJAMAN v2.1 ##
### build 2009-04-01
```
- G-3: tenor tepat 12 bulan tetap 1,5% (pinjaman/hitung_bunga.php:4) — replicate.

## 6. Open Questions
- OQ-PINJAMAN-01 [P2] Siapa yang menyetujui pencairan setelah DIAJUKAN? (probe-glob: pinjaman/setujui*.php)

## 7. Run & Recovery
- (a) Pemicu: form web anggota (pinjaman/ajukan.php:4).
- (c) Rerun: submit ganda membuat dua record — [UNKNOWN], lihat OQ-PINJAMAN-01.
EOF
cat > "$r/$MD/angsuran.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: angsuran
classification: workflow
criticality: high
source_files:
  - angsuran/bayar.php
  - angsuran/denda.php
---
# PRD — Angsuran

## 1. Purpose
Mencatat pembayaran angsuran dan menghitung denda keterlambatan (angsuran/bayar.php:3).

## 2. Business Rules
| ID | Rule | Why | Source | Confidence | Mutability |
|---|---|---|---|---|---|
| BR-ANGSURAN-1 | Denda 0,1% per hari keterlambatan | AD/ART | angsuran/denda.php:5 | | [LOCKED] |

### Acceptance criteria
- AC-BR-ANGSURAN-1-1 — given terlambat 10 hari atas 1.000.000 · when dibayar · then denda 10.000 · oracle: golden-master legacy run

### Tidak termasuk denda untuk angsuran yang jatuh tempo di hari libur
Angsuran yang jatuh tempo di hari libur tidak didenda bila dibayar di hari kerja berikutnya (angsuran/denda.php:9). [LOCKED]

## 3. Flow
```mermaid
flowchart LR
  A["Terima pembayaran"] --> B["Hitung denda"] --> C["Catat angsuran"]
```

## 4. Data In/Out
- Input: nomor pinjaman, nominal (angsuran/bayar.php:4).

## 5. Edge Cases & Gotchas
- G-1: pembayaran parsial tidak ditolak (angsuran/bayar.php:8) — open.
- G-2: denda dihitung dengan jam server (angsuran/denda.php:3) — do-not-replicate.
- G-3: pembulatan ke bawah (angsuran/denda.php:6) — replicate.

## 6. Open Questions
_Tidak ada._

## 7. Run & Recovery
- (a) Pemicu: teller (angsuran/bayar.php:3).
EOF
cat > "$r/$MD/laporan.prd.md" <<'EOF'
---
generated_by: mega-sdd:extract-intelligence
domain: laporan
classification: reporting
criticality: medium
source_files:
  - laporan/rekap_bulanan.php
---
# PRD — Laporan Rekap Bulanan

## 1. Tujuan
Rekap pinjaman dan angsuran per bulan untuk pengurus (laporan/rekap_bulanan.php:2).

## 2. Business Rules
| ID | Rule | Why | Source | Confidence | Mutability |
|---|---|---|---|---|---|
| BR-LAPORAN-1 | Rekap per bulan kalender | RAT | laporan/rekap_bulanan.php:6 | | [INTENT] |

### Source reference number format
Nomor referensi laporan REK-<YYYYMM>-<4 digit> (laporan/rekap_bulanan.php:15). [LOCKED]

## 3. Flow
```mermaid
flowchart LR
  A["Ambil transaksi bulan"] --> B["Rekap"] --> C["Cetak"]
```

## 4. Data In/Out
- Output: dokumen rekap (laporan/rekap_bulanan.php:20).

## 5. Edge Cases & Gotchas
_Tidak terdeteksi._

## 6. Pertanyaan Terbuka (Open Questions)
_Tidak ada._

## Out of scope
Fitur legacy yang tidak dibangun ulang:
### Ekspor ke Excel
Tidak dibangun ulang — keputusan pengurus.
EOF
tmpl="2-business-rules acceptance-criteria 3-flow 4-data-in-out 5-edge-cases-gotchas 7-run-recovery"
kunit "$r" U-001 $(for s in $tmpl; do echo "$MD/pinjaman.prd.md#$s"; done)
kunit "$r" U-002 $(for s in $tmpl; do echo "$MD/angsuran.prd.md#$s"; done)
kunit "$r" U-003 $(for s in 2-business-rules 3-flow 4-data-in-out 5-edge-cases-gotchas; do echo "$MD/laporan.prd.md#$s"; done)
RA="$(for s in $tmpl purpose-code-validation; do printf 'pinjaman.prd.md#%s ' "$s"; done)$(for s in $tmpl tidak-termasuk-denda-untuk-angsuran-yang-jatuh-tempo-di-hari-libur; do printf 'angsuran.prd.md#%s ' "$s"; done)$(for s in 2-business-rules source-reference-number-format 3-flow 4-data-in-out 5-edge-cases-gotchas; do printf 'laporan.prd.md#%s ' "$s"; done)"
RA="$RA laporan.prd.md#out-of-scope laporan.prd.md#ekspor-ke-excel"
kcov "$r"; kchk "R1 realistic 3-module KB: the 3 extractor-added [LOCKED] H3s with no unit and the undeclared Out-of-scope section + its H3 are the gaps (template meta / fenced banner not censused)" "$r" $? 1 \
  'pinjaman.prd.md#purpose-code-validation angsuran.prd.md#tidak-termasuk-denda-untuk-angsuran-yang-jatuh-tempo-di-hari-libur laporan.prd.md#source-reference-number-format laporan.prd.md#out-of-scope laporan.prd.md#ekspor-ke-excel' "$RA"
python3 - "$r/.mega-sdd/.plan-coverage-state.json" <<'EOF' && ok "R2 each gap names its own module file in gaps[] and next_action" || bad "R2 gap file naming"
import json, sys
d = json.load(open(sys.argv[1])); M = ".mega-sdd/knowledge-base/modules/"
want = {M + "pinjaman.prd.md#purpose-code-validation", M + "angsuran.prd.md#tidak-termasuk-denda-untuk-angsuran-yang-jatuh-tempo-di-hari-libur", M + "laporan.prd.md#source-reference-number-format", M + "laporan.prd.md#out-of-scope", M + "laporan.prd.md#ekspor-ke-excel"}
assert {"%s#%s" % (g["file"], g["slug"]) for g in d["gaps"]} == want, d["gaps"]
assert all(w in d["next_action"] for w in want), d["next_action"]
assert '- laporan.prd.md#"Out of scope" — <reason>' in d["next_action"], d["next_action"]  # the paste-ready, module-qualified line
EOF
kunit "$r" U-004 "$MD/pinjaman.prd.md#purpose-code-validation"
kunit "$r" U-005 "$MD/angsuran.prd.md:$(( $(grep -n '^### Tidak termasuk denda' "$r/$MD/angsuran.prd.md" | cut -d: -f1) + 1 ))"
kctx "$r" <<'EOF'
- laporan.prd.md#"Out of scope" — pengurus decided not to rebuild these
- laporan.prd.md#"Ekspor ke Excel" — not rebuilt (keputusan pengurus)
EOF
python3 - "$r/.mega-sdd/vaults/k/context.md" <<'EOF'  # the OQ lives in context.md (vault.json is derived after the gate)
import sys; p = sys.argv[1]; t = open(p).read()
q = '- [ ] **OQ-LAP-1** [P1] [business] [covers: .mega-sdd/knowledge-base/modules/laporan.prd.md#source-reference-number-format]: apakah REK-<YYYYMM> wajib dipertahankan?'
open(p, "w").write(t.replace("## Open Questions\n- none\n", "## Open Questions\n" + q + "\n"))
EOF
kcov "$r"; kchk "R3 slug unit + :line unit + an OQ with [covers:] + two module-qualified declarations close the 5 gaps → PASS over the same 21 anchors" "$r" $? 0 '' "$RA"
python3 - "$r/.mega-sdd/.plan-coverage-state.json" <<'EOF' && ok "R4 excluded[] lists the 2 declared headings with their reason and the 6 template sections (§1 / §6 per module)" || bad "R4 excluded[]"
import json, sys
d = json.load(open(sys.argv[1])); x = d["excluded"]
assert sorted((e["file"].rsplit("/", 1)[1], e["slug"], e["reason"]) for e in x if e["by"] == "declared") == [
    ("laporan.prd.md", "ekspor-ke-excel", "not rebuilt (keputusan pengurus)"), ("laporan.prd.md", "out-of-scope", "pengurus decided not to rebuild these")], x
assert sorted("%s#%s" % (e["file"].rsplit("/", 1)[1], e["slug"]) for e in x if e["by"] == "kb_template") == sorted([
    "pinjaman.prd.md#1-purpose", "pinjaman.prd.md#6-open-questions", "angsuran.prd.md#1-purpose", "angsuran.prd.md#6-open-questions",
    "laporan.prd.md#1-tujuan", "laporan.prd.md#6-pertanyaan-terbuka-open-questions"]), x
EOF

# F4 (round 5): a KB-born vault's entry is bound to the modules its README pin holds NOW, and --prd cannot stand in for --kb
PF="${PREFLIGHT_SCRIPT:-$P/scripts/validate-preflight.sh}"
r="$(kproj f4)"; kbase "$r" remit; kmod "$r" remit </dev/null; kctx "$r" </dev/null
python3 - "$r/.mega-sdd/vaults/k/context.md" <<'EOF2'
import sys; p = sys.argv[1]; t = open(p).read(); open(p, "w").write("---\nprd_path_at_generation: .mega-sdd/knowledge-base/README.md\n---\n" + t)
EOF2
kcov "$r" >/dev/null; pre() { ( cd "$r" && bash "$PF" --cwd="$r" --skill=mega-sdd:execute-bolts --quiet </dev/null >/dev/null 2>&1 ); echo $?; }
[ "$(pre)" = 0 ] && ok "R5 a KB-born vault (pin = <kb>/README.md) PASSes and the execute-bolts preflight passes" || bad "R5 preflight on the KB PASS"
printf '# PRD — Simpanan\n\n## 1. Purpose\nx\n\n## 2. Business Rules\nBunga harian (s.php:4). [LOCKED]\n' > "$r/$MD/simpanan.prd.md"
[ "$(pre)" = 1 ] && ok "F4 a module added to the KB after the PASS makes the entry stale → execute-bolts refused (RED)" || bad "F4 an added module kept the PASS"
( cd "$r" && bash "$COV" --cwd="$r" --prd=.mega-sdd/knowledge-base/README.md --vault=.mega-sdd/vaults/k --quiet </dev/null >/dev/null 2>&1 ); ec=$?
[ $ec -eq 2 ] && ok "F4 ... and --prd=<kb>/README.md on the KB-born vault is a usage error (exit 2): its pin needs --kb (RED)" || bad "F4 README census accepted (rc=$ec)"
kcov "$r"; kchk "F4 ... re-running --kb reports the new module's section" "$r" $? 1 'simpanan.prd.md#2-business-rules'

echo "── W: wiring (extract-intelligence → plan --kb) ──"
EI="$P/skills/extract-intelligence"; SK="$P/skills/plan/SKILL.md"
grep -qF 'plan --kb=<out>/knowledge-base/' "$EI/SKILL.md" && grep -qF 'mega-sdd:plan --kb=<kb> --auto' "$EI/SKILL.md" \
  && ok "W1 extract-intelligence announces and hands off to plan --kb" || bad "W1 extract-intelligence hand-off"
grep -qF 'suggested_skill: mega-sdd:plan' "$EI/references/handoff.md" && ok "W2 --auto handoff YAML names mega-sdd:plan" || bad "W2 handoff.md"
grep -qF -- '--kb=<kb-dir>' "$SK" && grep -qF 'references/kb-input.md' "$SK" && [ -f "$P/skills/plan/references/kb-input.md" ] \
  && ok "W3 plan accepts --kb and routes to references/kb-input.md" || bad "W3 plan --kb route"
grep -q 'generate-intent' "$SK" && bad "W4 plan still routes a KB to generate-intent" || ok "W4 plan names no generate-intent route (the KB refusal is gone)"
grep -qF 'skills/plan/references/templates/ai-consumer-guide.md' "$SK" && [ -f "$P/skills/plan/references/templates/ai-consumer-guide.md" ] \
  && ok "W5 the Step-3 consumer-guide cp source exists" || bad "W5 consumer-guide cp source"
grep -qF -- '--kb=<kb-dir>' "$P/skills/plan/references/plan-procedure.md" && grep -qF 'plan --kb=$APATH' "$P/scripts/certify-artifact.sh" \
  && ok "W6 plan-procedure + the certify kb rung name plan --kb" || bad "W6 procedure/certify"
exit $rc
