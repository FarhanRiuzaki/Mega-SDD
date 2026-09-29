#!/usr/bin/env bash
# PRD-mode plan coverage = DECLARED coverage (validate-plan-coverage.sh header; census + ref grammar in
# _lib/prd_headings.py, shared with validate-unit-spec.sh). The gate never guesses what a heading means: every ANCHOR
# (a non-empty H1-H3 that is not a container, an H4-H6 under a container, the text before the first heading) needs a
# decision — a unit prd_source, an OQ carrying [covers: <ref>], or a line in <vault>/context.md
# "## Coverage exclusions" with a real reason. Heuristic classification did not converge, so there is none.
#   A  the contract on an inline PRD: unit / OQ / declaration paths; whole heading, never a substring; the slug form;
#      invalid lines FAIL naming the context.md line; an H2 line covers no H3; containers; stale / redundant notes.
#   R  earlier declared-coverage review findings, one check or more each.
#   N  round-5 findings (F1-F12, H1-H2, M1-M7, L1-L5): the census is CommonMark's, an OQ decides only through
#      [covers:], the per-vault entry is bound to the sources the vault pins, reasons and near misses.
#   P  the per-vault, digest-bound state the execute-bolts preflight and analyze read + unit-spec parity.
#   F  the F-id path: whole id, and only through a ref to the same file.
#   B  fo* fail-open fixtures: each FAILs with no declaration; the gap set is every undecided anchor.
#   C  fc* fail-closed fixtures: FAIL undeclared, PASS with their natural declarations (<fc>.context.md).
#   H  parser guards (CommonMark heading / block rules; forgotten fence / comment closers hide nothing).
# Mutation check: every check marked (RED) fails on the pre-change scripts —
#   PLAN_COVERAGE_SCRIPT=<old gate> UNIT_SPEC_SCRIPT=<old unit-spec> PREFLIGHT_SCRIPT=<old preflight> \
#   ANALYZE_SCRIPT=<old run-analyze> bash <this file>   (each old script next to its own old _lib/)
# Run: bash tests/v9/test-plan-coverage-prd.sh </dev/null
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; SC="$ROOT/plugins/mega-sdd/scripts"
V="${PLAN_COVERAGE_SCRIPT:-$SC/validate-plan-coverage.sh}"; US="${UNIT_SPEC_SCRIPT:-$SC/validate-unit-spec.sh}"
PF="${PREFLIGHT_SCRIPT:-$SC/validate-preflight.sh}"; AN="${ANALYZE_SCRIPT:-$SC/run-analyze.sh}"; FX="$ROOT/tests/v9/fixtures/coverage"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; rc=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; rc=1; }

