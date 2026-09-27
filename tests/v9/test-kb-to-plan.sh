#!/usr/bin/env bash
# KB → plan — the legacy-rebuild hand-off stays buildable (spec docs/superpowers/specs/
# 2026-09-27-v9-simplification-design.md §0.2 + §4 + §7 decision 6; a P1 exit criterion).
# extract-intelligence writes a PRD-kontrak KB; `plan --kb=<kb-dir>` turns it into the
# layout-3 vault + units. Pinned here:
#   P  derive-plan-pins.sh --kb: prd_path = <kb>/README.md, prd_sha256 = sha256 of
#      <kb>/census.json (README when a numbered-tree KB has none), project_scale standard
#   C  validate-plan-coverage.sh --kb: every module heading of <kb>/modules/*.prd.md (a numbered-tree KB: 10-domains/*.md)
#      (minus §1 Purpose / §6 Open Questions) needs a unit prd_source or an OQ that
#      names the module file; a FAIL names the gap and its module
#   K  the --kb census excludes ONLY the template's own meta sections (numbered H2, EN/ID
#      name, whole heading) and ONLY a heading that IS an out-of-scope section — never a
#      prefix (V7 fail-open: 'Purpose code validation', 'Source reference number format',
#      'Tidak termasuk biaya admin …' were silently dropped); fenced code is not censused;
#      a malformed fence, or one spanning a numbered section H2, never hides a heading
#   R  a realistic multi-module KB (frontmatter, tables, AC, mermaid, a quoted legacy
#      banner, §7, Indonesian meta headings, an Out-of-scope section, extractor-added
#      [LOCKED] H3s) — the gaps are exactly the uncovered requirement headings
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
echo '{"open_questions":[{"tag":"OQ-FL-1","text":"3. Flow — who approves?","status":"open"}]}' > "$V/vault.json"
cov; [ $? -eq 1 ] && ok "C2 an OQ quoting the heading but not the module file does not cover it (every module has a '3. Flow')" || bad "C2 bare-heading OQ counted"
echo '{"open_questions":[{"tag":"OQ-FL-1","text":"a.prd.md 3. Flow — who approves?","status":"open"}]}' > "$V/vault.json"
cov; [ $? -eq 0 ] && ok "C3 an OQ naming the module file + quoting the heading covers it" || bad "C3 module-scoped OQ not counted"
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
gaps = sorted(key(g) for g in d["gaps"]); anchors = sorted(gaps + [key(c) for c in d["covered_detail"]])
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
kcov "$r"; kchk "K10 a heading that IS an out-of-scope section (EN/ID, numbered, bilingual) still excludes itself + its sub-headings; the next H2 is censused" "$r" $? 1 'remit.prd.md#9-batch-harian'
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
### Ekspor ke Excel
Tidak dibangun ulang — keputusan pengurus.
EOF
tmpl="2-business-rules acceptance-criteria 3-flow 4-data-in-out 5-edge-cases-gotchas 7-run-recovery"
kunit "$r" U-001 $(for s in $tmpl; do echo "$MD/pinjaman.prd.md#$s"; done)
kunit "$r" U-002 $(for s in $tmpl; do echo "$MD/angsuran.prd.md#$s"; done)
kunit "$r" U-003 $(for s in 2-business-rules 3-flow 4-data-in-out 5-edge-cases-gotchas; do echo "$MD/laporan.prd.md#$s"; done)
RA="$(for s in $tmpl purpose-code-validation; do printf 'pinjaman.prd.md#%s ' "$s"; done)$(for s in $tmpl tidak-termasuk-denda-untuk-angsuran-yang-jatuh-tempo-di-hari-libur; do printf 'angsuran.prd.md#%s ' "$s"; done)$(for s in 2-business-rules source-reference-number-format 3-flow 4-data-in-out 5-edge-cases-gotchas; do printf 'laporan.prd.md#%s ' "$s"; done)"
kcov "$r"; kchk "R1 realistic 3-module KB: exactly the 3 extractor-added [LOCKED] H3s with no unit are gaps (meta/ID-meta/fenced banner/Out-of-scope not censused)" "$r" $? 1 \
  'pinjaman.prd.md#purpose-code-validation angsuran.prd.md#tidak-termasuk-denda-untuk-angsuran-yang-jatuh-tempo-di-hari-libur laporan.prd.md#source-reference-number-format' "$RA"
python3 - "$r/.mega-sdd/.plan-coverage-state.json" <<'EOF' && ok "R2 each gap names its own module file in gaps[] and next_action" || bad "R2 gap file naming"
import json, sys
d = json.load(open(sys.argv[1])); M = ".mega-sdd/knowledge-base/modules/"
want = {M + "pinjaman.prd.md#purpose-code-validation", M + "angsuran.prd.md#tidak-termasuk-denda-untuk-angsuran-yang-jatuh-tempo-di-hari-libur", M + "laporan.prd.md#source-reference-number-format"}
assert {"%s#%s" % (g["file"], g["slug"]) for g in d["gaps"]} == want, d["gaps"]
assert all(w in d["next_action"] for w in want), d["next_action"]
EOF
kunit "$r" U-004 "$MD/pinjaman.prd.md#purpose-code-validation"
kunit "$r" U-005 "$MD/angsuran.prd.md:$(( $(grep -n '^### Tidak termasuk denda' "$r/$MD/angsuran.prd.md" | cut -d: -f1) + 1 ))"
echo '{"open_questions":[{"tag":"OQ-LAP-1","text":"laporan.prd.md Source reference number format — apakah REK-<YYYYMM> wajib dipertahankan?","status":"open"}]}' > "$r/.mega-sdd/vaults/k/vault.json"
kcov "$r"; kchk "R3 slug unit + :line unit + module-scoped OQ close the 3 gaps → PASS over the same 19 anchors" "$r" $? 0 '' "$RA"

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