# pc <label> <fixture> <want exit> '<gaps>' <vault.json|-> <context.md|-> [<unit prd_source>...]
#    <gaps>: 'A|B' = the exact multiset of gap headings; '+A|B' = all of these are gaps; '-A|B' = none of these is
#    one. <fixture> / <vault.json> / <context.md>: a name in $FX or an absolute path. A unit arg 'superseded:<ref>' writes that
#    unit with `status: superseded`. The case state stays in $ST for pj.
n=0; ST=""
pc() {
  local label="$1" fx="$2" want_rc="$3" want="$4" oq="$5" ctx="$6" s k=0; shift 6; n=$((n + 1))
  local W="$T/c$n"; mkdir -p "$W/v/units"; case "$fx" in /*) cp "$fx" "$W/prd.md" ;; *) cp "$FX/$fx" "$W/prd.md" ;; esac
  for s in "$@"; do k=$((k + 1)); local st=""; case "$s" in superseded:*) s="${s#superseded:}"; st='status: superseded\n' ;; esac
    printf -- '---\nunit_id: U-%03d\n%bprd_source: %s\n---\n# U\n' $k "$st" "$s" > "$W/v/units/U-$(printf %03d $k).md"; done
  case "$oq" in -) ;; /*) cp "$oq" "$W/v/vault.json" ;; *) cp "$FX/$oq" "$W/v/vault.json" ;; esac
  case "$ctx" in -) ;; /*) cp "$ctx" "$W/v/context.md" ;; *) cp "$FX/$ctx" "$W/v/context.md" ;; esac
  bash "$V" --cwd="$W" --prd="$W/prd.md" --vault="$W/v" --quiet >/dev/null 2>&1; local r=$?; ST="$W/.mega-sdd/.plan-coverage-state.json"
  python3 - "$ST" "$r" "$want_rc" "$want" <<'EOF' && ok "$label" || bad "$label"
import json, sys
d = json.load(open(sys.argv[1])); r, want_rc, w = int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
got = sorted(g["heading"] for g in d["gaps"]); mode = w[:1] if w[:1] in "+-" and w[1:2] != " " else ""
want = sorted(h for h in (w[1:] if mode else w).split("|") if h)
assert r == want_rc and d["status"] == ("PASS" if want_rc == 0 else "FAIL"), "exit %d status %s (want %d); gaps %s" % (r, d["status"], want_rc, got)
assert (got == want) if not mode else all((h in got) == (mode == "+") for h in want), "gaps %s vs %s%s" % (got, mode, want)
EOF
}
pj() {  # pj <label> '<python bool expr over d = the last case state>'
  python3 - "$ST" "$2" <<'EOF' && ok "$1" || bad "$1"
import json, sys
d = json.load(open(sys.argv[1])); decl = {x["heading"]: x for x in d.get("excluded", []) if x.get("by") == "declared"}
nd = sum(1 for x in d.get("excluded", []) if x.get("by") == "declared")  # identical headings share a key in decl
bad = {g["line"]: g.get("why", "") for g in d["gaps"] if g["heading"].startswith("(invalid coverage exclusion)")}
cov = {c["heading"]: c["covered_by"] for c in d.get("covered_detail", [])}
oqo = {x["heading"]: x for x in d.get("oq_only", [])}; notes = " || ".join(d.get("notes", []))
assert eval(sys.argv[2]), json.dumps({k: d.get(k) for k in ("anchors", "gaps", "excluded", "covered_detail", "oq_only", "notes", "next_action")}, ensure_ascii=False)[:1400]
EOF
}
# ctx < body → a context.md; $OQS (optional) = the `## Open Questions` lines (the section comes last, as plan writes it)
ctx() { printf '# ctx\n\n## Open Questions\n%s\n\n' "${OQS:-- none}"; cat; }
TITLE='- "PRD: Wallet" — document title and intro, no behaviour'
printf '# ctx\n\n## Coverage exclusions\n- "Wallet PRD" — document title and one-line product summary, no behaviour\n' > "$T/wal.ctx"

echo "── A: the declared-coverage contract (inline PRD) ──"
cat > "$T/a.md" <<'P'
# PRD: Wallet
Intro under the title.
## 1. Background
Why we build it.
## 2. Transfers
### 2.1 Limits
Daily limit Rp10.000.000.
### 2.2 Scheduled Transfers
Runs at 06:00 WIB.
## Background Jobs
A nightly job reconciles payments.
## 3. Timeline {#timeline}
Beta in Q3.
## Out of scope
Not in this release:
### Crypto
Not now.
## Out of scope (v2)
Multi-currency.
## Non-Functional Requirements
p95 < 300 ms.
## Open Questions
- OQ-1: retention?
P
ALL="PRD: Wallet|1. Background|2.1 Limits|2.2 Scheduled Transfers|Background Jobs|3. Timeline {#timeline}|Out of scope|Crypto|Out of scope (v2)|Non-Functional Requirements|Open Questions"
pc "A1 no unit, no OQ, no declaration: every anchor is a gap; the body-less '2. Transfers' is a container, its H3s stand in (RED)" "$T/a.md" 1 "$ALL" - -
pj "A1 11 anchors; next_action names the three decisions ([covers:] for an OQ), then one paste-ready line per gap; the container is noted (RED)" \
  'd["anchors"] == 11 and "prd_source" in d["next_action"] and "[covers: <ref>]" in d["next_action"] and "## Coverage exclusions" in d["next_action"] and "- \"Background Jobs\" — <reason>" in d["next_action"].split("\n") and "prd.md#background-jobs" in d["next_action"] and len(d["paste"]) == 11 and all(p in d["next_action"].split("\n") for p in d["paste"]) and "container" in notes and "prd.md#2-transfers" in notes'
OQS='- [ ] **OQ-FL-1** [P1] [business] [covers: prd.md#2-2-scheduled-transfers]: which timezone?
- [ ] **OQ-FL-2** [P1] [business]: "Background Jobs" (PRD §3) — how often?' ctx > "$T/a2q.ctx" <<'C'
## Coverage exclusions
- "1. BACKGROUND" — problem context, no behaviour to build
- 3-timeline — project schedule, not software
- "Out of scope" — the PRD's own exclusion list
- "Crypto" - listed under Out of scope
- "Open Questions": carried into context.md ## Open Questions
- "Background" — names no heading of this PRD
C
pc "A2 a unit, an OQ with [covers:] and declarations decide their anchors; an OQ quoting '\"Background Jobs\"' / '§3' decides nothing; 'Background' is no substring of 'Background Jobs' (RED)" \
  "$T/a.md" 1 "PRD: Wallet|Background Jobs|Out of scope (v2)" - "$T/a2q.ctx" prd.md#2-transfers prd.md#2-1-limits prd.md#non-functional-requirements
pj "A2 declared headings land in excluded[] with their reason and line (case-insensitive quoted text, the slug, '-' and ':' after a quoted key)" \
  'sorted(decl) == sorted(["1. Background", "3. Timeline {#timeline}", "Out of scope", "Crypto", "Open Questions"]) and decl["Crypto"]["reason"] == "listed under Out of scope" and decl["Open Questions"]["reason"] == "carried into context.md ## Open Questions" and decl["1. Background"]["declared_at"].endswith("context.md:8")'
pj "A2 OQ-FL-1 decides '2.2 Scheduled Transfers' and is listed in oq_only[]; the unit citing the container covers nothing (a note); 'Background' is stale (RED)" \
  'cov.get("2.2 Scheduled Transfers") == "open question OQ-FL-1" and oqo["2.2 Scheduled Transfers"]["oq"] == "OQ-FL-1" and "U-001.md → prd.md#2-transfers" in notes and "context.md:13 Background" in notes and "only an open question" in d["next_action"]'
ctx > "$T/a3.ctx" <<C
## Coverage exclusions
- "1. Background" — problem context, no behaviour to build
- "3. Timeline" — project schedule, not software
- "Out of scope" — the PRD's own exclusion list
- "Crypto" — listed under Out of scope
- "Out of scope (v2)" — excluded until v2
- "Open Questions" — carried into context.md ## Open Questions
$TITLE
C
A3U="prd.md#2-1-limits prd.md#2-2-scheduled-transfers prd.md#background-jobs prd.md#non-functional-requirements"
# shellcheck disable=SC2086
pc "A3 every anchor decided → PASS (the '{#id}' of '3. Timeline {#timeline}' is not part of its text)" "$T/a.md" 0 "" - "$T/a3.ctx" $A3U
pj "A3 anchors 11 = 4 covered by a unit + 7 declared; next_action and summary say so (RED)" \
  'd["anchors"] == 11 and d["covered"] == 4 and len(decl) == 7 and "4 covered by a unit, 0 by an open question, 7 declared" in d["next_action"] and d["summary"]["declared"] == 7 and d["summary"]["gaps"] == 0 and d["summary"]["oq_only"] == 0'
grep -v '"Crypto"' "$T/a3.ctx" > "$T/a4.ctx"
# shellcheck disable=SC2086
pc "A4 declaring an H2 does not cover its H3: '## Out of scope' (it has text) declared, '### Crypto' under it is still a gap" "$T/a.md" 1 "Crypto" - "$T/a4.ctx" $A3U
ctx > "$T/a5.ctx" <<C
## Coverage exclusions
- "1. Background" — problem context, no behaviour to build
- "3. Timeline" — TBD
- "Out of scope" — n/a
- "Crypto" — -
- "Out of scope (v2)" — <reason>
- "Open Questions" —
- Background Jobs — unquoted words are no heading
$TITLE
C
pc "A5 an empty or placeholder reason (TBD, n/a, -, <reason>, nothing) and an unparseable item FAIL, and their headings stay gaps" "$T/a.md" 1 \
  "3. Timeline {#timeline}|Out of scope|Crypto|Out of scope (v2)|Open Questions|Background Jobs|(invalid coverage exclusion) - \"3. Timeline\" — TBD|(invalid coverage exclusion) - \"Out of scope\" — n/a|(invalid coverage exclusion) - \"Crypto\" — -|(invalid coverage exclusion) - \"Out of scope (v2)\" — <reason>|(invalid coverage exclusion) - \"Open Questions\" —|(invalid coverage exclusion) - Background Jobs — unquoted words are no heading" \
  - "$T/a5.ctx" prd.md#2-1-limits prd.md#2-2-scheduled-transfers prd.md#non-functional-requirements
pj "A5 each invalid line is named by its context.md line and why; next_action lists them" \
  'set(bad) == {8, 9, 10, 11, 12, 13} and all(bad[x].startswith("empty or placeholder reason") for x in range(8, 13)) and bad[13].startswith("not a declaration") and "6 invalid coverage exclusion line(s)" in d["next_action"] and "context.md:8 empty or placeholder reason" in d["next_action"]'
cat > "$T/a6.ctx" <<C
# ctx

## Constraints
- "Out of scope" — a list item outside the section declares nothing

## Coverage exclusions
- "1. Background" — problem context, no behaviour to build
$TITLE
<!--
- "Crypto" — commented out
-->
\`\`\`md
- "Open Questions" — an example inside a fence
\`\`\`
### Notes
- "3. Timeline" — an H3 inside the section keeps the section open

## Later section
- "Non-Functional Requirements" — the section ended at the next H2
C
pc "A6 a line outside the section, inside an HTML comment or a fence declares nothing (an H3 does not end the section)" "$T/a.md" 1 \
  "Out of scope|Crypto|Out of scope (v2)|Non-Functional Requirements|Open Questions" - "$T/a6.ctx" \
  prd.md#2-1-limits prd.md#2-2-scheduled-transfers prd.md#background-jobs
ctx > "$T/a7.ctx" <<C
## Coverage exclusions
- prd.md#"1. Background" — problem context, no behaviour to build
- timeline — project schedule ({#id} slug)
- prd.md#out-of-scope — the PRD's own exclusion list
- other-prd.md#"Crypto" — another PRD's heading
- scheduled-transfers — no heading has this slug (it is 2-2-scheduled-transfers)
- "Out of scope (v2)" — excluded until v2
- "Open Questions" — carried into context.md ## Open Questions
- "2.1 Limits" — also owned by a unit
$TITLE
C
# shellcheck disable=SC2086
pc "A7 a file-qualified line must name the PRD file; the slug form matches the whole slug or the {#id}, never a part" "$T/a.md" 1 "Crypto" - "$T/a7.ctx" $A3U
pj "A7 stale lines (other file, partial slug) and the redundant declaration of a unit-covered heading are notes" \
  'any("stale" in x and "context.md:10 Crypto" in x and "context.md:11 scheduled-transfers" in x for x in d["notes"]) and any("redundant" in x and "prd.md#2-1-limits" in x for x in d["notes"])'
printf 'Intro, no heading at all.\n**Scheduled transfers**\nAt 06:00.\n' > "$T/zero.md"
ctx > "$T/zero.ctx" <<'C'
## Coverage exclusions
- "Scheduled transfers" — a bold line is no heading
C
pc "A8 a heading-less PRD is ONE anchor, '(text before the first heading)' — a bold line is no heading (RED)" "$T/zero.md" 1 "(text before the first heading)" - "$T/zero.ctx"
pj "A8 ... its paste line is the quoted anchor name, its ref a :line (RED)" \
  'd["anchors"] == 1 and "- \"(text before the first heading)\" — <reason>" in d["paste"] and "prd.md:1" in d["next_action"]'
pc "A8 ... a unit citing a line of it decides it → PASS (RED)" "$T/zero.md" 0 "" - - prd.md:2
printf -- '---\ntitle: Wallet\n---\n\n<!-- nothing yet -->\n' > "$T/zero3.md"
pc "A8 zero anchors (frontmatter + a comment, no text) = FAIL, never a PASS" "$T/zero3.md" 1 "(no requirement headings found)" - -
pj "A8 ... next_action says the structure was not readable" 'd["anchors"] == 0 and "no heading" in d["next_action"]'

echo "── R: earlier declared-coverage review findings ──"
# F1 + F12 — only an OQ still waiting for (or holding) a human scope decision covers; a resolved one covers nothing
printf '# PRD: Wallet\n\n## Top-up\nTop up from a bank account.\n\n## Refunds\nA refund above Rp1.000.000 needs an approval.\n' > "$T/r1.md"
echo '{"open_questions":[{"tag":"OQ-FL-1","status":"resolved","text":"Which approval chain applies above Rp1.000.000? [covers: prd.md#refunds] → Resolved: supervisor only."}]}' > "$T/r1.json"
pc "F1 a resolved OQ (vault.json, no context.md) carrying [covers: prd.md#refunds] covers nothing" "$T/r1.md" 1 "Refunds" "$T/r1.json" - prd.md#top-up
OQS='- [x] **OQ-FL-1** [P1] [business] [covers: prd.md#refunds]: above Rp1.000.000 — which approval chain? → **Resolved v1.1** (plan, 2026-09-27): supervisor only' \
  ctx > "$T/r1b.ctx" < /dev/null
pc "F1 ... nor does a context.md [x] OQ answered at the Step-6 ask" "$T/r1.md" 1 "Refunds" - "$T/r1b.ctx" prd.md#top-up
pj "F1 ... and the notes say the resolved OQ decides nothing (RED)" '"OQ-FL-1 is resolved" in notes'
for st in '[ ] **OQ-FL-1** [P1] [business] [covers: prd.md#refunds]: above Rp1.000.000 — which approval chain?' \
          '[ ] **OQ-FL-1** [P2] [business] [covers: prd.md#refunds]: above Rp1.000.000 — which approval chain? **Deferred (plan)**: after launch' \
          '[~] **OQ-FL-1** [P1] [business] [covers: prd.md#refunds]: above Rp1.000.000 — which approval chain? → Out of Scope v1.1: no refunds in v1'; do
  OQS="- $st" ctx > "$T/r1c.ctx" < /dev/null
  case "$st" in *Deferred*) k=deferred ;; *~*) k=out-of-scope ;; *) k=open ;; esac
  pc "F1/F12 an $k OQ in context.md carrying [covers: prd.md#refunds] decides 'Refunds' (RED)" "$T/r1.md" 0 "" - "$T/r1c.ctx" prd.md#top-up
done
pj "F12 ... covered_by names the OQ; oq_only[] carries its status (RED)" 'cov.get("Refunds") == "open question OQ-FL-1" and oqo["Refunds"]["oq_status"] == "out_of_scope"'
# F2 / H3 — an OQ decides an anchor only through [covers:]; a word, a quote, a §, an [origin:] or a bare ref decides nothing
printf '# PRD: Wallet\n\n## Top-up\nTop up.\n\n## Refunds\nRefund in 7 days.\n\n## Notifications\nPush and email receipts.\n\n## Admin\nFreeze a wallet, export CSV.\n' > "$T/r2.md"
echo '{"open_questions":[{"tag":"OQ-X-1","status":"open","text":"Should the admin see top-up notifications for frozen wallets?"}]}' > "$T/r2.json"
pc "F2 an OQ mentioning 'admin' and 'notifications' covers neither section" "$T/r2.md" 1 "Refunds|Notifications|Admin" "$T/r2.json" - prd.md#top-up
printf '# PRD: Wallet\n\n## 1. Top-up\nTop up.\n\n## 2. Refunds\nRefund in 7 days.\n\n## 3. Notifications\nReceipts.\n\n### 3.1 Push\nPush on debit.\n\n## 4. Admin\nFreeze.\n' > "$T/r2c.md"
OQS='- [ ] **OQ-X-1** [P1] [business] [origin: prd.md#2-refunds]: who approves large refunds?
- [ ] **OQ-X-2** [P1] [business]: PRD §3.1 — which push provider is allowed?
- [ ] **OQ-X-3** [P2] [business]: does “1. Top-up” allow a credit card?
- [ ] **OQ-X-4** [P2] [business]: can prd.md:16 freeze be undone by the user? See prd.md#4-admin.
- [ ] **OQ-X-5** [P1] [business] [covers: prd.md#3-notifications, prd.md:13]: are notifications in v1 at all?' ctx > "$T/r2c.ctx" < /dev/null
pc "F2/H1 [origin: <ref>], §<number>, the whole heading in “…”, a bare <file>:<line> / <file>#<slug> decide nothing; [covers: <ref>, <file>:<line>] decides each ref (RED)" \
  "$T/r2c.md" 1 "1. Top-up|2. Refunds|4. Admin" - "$T/r2c.ctx"
pj "F2/H1 ... both covered anchors are listed in oq_only[] and next_action (RED)" \
  'sorted(oqo) == ["3. Notifications", "3.1 Push"] and "2 heading(s) have no unit, only an open question" in d["next_action"] and "3.1 Push ← OQ-X-5 (open)" in d["next_action"]'
# F3 / H1 — unique slugs (x, x-1 …): a ref, a declaration or an OQ names ONE heading
pc "F3 '#business-rules' names the FIRST 'Business rules' only: Transfer's daily-limit H3 is a gap" fo51-duplicate-h3-names.md 1 "Business rules" - - \
  prd.md#top-up prd.md#business-rules prd.md#transfer
pj "F3 ... the gap is the second one (L12, slug business-rules-1) and its paste line uses the unique slug" \
  '[(g["line"], g["slug"]) for g in d["gaps"]] == [(12, "business-rules-1")] and "- business-rules-1 — <reason>" in d["next_action"].split("\n")'
pc "F3 '#business-rules-1' covers the second (GitHub anchor order)" fo51-duplicate-h3-names.md 0 "" - - prd.md#top-up prd.md#business-rules prd.md#transfer prd.md#business-rules-1
ctx > "$T/r3.ctx" <<'C'
## Coverage exclusions
- "Business rules" — covered by the implementation notes
C
pc "F3 a quoted declaration of a name two headings share is INVALID (ambiguous), and both stay gaps" fo51-duplicate-h3-names.md 1 \
  "Business rules|Business rules|(invalid coverage exclusion) - \"Business rules\" — covered by the implementation notes" - "$T/r3.ctx" prd.md#top-up prd.md#transfer
pj "F3 ... the invalid row names both unique refs" 'bad[7].startswith("ambiguous: 2 headings") and "prd.md#business-rules, prd.md#business-rules-1" in bad[7]'
cat > "$T/r3b.md" <<'P'
# Timesheets and payslips

# Module A — Timesheets

## Functional requirements
Staff log hours per day.

## Acceptance criteria
A day over 12 hours is rejected.

# Module B — Payslips

## Functional requirements
Payslips MUST be encrypted with the employee's NIK.

## Acceptance criteria
A payslip opens only with the NIK.
P
pc "H1 a unit citing Module A's '#functional-requirements' / '#acceptance-criteria' leaves Module B's same-named sections undecided; the title (no text, no sub-heading of its own) is an anchor (RED)" "$T/r3b.md" 1 \
  "Timesheets and payslips|Functional requirements|Acceptance criteria" - - prd.md#functional-requirements prd.md#acceptance-criteria
pj "H1 ... the gaps are the title and Module B's (L1, L13, L16)" 'sorted(g["line"] for g in d["gaps"]) == [1, 13, 16]'
printf '# PRD\n\n## Refunds {#rf}\nWithin 7 days.\n\n## Refund fees {#rf}\nRp2.500.\n' > "$T/r3c.md"
pc "H1 a ref whose explicit id names two headings covers neither: an '(ambiguous prd_source)' FAIL row" "$T/r3c.md" 1 \
  "Refunds {#rf}|Refund fees {#rf}|(ambiguous prd_source) prd.md#rf" - - prd.md#rf
# F4 / H2 — an H1 with text of its own is an anchor (the title too); an H1 that only groups its children is not
pc "F4 '# §5. Global Business Rules' (BR-001/002, no H2 child) and the title with its intro are gaps; the container '# §6' / '# §Clinic' are not anchors" \
  fo50-h1-sections.md 1 "PRD: Clinic booking|§5. Global Business Rules" - - prd.md#6-1-compliance prd.md#clinic-1-booking-flow
printf '# Wallet PRD\n\n# Top-up\nTop up from a bank account.\n\n# Refunds\nRefund within 7 days.\n' > "$T/r4.md"
printf '# ctx\n\n## Coverage exclusions\n- "Wallet PRD" — the document title\n' > "$T/r4.ctx"
pc "F4 a Heading-1-only PRD (Google Docs style) reaches PASS through its units; its body-less title (no sub-heading) is declared" "$T/r4.md" 0 "" - "$T/r4.ctx" prd.md#top-up prd.md#refunds
printf '# Contact page\n\nA form: name, email and message; a message is emailed to the office.\n' > "$T/r4b.md"
pc "F4 a title-only PRD: the title is its one anchor, a unit citing :3 decides it" "$T/r4b.md" 0 "" - - prd.md:3
# F5 / F6 / M5 — heading shapes CommonMark renders (commonmark.js 0.31.2 reference) are censused
while IFS='|' read -r fx g; do
  pc "F5/F6 ${fx%%-*}: ${fx#*-} — '$g' is censused" "$fx" 1 "$g" - - prd.md#top-up prd.md#glossary
done <<'L'
fo42-setext-after-inline-html.md|Refunds
fo43-setext-in-blockquote.md|Chargebacks
fo44-setext-in-list-item.md|Freeze
fo45-html-heading-in-div.md|Export
fo46-html-heading-after-anchor.md|KYC
fo47-emphasis-and-metaline-setext.md|**Transfer limits**|Status: Chargeback handling
fo48-fence-marker-in-html-pre.md|Refunds|Chargebacks
fo49-unicode-line-separators.md|Refunds|Chargebacks
L
pj "F6 lines split on \\n only (U+2028 / \\f are text): 'Refunds' is L8, as CommonMark numbers it" '[g["line"] for g in d["gaps"] if g["heading"] == "Refunds"] == [8]'
pc "M5 'Status: …' / 'Approved by …' setext headings after the first H2 are censused" fo52-metaline-setext-after-h2.md 1 \
  "Status: order lifecycle rules|Approved by finance: refund rules" - - prd.md#checkout
# F7 — a ref / declaration file is resolved against --cwd (./ ../ normalised), never by suffix
pc "F7 'features/loans/prd.md#refunds' names another PRD: the root PRD's Refunds stays a gap" "$T/r1.md" 1 "Refunds" - - prd.md#top-up features/loans/prd.md#refunds
pc "F7 ... so does an archived copy 'docs/archive/v1/prd.md#refunds'" "$T/r1.md" 1 "Refunds" - - prd.md#top-up docs/archive/v1/prd.md#refunds
pj "F7 ... and the notes name the refs whose file is no source of this run (RED)" '"U-002.md → docs/archive/v1/prd.md#refunds" in notes and "no source of this run" in notes'
ctx > "$T/r7.ctx" <<'C'
## Coverage exclusions
- features/loans/prd.md#"Refunds" — another document's section
C
pc "F7 ... and a declaration qualified with another file declares nothing here (a stale note)" "$T/r1.md" 1 "Refunds" - "$T/r7.ctx" prd.md#top-up
pc "F7 ... while './prd.md#refunds' is this PRD" "$T/r1.md" 0 "" - - prd.md#top-up ./prd.md#refunds
# F10 — the unquoted form is a literal slug; '- Note: …' is prose, never a declaration
printf '# PRD: Wallet\n\n## Top-up\nTop up.\n\n## Scope\nTransfers MUST be limited to Rp5.000.000 a day.\n\n## Note\nEvery ledger entry MUST be immutable.\n' > "$T/r10.md"
ctx > "$T/r10.ctx" <<'C'
## Coverage exclusions
- Note: every line below was checked against the PRD by the planner.
- Scope: out-of-scope items are listed in ## Constraints.
C
pc "F10 '- Note: …' / '- Scope: …' explanatory bullets are INVALID rows naming their line, never declarations" "$T/r10.md" 1 \
  "Scope|Note|(invalid coverage exclusion) - Note: every line below was checked against the PRD by the planner.|(invalid coverage exclusion) - Scope: out-of-scope items are listed in ## Constraints." \
  - "$T/r10.ctx" prd.md#top-up
pj "F10 ... at context.md:7 and :8" 'sorted(bad) == [7, 8]'
ctx > "$T/r10b.ctx" <<'C'
## Coverage exclusions
- note — a reviewer note for the PRD authors, no behaviour
- "Scope": the scope statement; its limit is unit U-009's Hard rule
C
pc "F10 ... a literal slug with — and a quoted key with ':' still declare" "$T/r10.md" 0 "" - "$T/r10b.ctx" prd.md#top-up
# F11 — the paste-ready lines parse back to their heading (curly quotes, backticks, separators inside)
printf '# PRD\n\n## Top-up\nTop up.\n\n## `POST /transfers` — create a transfer\nIdempotent on the key.\n\n## Fitur “Bayar Nanti” — cicilan\nThree instalments.\n\n## Pay "now" — later\nDeferred charge.\n' > "$T/r11.md"
mkdir -p "$T/r11"; cp "$T/r11.md" "$T/r11/prd.md"; mkdir -p "$T/r11/v/units"
printf -- '---\nunit_id: U-001\nprd_source: prd.md#top-up\n---\n' > "$T/r11/v/units/U-001.md"
bash "$V" --cwd="$T/r11" --prd="$T/r11/prd.md" --vault="$T/r11/v" --quiet >/dev/null 2>&1
python3 - "$T/r11/.mega-sdd/.plan-coverage-state.json" "$T/r11/v/context.md" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1])); lines = [x for x in d["next_action"].split("\n") if x.startswith("- ") and x.endswith("<reason>")]
open(sys.argv[2], "w").write("# ctx\n\n## Coverage exclusions\n" + "".join(x.replace("<reason>", "an HTTP contract section — unit U-007 owns it") + "\n" for x in lines))
EOF
pc "F11 pasting next_action's lines (reasons filled in) decides every gap it listed" "$T/r11.md" 0 "" - "$T/r11/v/context.md" prd.md#top-up
# F13 / M1 — placeholder reasons; declarations hidden in <style> / <script> / <template>
printf '# PRD\n\n## A\na\n\n## B\nb\n\n## C\nc\n\n## D\nd\n\n## E\ne\n\n## F\nf\n\n## G\ng\n\n## H\nh\n\n## I\ni\n' > "$T/r13.md"
ctx > "$T/r13.ctx" <<'C'
## Coverage exclusions
- "A" — (TBD)
- "B" — [TBD]
- "C" — TBD — confirm with PO
- "D" — todo: isi alasan
- "E" — TBD by the PO
- "F" — belum ada
- "G" — kept as <reason> for now
<style>
- "H" — handled by the partner bank
</style>
- "I" — the partner bank runs this flow; nothing to build
C
pc "F13/M1 (TBD), [TBD], 'TBD — …', 'todo: …', 'TBD by the PO', 'belum ada', a reason holding <reason> are INVALID; a line inside <style> declares nothing" "$T/r13.md" 1 \
  "+A|B|C|D|E|F|G|H" - "$T/r13.ctx"
pj "F13/M1 ... seven invalid rows; only 'I' is declared" 'sorted(bad) == [7, 8, 9, 10, 11, 12, 13] and sorted(decl) == ["I"]'
# F14 — a near-miss section heading is a note; an ordered item is an invalid row
printf '# ctx\n\n## Coverage Exclusions:\n- "A" — reference list\n\n## Coverage exclusions\n1. "B" — document history\n- "C" — changelog, nothing to build\n' > "$T/r14.ctx"
pc "F14 '## Coverage Exclusions:' is not read but noted; '1. \"B\" — …' is an invalid row ('use a - bullet')" "$T/r13.md" 1 "+A|B" - "$T/r14.ctx"
pj "F14 ... the note names the near-miss line, the row names line 7" \
  'any("near-miss" in x and "context.md:3" in x for x in d["notes"]) and bad.get(7, "").startswith("an ordered item") and "C" in decl'
# M2 — the paste lines are one per line; the old ' | '-joined line pasted whole is invalid (it still holds <reason>)
printf '# ctx\n\n## Coverage exclusions\n- "A" — <reason> | - "B" — <reason> | - "C" — <reason>\n' > "$T/m2.ctx"
pc "M2 a pasted line that still holds <reason> is INVALID" "$T/r13.md" 1 "+A|B|C" - "$T/m2.ctx"
pj "M2 ... named at context.md:4" 'bad.get(4, "").startswith("empty or placeholder reason") and not decl'
# M6 — the key is the heading as written: case, curly quotes, dashes, emphasis / code markers, emoji, a trailing ?/: fold
printf '# PRD\n\n## **Background**\nx\n\n## Scope — v1 (draft)\nx\n\n## What’s next\nx\n\n## Tabel `contact_messages`\nx\n\n## 🚀 Launch plan\nx\n\n## FAQ?\nx\n\n## 2) Goals:\nx\n' > "$T/m6.md"
ctx > "$T/m6.ctx" <<'C'
## Coverage exclusions
- "Background" — context only
- "Scope - v1 (draft)" — scope statement, no behaviour
- "What's next" — roadmap
- **"Tabel contact_messages"** — schema listing, the DBML in context.md is the source
- "Launch plan" — go-live checklist, not software
- 'FAQ' — support copy
- "2) Goals" — goals, measured outside the product
A plain sentence in the section is noted, not read.
C
pc "M6 each heading is decided through the folded whole-heading key (never a substring)" "$T/m6.md" 0 "" - "$T/m6.ctx"
pj "M6 ... and the non-list line is a note" 'len(decl) == 7 and any("not \x27- \x27 declarations" in x and "context.md:14" in x for x in d["notes"])'
# M7 — an empty ATX heading is skipped (CommonMark renders it empty) and noted, never a gap no line can close
printf '# PRD\n\n## Kontak\nForm.\n\n##\n\nText.\n' > "$T/m7.md"
pc "M7 a stray '##' is no gap; the note names it" "$T/m7.md" 0 "" - - prd.md#kontak
pj "M7 ... noted at prd.md:6" 'any("empty heading" in x and "prd.md:6" in x for x in d["notes"])'
pj "L3 the state carries summary {gaps, anchors, covered, declared, invalid, oq_only} for the analyze row (RED)" \
  'd["summary"] == {"gaps": 0, "anchors": 1, "covered": 1, "declared": 0, "invalid": 0, "oq_only": 0}'

echo "── N: round-5 findings ──"
# F1 — '<!-->' / '<!--->' close on their own line (CommonMark checks the end condition on the start line)
for fx in fo53-empty-comment-in-list-item.md fo54-empty-comment-top-level.md fo64-empty-comment-in-blockquote.md fo65-empty-comment-dashes-top-level.md; do
  g=Refunds; case "$fx" in fo65*) g=Chargebacks ;; esac
  pc "F1 ${fx%%-*}: ${fx#*-} — '$g' after the self-closing comment is censused (RED)" "$fx" 1 "$g" - "$T/wal.ctx" prd.md#1-top-up prd.md#2-reports
done
printf '# ctx\n\n## Coverage exclusions\n<!-->\n- "Refunds" — the partner bank refunds; nothing to build here\n' > "$T/n1.ctx"
pc "F1 ... and context.md reads '<!-->' the same way: the declaration after it is read (RED)" "$T/r1.md" 0 "" - "$T/n1.ctx" prd.md#top-up
# F2 — no metadata-name skip: a setext heading is a heading whatever its words; frontmatter = exact YAML at the file top
while IFS='|' read -r fx g; do
  pc "F2 ${fx%%-*}: ${fx#*-} — '$g' is censused (RED)" "$fx" 1 "$g" - "$T/wal.ctx" prd.md#1-top-up prd.md#2-reports
done <<'L'
fo55-banner-word-setext.md|Confidential data handling
fo56-setext-under-part-h1.md|Changes in v2.1
fo57-bold-label-setext-before-h2.md|**Scope:** card refunds
L
pc "F2 fo58: a leading '---' block holding '# Wallet PRD' is not frontmatter — the H1 and its list are censused (RED)" fo58-frontmatter-holding-a-heading.md 1 "Wallet PRD" - - prd.md#1-background prd.md#2-reports
printf '# Payments PRD\n---\nscope: card payments must be 3-D Secure verified before capture\nrefund_rule: refunds must be issued within 7 days\n---\n\n## Checkout\n\nCard checkout page.\n' > "$T/n2.md"
pc "F2/L3 a YAML-like block under the title is a thematic break + a setext H2 (CommonMark), censused like any heading (RED)" "$T/n2.md" 1 \
  "scope: card payments must be 3-D Secure verified before capture refund_rule: refunds must be issued within 7 days" - - prd.md#checkout
U2="$T/us2"; mkdir -p "$U2/.mega-sdd/vaults/p/units"; cp "$FX/fo55-banner-word-setext.md" "$U2/prd.md"; k=0
for r in confidential-data-handling 1-top-up 2-reports; do k=$((k + 1))
  printf -- '---\nunit_id: U-%03d\ntitle: t\ntask_type: create\ncontext_source: context.md#flows\nprd_source: prd.md#%s\ntarget_files:\n  - path: src/a%d.ts\n    operation: create\nacceptance_test:\n  - type: test\n    command: npm test\n    expects: "ok"\n---\n# U\n' $k "$r" $k > "$U2/.mega-sdd/vaults/p/units/U-00$k.md"; done
printf '# ctx\n\n## Open Questions\n- none\n' > "$U2/.mega-sdd/vaults/p/context.md"
bash "$US" --cwd="$U2" --quiet >/dev/null 2>&1
python3 -c "import json,sys; d=json.load(open('$U2/.mega-sdd/.unit-spec-state.json')); sys.exit(1 if [i for i in d.get('issues', []) if i.get('halt_type') == 'prd_source_unresolvable'] else 0)" \
  && ok "F2 ... and the unit that cites it resolves in validate-unit-spec.sh (RED)" || bad "F2 unit-spec rejects the censused heading"
bash "$V" --cwd="$U2" --prd="$U2/prd.md" --vault="$U2/.mega-sdd/vaults/p" --quiet >/dev/null 2>&1 \
  && ok "F2 ... and the gate PASSes on it (the title is a container)" || bad "F2 gate on fo55 with its unit"
# F3 / H1 — an OQ decides nothing by § / quote / label; [covers:] is the only route and is listed in oq_only[]
printf '# Wallet PRD\nWallet lets customers top up and pay merchants.\n\n## 1. Top-up\nCustomers top up from a virtual account.\n\n## 4. Data retention\nTransaction data is kept for 10 years, then anonymised; KTP images are deleted after 5 years.\n\n## 5. Reports\nDaily settlement report at 06:00.\n' > "$T/n3.md"
OQS='- [ ] **OQ-1** [P2] [business] Does the OTP flow need the consent wording from UU PDP §4 on the top-up screen?' ctx > "$T/n3.ctx" <<'C'
## Coverage exclusions
- "Wallet PRD" — document title and one-line product summary, no behaviour
C
pc "F3 '§4' of a law cited by an OQ decides nothing in this PRD (RED)" "$T/n3.md" 1 "4. Data retention" - "$T/n3.ctx" prd.md#1-top-up prd.md#5-reports
printf '# Mini App\n\n## Login\nEmail + OTP; 3 wrong OTPs lock the account for 15 minutes.\n\n## Dashboard\nLast 30 days of transactions, CSV export.\n\n## Settings\nDisplay name and notification preferences.\n' > "$T/n3b.md"
OQS='- [ ] **OQ-FL-1** [P2] [business]: should the "Login" button be disabled until the OTP has 6 digits?
- [ ] **OQ-FL-2** [P2] [business]: the CSV export on the "Dashboard" — which columns?' ctx > "$T/n3b.ctx" < /dev/null
pc "H1 OQs quoting UI labels equal to headings ('\"Login\"', '\"Dashboard\"') decide nothing (RED)" "$T/n3b.md" 1 "Login|Dashboard" - "$T/n3b.ctx" prd.md#settings
OQS='- [ ] **OQ-FL-1** [P1] [business] [covers: prd.md#dashboard]: is the dashboard in v1 at all?
- [ ] **OQ-FL-2** [P2] [business] [covers: prd.md#nothing-here]: a ref no anchor has' ctx > "$T/n3c.ctx" < /dev/null
pc "H1 ... [covers: prd.md#dashboard] decides the dashboard; a [covers:] naming no anchor decides nothing (RED)" "$T/n3b.md" 1 "Login" - "$T/n3c.ctx" prd.md#settings
pj "H1 ... oq_only[] and next_action name the dashboard; the dead ref is a note (RED)" \
  'list(oqo) == ["Dashboard"] and "Dashboard ← OQ-FL-1 (open)" in d["next_action"] and "OQ-FL-2 [covers: prd.md#nothing-here] names no anchor" in notes'
# F5 / H2 — the gate reads markdown only; a heading-less .md is one anchor (A8)
mkdir -p "$T/n5/v"; printf '1. Goals\nLeave requests.\n' > "$T/n5/PRD.txt"; printf '%%PDF-1.4 binary\n' > "$T/n5/PRD.pdf"; printf 'x' > "$T/n5/PRD.docx"
for f in PRD.txt PRD.pdf PRD.docx; do
  out="$(bash "$V" --cwd="$T/n5" --prd="$T/n5/$f" --vault="$T/n5/v" --quiet 2>&1 >/dev/null)"; r=$?
  [ $r -eq 2 ] && printf '%s' "$out" | grep -q "not markdown" && ok "F5/H2 --prd=$f → exit 2 'not markdown: write its .md rendition first' (RED)" || bad "F5/H2 $f: rc=$r $out"
done
# F6 — an OQ decides only when a reader sees it and it still waits: not in a comment / fence, not answered, [~] with a reason
for c in 'comment|<!-- dropped after the PO call:
- [ ] **OQ-1** [P1] [business] [covers: prd.md#refunds]: who approves "Refunds" above Rp5jt?
-->' \
         'fence|```
- [ ] **OQ-1** [P1] [business] [covers: prd.md#refunds]: who approves "Refunds" above Rp5jt?
```' \
         'tilde-no-reason|- [~] **OQ-1** [P1] [business] [covers: prd.md#refunds]: "Refunds"' \
         'open-but-answered|- [ ] **OQ-1** [P1] [business] [covers: prd.md#refunds]: are "Refunds" in v1? → **Resolved v1.1** (plan, 2026-09-28): yes, with a 7-day window.'; do
  OQS="${c#*|}" ctx > "$T/n6.ctx" < /dev/null
  pc "F6 an OQ with [covers: prd.md#refunds] ($(printf '%s' "${c%%|*}")) decides nothing (RED)" "$T/r1.md" 1 "Refunds" - "$T/n6.ctx" prd.md#top-up
done
pj "F6 ... the open-but-answered one is named in the notes (RED)" '"OQ-1 carries → Resolved but its box is not [x]" in notes'
# F7 — a quoted name that another anchor bears after a section number is ambiguous
printf '# Clinic PRD\nClinic booking.\n\n## 1. Users\nPatients and receptionists.\n\n## 2. Booking\nA patient books a slot.\n\n## 3. Data model\n### Users\nStores NIK (16 digits, unique); NIK is masked in every screen.\n### Appointments\nOne per slot.\n' > "$T/n7.md"
printf '# ctx\n\n## Coverage exclusions\n- "Clinic PRD" — the title\n- "Users" — persona list, no behaviour of its own\n' > "$T/n7.ctx"
pc "F7 '\"Users\"' with '## 1. Users' and '### Users' present is INVALID (ambiguous) — both stay gaps (RED)" "$T/n7.md" 1 \
  "1. Users|Users|(invalid coverage exclusion) - \"Users\" — persona list, no behaviour of its own" - "$T/n7.ctx" prd.md#2-booking prd.md#appointments
pj "F7 ... the row prints both unique refs (RED)" 'bad[5].startswith("ambiguous: 2 headings named Users") and "prd.md#users" in bad[5] and "prd.md#1-users" in bad[5]'
printf '# ctx\n\n## Coverage exclusions\n- "Clinic PRD" — the title\n- 1-users — persona list, no behaviour of its own\n- "Booking" — a name no anchor carries without its number\n' > "$T/n7b.ctx"
pc "F7 ... the slug decides '1. Users' only: the data-model 'Users' stays a gap (RED)" "$T/n7.md" 1 "Users" - "$T/n7b.ctx" prd.md#2-booking prd.md#appointments
pj "F7 ... a quoted name that matches only a numbered heading is stale with a hint (RED)" '"context.md:6 Booking (did you mean \"2. Booking\"?)" in notes'
# F8 — a pending business decision is an OQ, never an exclusion
printf '# PRD\n\n## Refunds\nx\n\n## Cashback\nx\n\n## Limits\nx\n\n## Disputes\nx\n\n## Loyalty\nx\n\n## Fees\nx\n' > "$T/n8.md"
ctx > "$T/n8.ctx" <<'C'
## Coverage exclusions
- "Refunds" — awaiting PO decision on the refund window
- "Cashback" — menunggu konfirmasi bisnis
- "Limits" — to be confirmed with the business
- "Disputes" — belum diputuskan
- "Loyalty" — unclear, ask PO
- "Fees" — the partner bank sets and charges them; nothing to build
C
pc "F8 'awaiting …', 'menunggu …', 'to be confirmed …', 'belum diputuskan', 'unclear, ask PO' are INVALID; a real reason is not (RED)" "$T/n8.md" 1 "+Refunds|Cashback|Limits|Disputes|Loyalty" - "$T/n8.ctx"
pj "F8 ... five rows say a pending decision is a [business] OQ (RED)" \
  'sorted(bad) == [7, 8, 9, 10, 11] and all("pending decision" in bad[x] and "[covers:" in bad[x] for x in bad) and sorted(decl) == ["Fees"]'
# F9 — CommonMark block rules: an HTML block start interrupts a lazy paragraph, <hN attributes wrap, '##Name' and
#      indented code keep the paragraph state CommonMark has, and a raw-HTML line is read with its markers stripped
while IFS='|' read -r fx g units; do
  # shellcheck disable=SC2086
  pc "F9 ${fx%%-*}: ${fx#*-} — '$g' is censused (RED)" "$fx" 1 "$g" - "$T/wal.ctx" prd.md#1-top-up $units
done <<'L'
fo59-div-interrupts-list-paragraph.md|Refunds|prd.md#2-reports
fo60-wrapped-html-h2.md|Refunds|prd.md#2-reports
fo62-nospace-atx-then-type7-tag.md|Refunds|prd.md#note prd.md#2-reports
fo63-indented-code-then-item.md|Refunds|prd.md#3-reports
L
# F10 — a body-less heading with sub-headings is a container: its H4 sub-sections are censused in its place
pc "F10 fo61: '#### 3.2 Refunds' / '#### 3.3 Cashback' under the body-less '## 3. Features' are anchors; a ref to 3.1 decides 3.1 only (RED)" \
  fo61-h4-sections-under-container.md 1 "3.2 Refunds|3.3 Cashback" - "$T/wal.ctx" prd.md#3-1-top-up
pc "F10 ... citing the container decides none of them (RED)" fo61-h4-sections-under-container.md 1 "3.1 Top-up|3.2 Refunds|3.3 Cashback" - "$T/wal.ctx" prd.md#3-features
pj "F10 ... the notes say it names no anchor (RED)" '"U-001.md → prd.md#3-features" in notes'
# L5 — the same rule at every level: a body-less H1 with no sub-heading is an anchor
pc "L5 fo66: '# Export to CSV' (no text, no sub-heading) is an anchor; '# Wallet PRD' / '# Reports' are containers (RED)" fo66-body-less-h1-requirement.md 1 "Export to CSV" - - prd.md#top-up prd.md#daily-report
# F11 / L2 — near misses are notes; a 2-3-space indented bullet and a '→' separator are read
for h in '### Coverage exclusions' '## Coverage exclusion' '## Exclusions' 'Coverage exclusions
---'; do
  printf '# ctx\n\n%s\n- "Refunds" — the partner bank refunds; nothing to build\n' "$h" > "$T/n11.ctx"
  pc "F11/L2 '$(printf '%s' "$h" | head -1)' is not read — the Refunds line decides nothing" "$T/r1.md" 1 "Refunds" - "$T/n11.ctx" prd.md#top-up
  pj "F11/L2 ... and the notes name the near miss (RED)" '"near-miss" in notes and "context.md:3" in notes'
done
printf '# ctx\n\n## Coverage exclusions\n  - "Refunds" → the partner bank refunds; nothing to build\n' > "$T/n11b.ctx"
pc "L2 a bullet indented 2 spaces (a top-level item in CommonMark) with a '→' separator declares (RED)" "$T/r1.md" 0 "" - "$T/n11b.ctx" prd.md#top-up
# F12 — a ref's file must match the source path exactly (case too), in unit-spec and in the gate alike
U3="$T/n12"; mkdir -p "$U3/docs" "$U3/.mega-sdd/vaults/p/units"; printf '# PRD\n\n## 1. Top-up\nTop up.\n' > "$U3/docs/PRD.md"
printf -- '---\nunit_id: U-001\ntitle: t\ntask_type: create\ncontext_source: context.md#flows\nprd_source: docs/prd.md#1-top-up\ntarget_files:\n  - path: src/a.ts\n    operation: create\nacceptance_test:\n  - type: test\n    command: npm test\n    expects: "ok"\n---\n# U\n' > "$U3/.mega-sdd/vaults/p/units/U-001.md"
printf '# ctx\n\n## Open Questions\n- none\n' > "$U3/.mega-sdd/vaults/p/context.md"
bash "$US" --cwd="$U3" --quiet >/dev/null 2>&1
python3 -c "import json,sys; d=json.load(open('$U3/.mega-sdd/.unit-spec-state.json')); sys.exit(0 if [i for i in d.get('issues', []) if i.get('halt_type') == 'prd_source_unresolvable'] else 1)" \
  && ok "F12 unit-spec rejects 'docs/prd.md#…' when the file is docs/PRD.md, as the gate does (RED on a case-insensitive disk)" || bad "F12 unit-spec accepted a case-mismatched ref"
bash "$V" --cwd="$U3" --prd="$U3/docs/PRD.md" --vault="$U3/.mega-sdd/vaults/p" --quiet >/dev/null 2>&1; ST="$U3/.mega-sdd/.plan-coverage-state.json"
pj "F12 ... and the gate names that ref in its notes (RED)" '[g["heading"] for g in d["gaps"]] == ["1. Top-up"] and "U-001.md → docs/prd.md#1-top-up" in notes'
# M6 — the key folds what CommonMark renders: VS16 emoji, backslash escapes, entities; an older slug still resolves
printf '# Demo\n\n## ⚠️ Risks\n\nVendor lock-in.\n\n## Pricing!\n\nDisplay only.\n\n## 1\\. Scope\n\nWeb only.\n\n## Goals &amp; KPIs\n\nKPI text.\n' > "$T/n13.md"
ctx > "$T/n13.ctx" <<'C'
## Coverage exclusions
- "Risks" — context only
- "Pricing" — display only, no behaviour
- "1. Scope" — scope boundary
C
pc "M6 '\"Risks\"' / '\"1. Scope\"' decide '⚠️ Risks' / '1\\. Scope'; an older slug ('#goals-amp-kpis') still resolves (RED)" "$T/n13.md" 0 "" - "$T/n13.ctx" prd.md#goals-amp-kpis
pj "M6 ... the heading reads as rendered ('Goals & KPIs')" 'cov.get("Goals & KPIs", "").startswith("unit prd_source") and "1. Scope" in decl'
# L1 — a real reason with '<' / '>' comparisons or starting 'fill-in' is not a placeholder
ctx > "$T/n14.ctx" <<'C'
## Coverage exclusions
- "Top-up" — the partner app loads it (< 2 s on 3G, escaping > raw HTML); nothing built here
- "Refunds" — fill-in of the refund form is done by the partner bank's own screen
C
pc "L1 reasons holding '< 2 s … >' or starting 'fill-in' are real reasons (RED)" "$T/r1.md" 0 "" - "$T/n14.ctx"
# L3 — a hidden block holding a heading + text is named in the notes
printf '# Payments PRD\n\nPayments for the web shop.\n\n## Checkout\n\nCard checkout page.\n\n```bash\nnpm run seed\n\n## Refunds\n\nSupport staff can refund an order from the admin panel within 7 days.\n\n```\n\n## Data model\n\nOrder, Payment.\n' > "$T/n15.md"
pc "L3 a fenced '## Refunds' + text stays hidden (a closed bash fence)" "$T/n15.md" 1 "Payments PRD" - - prd.md#checkout prd.md#data-model
pj "L3 ... but the notes name the block (RED)" '"hidden fence/comment block(s) hold a heading + text" in notes and "prd.md:9" in notes'
# M7 — the lanes that change coverage inputs after plan re-run the gate
grep -q "validate-plan-coverage.sh" "$ROOT/plugins/mega-sdd/skills/resolve-oq/SKILL.md" && grep -q "validate-plan-coverage.sh" "$ROOT/plugins/mega-sdd/skills/diff-vault/SKILL.md" \
  && ok "M7 resolve-oq and diff-vault re-run validate-plan-coverage.sh after they change OQs / sources (a doc check: it failed before the skill edits, not a script mutation)" || bad "M7 resolve-oq / diff-vault never re-run the gate"

echo "── P: the per-vault, digest-bound state the preflight / analyze read + unit-spec parity ──"
P="$T/proj"; mkdir -p "$P/docs" "$P/.mega-sdd/vaults/a/units" "$P/.mega-sdd/vaults/b/units"
printf '# PRD A\n\n## Top-up\nTop up.\n\n## Scheduled transfers\nRun at 06:00.\n' > "$P/docs/prd-a.md"
printf '# PRD B\n\n## Refunds\nRefund in 7 days.\n\n## Chargebacks\nReversed after 14 days.\n' > "$P/docs/prd-b.md"
printf -- '---\nunit_id: U-001\nstatus: pending\nprd_source: docs/prd-a.md#top-up\n---\n# U\n' > "$P/.mega-sdd/vaults/a/units/U-001.md"
printf -- '---\nunit_id: U-001\nprd_source: docs/prd-b.md#refunds\n---\n# U\n' > "$P/.mega-sdd/vaults/b/units/U-001.md"
printf '# ctx\n\n## Open Questions\n- none\n\n## Coverage exclusions\n- "Scheduled transfers" — a later tranche\n' > "$P/.mega-sdd/vaults/a/context.md"
printf '# ctx\n\n## Open Questions\n- none\n\n## Coverage exclusions\n' > "$P/.mega-sdd/vaults/b/context.md"
gate() { bash "$V" --cwd="$P" --prd="$P/docs/prd-$1.md" --vault="$P/.mega-sdd/vaults/$1" --quiet >/dev/null 2>&1; }
pre() { bash "$PF" --cwd="${1:-$P}" --skill=mega-sdd:execute-bolts --quiet >/dev/null 2>&1; echo $?; }
PST="$P/.mega-sdd/.preflight-state.json"; CST="$P/.mega-sdd/.plan-coverage-state.json"
gate b; gate a; r=$?
python3 - "$CST" "$r" <<'EOF' && ok "H4 one project slot, one entry per vault: vault a PASSes (exit 0) while the slot's status stays FAIL for vault b" || bad "H4 per-vault state"
import json, sys
d = json.load(open(sys.argv[1])); assert int(sys.argv[2]) == 0 and d["run_status"] == "PASS" and d["status"] == "FAIL", d
assert {k: v["status"] for k, v in d["vaults"].items()} == {".mega-sdd/vaults/a": "PASS", ".mega-sdd/vaults/b": "FAIL"}, d["vaults"]
assert ".mega-sdd/vaults/b (FAIL)" in d["next_action"] and d["summary"]["other_vaults_not_pass"] == [".mega-sdd/vaults/b (FAIL)"], d
EOF
[ "$(pre)" = 1 ] && python3 -c "import json,sys; d=json.load(open('$PST')); sys.exit(0 if 'FAIL for .mega-sdd/vaults/b' in d['fatal_on_fail'] and 'Chargebacks' in d['fatal_on_fail'] else 1)" \
  && ok "H4 the dispatch preflight refuses execute-bolts: vault b's entry is FAIL even though the last run (a) PASSed" || bad "H4 preflight trusted the last run"
out="$(bash "$PF" --predictive --cwd="$P" --chain=execute-bolts 2>/dev/null)"
printf '%s' "$out" | grep -q '"check": "lite_plan_coverage_pass", "status": "fatal"' && ok "H4 ... and so does the predictive twin" || bad "H4 predictive: $out"
printf -- '- "Chargebacks" — the card network runs them\n' >> "$P/.mega-sdd/vaults/b/context.md"; gate b
[ "$(pre)" = 0 ] && ok "F8 both vaults' entries are fresh PASSes → the preflight passes" || bad "F8 fresh PASS refused: $(head -c 400 "$PST")"
python3 - "$P/.mega-sdd/vaults/a/units/U-001.md" <<'EOF'
import sys; p = sys.argv[1]; t = open(p).read(); open(p, "w").write(t.replace("status: pending", "status: done"))
EOF
[ "$(pre)" = 0 ] && ok "F8 a unit status edit (pending → done) does not stale the entry (only prd_source refs / superseded count)" || bad "F8 status edit staled the entry"
python3 - "$P/.mega-sdd/vaults/a/context.md" <<'EOF'
import sys; p = sys.argv[1]; t = open(p).read(); open(p, "w").write(t.replace("## Open Questions\n", "## Flows\n### F-U-001: top-up\nA new flow line.\n\n## Open Questions\n"))
EOF
[ "$(pre)" = 0 ] && ok "M1 an edit ABOVE the exclusions (a flow line) moves their line numbers but not the entry: still fresh (RED)" || bad "M1 a line move staled the entry"
printf '\n## Instant refunds\nWithin one minute.\n' >> "$P/docs/prd-a.md"
[ "$(pre)" = 1 ] && python3 -c "import json,sys; d=json.load(open('$PST')); sys.exit(0 if 'stale for .mega-sdd/vaults/a' in d['fatal_on_fail'] else 1)" \
  && ok "F8 a PRD edit after the PASS (a new '## Instant refunds') makes vault a's entry stale → refused" || bad "F8 stale PRD passed"
bash "$AN" --cwd="$P" --aggregate-only >/dev/null 2>&1
python3 -c "import json,sys; d=json.load(open('$P/.mega-sdd/.analyze-state.json')); b=d['boundaries']['plan_coverage']; sys.exit(0 if b['status'] == 'FAIL' and 'stale for .mega-sdd/vaults/a' in b['detail'] else 1)" \
  && ok "M3 analyze reports plan_coverage FAIL (stale) for the same state the preflight refuses (RED)" || bad "M3 analyze: $(python3 -c "import json; print(json.load(open('$P/.mega-sdd/.analyze-state.json'))['boundaries'].get('plan_coverage'))" 2>&1)"
gate a; [ "$(pre)" = 1 ] && ok "F8 ... re-running the gate reports the new heading (FAIL), still refused" || bad "F8 re-run"
printf -- '- "Instant refunds" — a later tranche\n' >> "$P/.mega-sdd/vaults/a/context.md"; gate a; [ "$(pre)" = 0 ] || bad "F8 declared re-run"
printf -- '- "Top-up" — moved to the partner app\n' >> "$P/.mega-sdd/vaults/a/context.md"
[ "$(pre)" = 1 ] && ok "F8 an exclusion added after the PASS stales the entry too" || bad "F8 exclusion edit passed"
gate a; sed -i.bak '$d' "$P/.mega-sdd/vaults/a/context.md"; rm -f "$P/.mega-sdd/vaults/a/context.md.bak"
[ "$(pre)" = 1 ] && ok "F8 ... and so does deleting one at the Step-7 review" || bad "F8 exclusion delete passed"
gate a; printf 'x' >> "$P/.mega-sdd/vaults/b/units/U-001.md"
python3 - "$P/.mega-sdd/vaults/b/units/U-001.md" <<'EOF'
import sys; p = sys.argv[1]; t = open(p).read(); open(p, "w").write(t.replace("unit_id: U-001\n", "unit_id: U-001\nstatus: superseded\n"))
EOF
[ "$(pre)" = 1 ] && ok "F8 marking a unit superseded (plan --reconcile) stales its vault's entry" || bad "F8 superseded passed"
echo '{"source_documents":[{"path":"docs/prd-a.md","type":"PRD"}]}' > "$P/.mega-sdd/vaults/a/vault.json"
bash "$V" --cwd="$P" --prd="$P/docs/prd-b.md" --vault="$P/.mega-sdd/vaults/a" --quiet >/dev/null 2>&1
[ $? -eq 2 ] && ok "F8 --prd that is not in the vault's source_documents → exit 2 (a PASS for another document proves nothing)" || bad "F8 wrong PRD accepted"
# F4 / M2 — the entry is bound to the sources the vault pins NOW (never to the last run's list)
Q="$T/q"; QV="$Q/.mega-sdd/vaults/w"; mkdir -p "$Q/docs" "$QV/units"
printf '# Wallet PRD\n\n## 1. Top-up\nTop up.\n\n## 2. Refunds\nRefund in 7 days.\n' > "$Q/docs/PRD.md"; printf '# Glossary\n\n## VA\nVirtual account.\n' > "$Q/docs/glossary.md"
printf -- '---\nprd_path_at_generation: docs/PRD.md\n---\n# ctx\n\n## Open Questions\n- none\n\n## Coverage exclusions\n- "VA" — a glossary term\n' > "$QV/context.md"
echo '{"source_documents":[{"path":"docs/PRD.md","type":"PRD"},{"path":"docs/glossary.md","type":"glossary"}]}' > "$QV/vault.json"
printf -- '---\nunit_id: U-001\nprd_source: docs/PRD.md#1-top-up\n---\n' > "$QV/units/U-001.md"
bash "$V" --cwd="$Q" --prd="$Q/docs/glossary.md" --vault="$QV" --quiet >/dev/null 2>&1; r=$?
[ $r -eq 2 ] && ok "F4 a run on another source document (the glossary) of a vault that pins docs/PRD.md → exit 2 (RED)" || bad "F4 glossary run rc=$r"
[ "$(pre "$Q")" = 1 ] && ok "F4 ... so no entry: the preflight refuses (RED)" || bad "F4 preflight passed on a glossary census"
printf -- '---\nunit_id: U-002\nprd_source: docs/PRD.md#2-refunds\n---\n' > "$QV/units/U-002.md"
bash "$V" --cwd="$Q" --prd="$Q/docs/PRD.md" --vault="$QV" --quiet >/dev/null 2>&1 && [ "$(pre "$Q")" = 0 ] \
  && ok "F4 ... the run on the pinned PRD PASSes and the preflight passes" || bad "F4 pinned PRD run"
printf '# Wallet PRD v1.1\n\n## 1. Top-up\nTop up.\n\n## 2. Refunds\nRefund in 7 days.\n\n## 3. Admin export\nCSV of all messages.\n' > "$Q/docs/PRD-v1.1.md"
sed -i.bak 's#docs/PRD.md#docs/PRD-v1.1.md#' "$QV/context.md" "$QV/vault.json"; rm -f "$QV"/*.bak
[ "$(pre "$Q")" = 1 ] && python3 -c "import json,sys; d=json.load(open('$Q/.mega-sdd/.preflight-state.json')); sys.exit(0 if 'docs/PRD-v1.1.md' in d['fatal_on_fail'] else 1)" \
  && ok "M2 the vault re-pinned to PRD-v1.1.md (diff-vault): the PASS on docs/PRD.md is stale → refused (RED)" || bad "M2 a moved pin kept the PASS"
printf -- '---\nprd_path_at_generation: docs/PRD.md\n---\n# ctx\n\n## Open Questions\n- none\n\n## Coverage exclusions\n' > "$QV/context.md"
echo '{"source_documents":[{"path":"docs/PRD.md","type":"PRD"},{"path":".mega-sdd/vaults/w/source/delta-1.md","type":"brief"}]}' > "$QV/vault.json"
mkdir -p "$QV/source"; printf '# Seed PRD — delta\n\n## E. In-scope features\nExport refunds as CSV.\n' > "$QV/source/delta-1.md"
bash "$V" --cwd="$Q" --prd="$Q/docs/PRD.md" --vault="$QV" --quiet >/dev/null 2>&1; r=$?
[ $r -eq 2 ] && ok "M2 a delta seed-PRD (type: brief) the vault lists must be censused too: a run on the PRD alone → exit 2 (RED)" || bad "M2 brief skipped rc=$r"
printf -- '---\nunit_id: U-003\nprd_source: .mega-sdd/vaults/w/source/delta-1.md#e-in-scope-features\n---\n' > "$QV/units/U-003.md"
printf '# ctx\n\n## Coverage exclusions\n- delta-1.md#"Seed PRD — delta" — the seed title\n' >> "$QV/context.md"
bash "$V" --cwd="$Q" --prd="$Q/docs/PRD.md" --prd="$QV/source/delta-1.md" --vault="$QV" --quiet >/dev/null 2>&1 && [ "$(pre "$Q")" = 0 ] \
  && ok "M2 ... one run with --prd per source PASSes; a declaration may name the file's unique basename" || bad "M2 two-source run: $(head -c 600 "$Q/.mega-sdd/.plan-coverage-state.json")"
# F9 / M4 / M8 / L4: validate-unit-spec.sh resolves a prd_source exactly when the coverage gate matches it
U="$T/us"; mkdir -p "$U/docs" "$U/.mega-sdd/vaults/p/units"
cat > "$U/docs/PRD Kontak.md" <<'P'
# PRD: Wallet

Top-up
------
Users top up from a bank account.

## 3. Timeline {#timeline}
Beta in Q3.

### F-PAY-001 — Transfer to bank
Transfers settle T+0.

<h2 id="kyc">KYC</h2>
ID card check.

## Café payments
QRIS at partner cafés.

  ## Refunds
Refund within 7 days.

## Descripción general
Resumen.

### Business rules
One.

### Business rules
Two.
P
printf '# ctx\n\n## Open Questions\n- none\n' > "$U/.mega-sdd/vaults/p/context.md"; k=0
for r in top-up timeline F-PAY-001 kyc cafe-payments refunds descripcion-general descripci-n-general business-rules business-rules-1; do k=$((k + 1))
  printf -- '---\nunit_id: U-%03d\ntitle: t\ntask_type: create\ncontext_source: context.md#flows\nprd_source: "docs/PRD Kontak.md#%s"\ntarget_files:\n  - path: src/a%d.ts\n    operation: create\nacceptance_test:\n  - type: test\n    command: npm test\n    expects: "ok"\n---\n# U\n' $k "$r" $k > "$U/.mega-sdd/vaults/p/units/U-$(printf %03d $k).md"; done
bash "$US" --cwd="$U" --quiet >/dev/null 2>&1
python3 - "$U/.mega-sdd/.unit-spec-state.json" <<'EOF' && ok "F9 unit-spec resolves setext / {#id} / whole F-id / html id / accent-folded / indented / repeated-heading (x-1) refs and a path with a space" || bad "F9 unit-spec rejects refs the gate accepts"
import json, sys
d = json.load(open(sys.argv[1])); bad = [i for i in d.get("issues", []) if i.get("halt_type") == "prd_source_unresolvable"]
assert not bad, bad
EOF
bash "$V" --cwd="$U" --prd="$U/docs/PRD Kontak.md" --vault="$U/.mega-sdd/vaults/p" --quiet >/dev/null 2>&1
python3 - "$U/.mega-sdd/.plan-coverage-state.json" <<'EOF' && ok "F9 ... and the coverage gate covers every anchor through the same refs (the title is a container)" || bad "F9 gate disagrees"
import json, sys
d = json.load(open(sys.argv[1])); assert d["status"] == "PASS" and d["covered"] == d["anchors"] == 9, (d["anchors"], d["gaps"])
EOF
printf -- '---\nunit_id: U-099\ntitle: t\ntask_type: create\ncontext_source: context.md#flows\nprd_source: "docs/PRD Kontak.md#business-rule"\ntarget_files:\n  - path: src/z.ts\n    operation: create\nacceptance_test:\n  - type: test\n    command: npm test\n    expects: "ok"\n---\n# U\n' > "$U/.mega-sdd/vaults/p/units/U-099.md"
bash "$US" --cwd="$U" --quiet >/dev/null 2>&1
python3 - "$U/.mega-sdd/.unit-spec-state.json" <<'EOF' && ok "F9 ... while a slug no heading has stays prd_source_unresolvable" || bad "F9 bad slug resolved"
import json, sys
d = json.load(open(sys.argv[1])); bad = [i["unit_id"] for i in d.get("issues", []) if i.get("halt_type") == "prd_source_unresolvable"]
assert bad == ["U-099"], bad
EOF

echo "── F: the F-id path ──"
pc "F1 F-TRF-001 does not cover F-TRF-001a / F-TRF-001b (the id ends at a word boundary)" \
  fo39-fid-letter-suffix.md 1 "F-TRF-001a Scheduled Transfer|F-TRF-001b Recurring Transfer" - - 'prd.md#F-TRF-001' 'prd.md#F-TRF-002'
pc "F2 an F-id ref into ANOTHER PRD covers nothing here (the F-id path checks the ref's file)" \
  fo40-fid-cross-file.md 1 "F-TRF-002 Scheduled Transfer" - - 'prd.md#f-trf-001-instant-transfer' 'docs/archive/mbanking-v1-prd.md#F-TRF-002' 'prd.md#f-trf-003-transfer-history'
pc "F3 ... while an F-id ref to this PRD covers its own flow" \
  fo40-fid-cross-file.md 0 "" - - 'prd.md#F-TRF-001' 'prd.md#F-TRF-002' './prd.md#F-TRF-003'
pc "F4 F-PAY-12 does not cover F-PAY-1" fo15-fid-prefix.md 1 "F-PAY-1 Transfer" - - 'prd.md#f-pay-12-refund'
pc "F5 F-U-001 does not cover F-U-001-B, F-U-002 does not cover F-U-002.1" \
  fo25-fid-suffix.md 1 "F-U-001-B — Slot already taken (alternate)|F-U-002.1 — Late cancellation fee" - - \
  'prd.md#clinic-1-functional-requirements-user-flows' 'prd.md#F-U-001' 'prd.md#F-U-002'
pc "F6 ... nor the reverse (sub-flows do not cover the main flows)" \
  fo25-fid-suffix.md 1 "F-U-001 — Patient books appointment|F-U-002 — Patient cancels appointment" - - \
  'prd.md#clinic-1-functional-requirements-user-flows' 'prd.md#f-u-001-b-slot-already-taken-alternate' 'prd.md#f-u-002-1-late-cancellation-fee'

echo "── B: fail-open attack fixtures — every anchor needs a decision ──"
pc "fo01 meta-named feature sections are anchors like any other (Background too)" fo01-meta-named-features.md 1 \
  "1. Background|3. Version History|4. Backgrounds|5. Sources|6. Goals|7. Objectives|8. References|9. Changelog|10. Revision History" - - 'prd.md#2-document-editor'
pc "fo02 Indonesian banking names are anchors (Latar Belakang, Sumber & Tujuan, Riwayat, Tidak Termasuk:, Versi)" fo02-id-banking-names.md 1 \
  "1. Latar Belakang|2.1 Sumber & Tujuan|2.3 Referensi|3. Riwayat (Mutasi Rekening)|4.1 Riwayat Perubahan|Tidak Termasuk:|Versi|Latar" - - \
  'prd.md#2-fitur-transfer' 'prd.md#2-2-nominal' 'prd.md#4-profil-nasabah' 'prd.md#5-paket-langganan' 'prd.md#termasuk' 'prd.md#6-force-update' 'prd.md#7-tema'
pc "fo03 id-words / parentheticals / meta pairs: all anchors" fo03-idword-and-paren.md 1 \
  "Overview|FR12 Version History|US3 Goals|OAuth2 Scope|§API.3 Sources (Funding Sources: card, VA, QRIS)|Context (Request Context Propagation)|Version (Force Update):|4) Scope (per-tenant data isolation)|Sources / References|B2B Scope" - -
pc "fo04 a fenced '## Out of scope' / '## Highlights' is no heading; the real H3s are gaps" fo04-fenced-oos.md 1 "1.1 Grouping|1.2 Version Bump Rules" - - \
  'prd.md#1-generator-output' 'prd.md#2-publishing' 'prd.md#highlights'
pj "fo04 exactly 4 anchors (nothing from inside the fence)" 'd["anchors"] == 4 and "highlights" not in [c["slug"] for c in d["covered_detail"]]'
pc "fo05 a commented '## Out of scope' is no heading" fo05-comment-oos.md 1 "4.1 Refund Window|4.2 Partial Refunds" - - 'prd.md#4-payments' 'prd.md#5-receipts'
pc "fo06 setext H2s are anchors" fo06-setext.md 1 "Out of Scope|Transfer Limits|Top-up" - - 'prd.md#notifications'
pc "fo07 a setext H2 after an ATX section is an anchor; the body-less '3. Transfers' is a container" fo07-setext-ends-oos.md 1 \
  "1. Background|2. Out of scope|3.1 Transfer Limits|3.2 Scheduled Transfers" - - 'prd.md#4-notifications'
pc "fo08 H2s under an H1 are anchors; the H1 is not" fo08-h1-ends-oos.md 1 "1.1 Background|1.2 Out of Scope" - - \
  'prd.md#fr-1-transfer-limits' 'prd.md#fr-2-scheduled-transfers'
pc "fo09 an H2 with 1-3 leading spaces is a heading ('  ## Payments' is the container of Refund Window)" fo09-indented-h2-ends-oos.md 1 "Out of scope|Refund Window" - -
pj "fo09 ... it is parsed: the notes list it as a container" '"prd.md#payments" in notes'
pc "fo10 a setext H2 is censused; its H4 / bold lines ride on it (documented H4 limit)" fo10-setext-h4-bold.md 0 "" - - 'prd.md#transfer-limits'
pj "fo10 exactly 1 anchor" 'd["anchors"] == 1'
pc "fo11 'Tidak Termasuk' (body-less: a container) and its fee H3s are anchors" fo11-tidak-termasuk-fees.md 1 \
  "1. Tujuan|3.1 Transfer Luar Negeri|3.2 Tarik Tunai ATM Bank Lain" - - 'prd.md#2-termasuk-dalam-paket' 'prd.md#4-kartu-debit'
pc "fo12 decorated / closing-hash headings are anchors (their text is the heading)" fo12-bare-riwayat-forms.md 1 \
  "📜 Riwayat|**Scope**|Riwayat|Context —|Goals!|Riwayat|riwayat:|RIWAYAT.|3 - Scope" - -
pc "fo13 a :line inside an H3 body owns that H3 only" fo13-h3-meta-under-feature.md 1 "3. BI-FAST Transfer|3.1 Scope|3.3 Data Model" - - 'prd.md:7'
pc "fo14 an OQ decides a heading only through [covers:]: 'shipping' is not 'PIN', 'on checkout' covers nothing" \
  fo14-oq-substring.md 1 "PIN|Fee|Refund|Checkout" fo14-oq-substring.vault.json -
pc "fo16 a fence opened in a list item ends with the item" fo16-listitem-fence-implicit-close.md 1 \
  "§4. Transfer Terjadwal|§5. Idempotensi|§6. Kode Error" - - 'prd.md#3-transfer-api'
pc "fo17 a forgotten \`\`\`json closer hides no '## §N.' section" fo17-fence-forgot-section-sign.md 1 \
  "§2. Transfer Terjadwal|§3. Limit Harian|§4. Notifikasi" - - 'prd.md#1-transfer-antar-rekening'
pj "fo17 the refused fence is named in the notes" 'any("NOT treated" in n and "prd.md:7" in n for n in d["notes"])'
pc "fo18 a forgotten closer under an H3 hides no numbered H3" fo18-fence-forgot-h3.md 1 \
  "3.2 Scheduled Transfers|3.3 Idempotency|3.4 Error Codes" - - 'prd.md#3-transfer-api' 'prd.md#3-1-request' 'prd.md#4-notifications'
pc "fo19 a forgotten \`\`\`bash closer hides no unnumbered H2" fo19-fence-forgot-unnumbered.md 1 "Scheduled Transfers|Withdrawal|Notifications" - - 'prd.md#top-up'
pc "fo20 a forgotten \`\`\`dbml closer hides nothing; the data-model section is an anchor" fo20-fence-forgot-under-datamodel.md 1 \
  "§2. Data Model|§3. Autodebet Bulanan|§4. Pencairan|§5. Notifikasi" - - 'prd.md#1-pembukaan-rekening'
pc "fo21 a forgotten '<!--' is not closed by a Mermaid '-->' arrow" fo21-comment-closed-by-mermaid-arrow.md 1 \
  "2. Transfer Terjadwal|3. Limit Harian|4. Alur Transfer" - - 'prd.md#1-transfer-antar-rekening' 'prd.md#5-notifikasi'
pc "fo22 a forgotten '<!--' is not closed by a prose arrow" fo22-comment-closed-by-prose-arrow.md 1 "Refunds|Order Status" - - 'prd.md#checkout' 'prd.md#receipts'
pc "fo23 no wording (affixed WAJIB, MUST NOT, '(TBC?)') decides anything: every anchor is a gap" fo23-normative-evasion.md 1 \
  "1. Ruang Lingkup|3. Context|4. Goals|5.1 Transfer Valas|5.2 Biaya Tarik Tunai Bank Lain" - - 'prd.md#2-transfer'
pc "fo24 a keyword-less fee rule under 'Tidak Termasuk' is an anchor" fo24-tidak-termasuk-natural.md 1 \
  "1. Tujuan|3.1 Transfer Luar Negeri|3.2 Tarik Tunai ATM Bank Lain" - - 'prd.md#2-termasuk-dalam-paket' 'prd.md#4-kartu-debit'
pc "fo26 a superseded unit covers nothing" fo26-superseded-unit.md 1 "2. Transfer Terjadwal" - - 'prd.md#1-transfer-antar-rekening' 'superseded:prd.md#2-transfer-terjadwal'
pj "fo26 ... and the notes say so" 'any("superseded unit" in n and "U-002.md" in n for n in d["notes"])'
pc "fo27 a CJK heading has its own slug" fo27-nonlatin-slug.md 1 "定时转账|通知" - - 'prd.md#转账'
pc "fo28 '(OOS) Detection' and its H3s are anchors" fo28-oos-detection-noun-phrase.md 1 \
  "1. Latar Belakang|3.1 Ambang Keyakinan|3.2 Balasan Fallback|3.3 Eskalasi ke Live Agent|3.4 Logging untuk Retraining" - - \
  'prd.md#2-intent-perbankan' 'prd.md#2-1-cek-saldo' 'prd.md#2-2-riwayat-transaksi' 'prd.md#3-out-of-scope-oos-detection' 'prd.md#4-notifikasi-proaktif'
pc "fo29 'Deferred …' sections and a 'Deferred' status H3 are anchors" fo29-deferred-settlement-and-status.md 1 \
  "1. Overview|3. Deferred & Scheduled Settlement|3.1 Cut-off Time|3.2 Holiday Calendar|3.3 Settlement Report|4.2 Deferred" - - \
  'prd.md#2-instant-settlement' 'prd.md#4-transaction-statuses' 'prd.md#4-1-pending' 'prd.md#4-3-settled'
pc "fo30 a forgotten \`\`\`bash closer is caught when a later \`\`\`json turns the pairing" fo30-fence-forgot-trailing-json.md 1 \
  "Scheduled Transfers|Withdrawal|Notifications" - - 'prd.md#top-up'
pc "fo31 'Di Luar Cakupan' under a feature is an anchor" fo31-di-luar-cakupan-insurance.md 1 "1. Latar Belakang|3.2 Di Luar Cakupan" - - \
  'prd.md#2-pendaftaran-polis' 'prd.md#3-manfaat-polis' 'prd.md#3-1-cakupan' 'prd.md#4-pengajuan-klaim'
pc "fo32 'Non-goals & Guardrails' is an anchor" fo32-nongoals-guardrails.md 1 "1. Problem Statement|3. Non-goals & Guardrails" - - \
  'prd.md#2-answer-account-questions' 'prd.md#4-feedback'
pc "fo33 Q&A / Target Audience / Dependencies features are anchors" fo33-meta-named-features-declarative.md 1 \
  "1. Overview|3. Q&A|5. Target Audience|6. Dependencies" - - 'prd.md#2-registration' 'prd.md#4-polls'
pc "fo34 Context / Sources features are anchors" fo34-context-sources-features.md 1 "1. Background|3. Context|4. Sources" - - 'prd.md#2-tanya-jawab'
pc "fo35 a unit citing 'payments-prd.md' covers nothing in 'prd.md'" fo35-cross-prd-suffix.md 1 "Notifications|Audit Log" - - \
  'prd.md#transfer' 'payments-prd.md#notifications' 'payments-prd.md#audit-log'
pc "fo36 an HTML <h2> and a blockquoted '### 4.1' are headings" fo36-html-and-quoted-headings.md 1 "4. Transfer Terjadwal|4.1 Gagal Saldo" - - \
  'prd.md#3-transfer-antar-rekening' 'prd.md#5-notifikasi'
pc "fo36 ... the <h2 id> or its text slug covers it" fo36-html-and-quoted-headings.md 0 "" - - \
  'prd.md#3-transfer-antar-rekening' 'prd.md#5-notifikasi' 'prd.md#transfer-terjadwal' 'prd.md#4-1-gagal-saldo'
pc "fo37 an 'Out of Scope' H2 and its H3s are anchors" fo37-oos-kept-opens-no-region.md 1 "2. Out of Scope|2.1 Pending Refund Report|2.2 Refund Reason Codes" - - \
  'prd.md#1-refund-request' 'prd.md#3-notifications'
pc "fo38 an ATX heading indented 4 spaces inside a list item is a heading" fo38-listitem-indented-heading.md 1 "1.1 Scheduled Transfer" - - \
  'prd.md#1-transfer' 'prd.md#2-notifications'
pc "fo41 a '**Label:** Name' paragraph over '----' after the first H2 is a setext heading, not metadata" fo41-setext-bold-label.md 1 \
  "**NEW:** Scheduled Transfers" - - 'prd.md#top-up' 'prd.md#transaction-history'
pc "fc01 numbered H3s named Sumber / Tujuan / Riwayat are anchors" fc01-numbered-h3-mbanking.md 1 "3.1 Sumber|3.2 Tujuan|3.3 Riwayat" - - \
  'prd.md#3-fitur-transfer' 'prd.md#3-4-konfirmasi'
pc "fc02 numbered H3s named Version History / References / Context are anchors" fc02-numbered-h3-editor.md 1 "4.2 Version History|4.3 References|4.4 Context" - - \
  'prd.md#4-features' 'prd.md#4-1-real-time-collaboration'
pc "fc03 requirement-id H3s are anchors" fc03-reqid-h3.md 1 "FR1 Sources|FR2 Scope (OAuth)|UC3 Version History|F4 Riwayat" - - \
  'prd.md#functional-requirements' 'prd.md#f-5-sources'

echo "── C: fail-closed attack fixtures — FAIL undeclared, PASS with the natural declarations ──"
# fixture | undeclared gap count | the units (a container's own ref covers nothing — a note; its sub-headings are anchors)
while IFS='|' read -r fx g units; do
  [ -z "$fx" ] && continue
  # shellcheck disable=SC2086
  pc "${fx%%-*} undeclared: FAIL (${fx#*-})" "$fx" 1 "+" - - $units
  pj "${fx%%-*} ... with $g gaps — no section name is special" "len(d['gaps']) == $g"
  # shellcheck disable=SC2086
  pc "${fx%%-*} with ${fx%.md}.context.md: PASS" "$fx" 0 "" - "${fx%.md}.context.md" $units
  pj "${fx%%-*} ... every forced heading is a declared exclusion ($g), the rest are covered" \
    "nd == $g and d['anchors'] == $g + d['covered'] and all(x['reason'] for x in decl.values())"
done <<'L'
fc04-compound-meta.md|7|prd.md#pembukaan-rekening
fc05-compound-meta-battery.md|39|prd.md#transfer-terjadwal
fc06-oos-qualified.md|56|prd.md#features prd.md#pay
fc07-standard-sections-en.md|16|prd.md#user-stories prd.md#us-1-guest-checkout prd.md#us-2-saved-addresses
fc08-standard-sections-id.md|15|prd.md#8-kebutuhan-fungsional prd.md#8-1-verifikasi-e-ktp prd.md#8-2-setoran-awal
fc09-meta-qualified.md|40|prd.md#features prd.md#pay
fc10-h3-meta.md|9|prd.md#requirements prd.md#create-va prd.md#confirm-payment
fc11-seed-prd.md|11|prd.md#e-in-scope-features-v1 prd.md#g-constraints prd.md#technical prd.md#regulatory-compliance
fc15-metadata-setext.md|3|prd.md#features prd.md#earn-points
fc16-meta-children.md|21|prd.md#features prd.md#book-a-slot prd.md#cancel-a-booking
fc17-meta-names.md|39|prd.md#booking
fc18-meta-pairs.md|31|prd.md#booking
fc19-lenny-prompts.md|6|prd.md#what-roughly-what-does-this-look-like-in-the-product prd.md#how-what-is-the-experiment-plan
fc23-normative-labels.md|2|prd.md#booking
L
pj "fc23 'Stakeholders' / 'Success Metrics' are declared with their reasons" 'sorted(decl) == ["Stakeholders", "Success Metrics"]'
pc "fc05/fc10 two headings with one name are declared by their unique slugs (a quoted name would be ambiguous)" fc10-h3-meta.md 0 "" - fc10-h3-meta.context.md \
  prd.md#requirements prd.md#create-va prd.md#confirm-payment
pj "fc10 ... both 'Open Questions' H3s are declared; the body-less containers' lines are stale notes" 'nd == 9 and sum(1 for x in d["excluded"] if x["heading"] == "Open Questions") == 2 and "stale" in notes'
pc "fc15 metadata over '---' under the title and an authorship line after the first H2 are setext headings (CommonMark), declared like any other" fc15-metadata-setext.md 1 \
  "Author: Jane Status: Draft|Prepared by the product team|Appendix" - - prd.md#features prd.md#earn-points
for fx in fc12-bom-frontmatter.md fc13-leadblank-frontmatter.md; do
  pc "${fx%%-*} YAML frontmatter at the top of the file is hidden (${fx#*-})" "$fx" 0 "" - - 'prd.md#features' 'prd.md#earn-points'
  pj "${fx%%-*} exactly 1 anchor ('Features' has no text: a container)" 'd["anchors"] == 1'
done
pc "fc14 a YAML-like block under the title is a thematic break + a setext H2, one declaration away" fc14-frontmatter-after-title.md 1 "title: PRD Loyalty owner: Jane" - - 'prd.md#features' 'prd.md#earn-points'
pc "fc20 ... whatever its keys" fc20-frontmatter-any-key.md 1 "prd_id: PRD-7 status: draft squad: growth" - - 'prd.md#features' 'prd.md#earn-points'
pc "fc21 a banner and metadata paragraphs over '---' under the title are setext headings — no word list skips them" fc21-metadata-bold-keys-banner.md 1 \
  "_Draft v0.3 — for internal review_|**Versi:** 0.3 **Pemilik:** Dewi **Tim:** Squad Booking|**Target release:** Q3 2026 **Epic:** CLIN-12" - - 'prd.md#features' 'prd.md#earn-points'
pc "fc22 NFR / data-model sections are requirements: undeclared, their four H3s are gaps (the body-less H2s are containers)" fc22-constraint-children.md 1 \
  "Performance|Security|Entities|5.1 Performance" - - prd.md#booking
pc "fc22 ... declaring '\"Performance\"' is ambiguous next to '5.1 Performance' (use the slug)" fc22-constraint-children.md 1 \
  "+Performance|(invalid coverage exclusion) - \"Performance\" — captured in context.md ## Constraints; cross-cutting, no unit of its own" - fc22-constraint-children.context.md prd.md#booking
pc "fc22 ... and the units that honour them cite them → PASS with no declaration" fc22-constraint-children.md 0 "" - - \
  prd.md#booking prd.md#performance prd.md#security prd.md#entities prd.md#5-1-performance

echo "── H: parser guards + no name is special ──"
pc "hx01 an H4 / bold line rides on its H2: 'Background' and 'Out of scope' are the anchors" hx01-zero-anchors.md 1 "Background|Out of scope" - -
pc "hx02 a comment missing its '-->' hides nothing" hx02-forgotten-comment-closer.md 1 "2. Out of scope|2.1 Scheduled Transfers" - - 'prd.md#1-wallet'
pc "hx03 a fence spanning a numbered H2 is no fence: its lines are censused ('Out of scope' holds only a fence marker: a container)" hx03-fence-spans-numbered-h2.md 1 "1. Summary|1.1 Grouping" - - \
  'prd.md#1-generator-output' 'prd.md#2-publishing'
pc "hx04 a leading '---' block holding an H2 is not frontmatter" hx04-frontmatter-lookalike.md 1 "Payments|Background" - -
pc "hx07 '##Payments' (space forgotten) is a heading (here the container of Refund Window)" hx07-nospace-atx-ends-oos.md 1 "Out of scope|Refund Window" - -
pj "hx07 ... the notes list it as a container" '"prd.md#payments" in notes'
pc "hx08 real blocks stay hidden: list-item fence, commented section, one-line comment, closed bash banner" hx08-real-blocks-stay-hidden.md 0 "" - - \
  'prd.md#1-transfer' 'prd.md#2-notifications'
pj "hx08 exactly 2 anchors, nothing refused" 'd["anchors"] == 2 and not any("NOT treated" in n for n in d["notes"])'
pc "hx10 a markdown sample holding a § section is censused, its closer opens no fence" hx10-markdown-sample-no-cascade.md 1 "§1. Summary" - - \
  'prd.md#1-output-format' 'prd.md#2-delivery' 'prd.md#2-1-naming'
pc "hx16 a blockquoted '## Out of scope' is a heading and opens no region" hx16-quoted-oos-no-region.md 1 "Out of scope|Scheduled Transfers" - - 'prd.md#transfers'
pc "hx05 no wording excludes (MUST NOT, not required, tidak wajib, questions)" hx05-negation-and-questions.md 1 "Open Questions|Crypto payments|Cicilan" - - 'prd.md#checkout'
pc "hx06 NFR / data-model sections are anchors" hx06-constraint-note.md 1 "Non-Functional Requirements|Data Model" - - 'prd.md#transfers'
pc "hx09 feature-looking and meta-looking names alike are anchors" hx09-feature-names-stay-anchors.md 1 \
  "Overview|Timeline|Jadwal|Lampiran|Approvals|Summary|Exclusions|Tidak Termasuk" - - 'prd.md#transfers'
pc "hx11 a table body decides nothing" hx11-table-cells.md 1 "Open Questions|Background" - - 'prd.md#tabungan-berjangka'
pc "hx12 body-less Scope H2s are containers; their H3s are anchors" hx12-scope-h2-feature-h3s.md 1 \
  "1. Overview|Version History|References|Context|Sumber|Riwayat Perubahan|4. Glossary" - - 'prd.md#2-1-real-time-collaboration'
pc "hx13 Open Items / Open Issues / Isu Terbuka / Open Questions H3s are anchors" hx13-open-items-h3-feature.md 1 "Open Items|Open Issues|Isu Terbuka|Open Questions" - - \
  'prd.md#accounts-receivable' 'prd.md#aging-report' 'prd.md#issue-tracker'
pc "hx14 body-less Overview / Appendix H2s are containers; every H3 under them is an anchor" hx14-open-containers.md 1 "Background|Transfer|A. Wireframes|B. Error Codes" - -
pc "hx15 Background and its H3 are anchors" hx15-kept-meta-is-a-feature.md 1 "Background|Current Flow" - - 'prd.md#transfer'
pc "hx17 every name, quoted H2 included, is an anchor" hx17-feature-names-by-body.md 1 \
  "Dokumen Pendukung|Meeting Notes|Schedule|Q&A|Additional Information|Success|Hypotheses|User Segments|Not Included|OOS|Designs|Login Screen|MVP (Q3)|Early Repayment|Background|Fee" - - 'prd.md#pengajuan'
exit $rc
