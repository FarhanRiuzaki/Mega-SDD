#!/usr/bin/env bash
# test-oq-single-prompt.sh — tranche 3a: resolve-oq collapses 3 human round trips per OQ into 1.
#
# The old walk asked three times per OQ: the A/B/C/D action menu (Step 2b), the free-text
# answer (Step 2c.1), and the destination confirm/override (Step 2c.3) — plus a conditional
# fourth for cross-cutting landing. The collapse makes them ONE AskUserQuestion:
#   [1] recommended answer   [2] Skip   [3] Defer   [4] Out of scope
#   Other = the free-text answer (+ the destination override, which composes with [1])
#   Esc   = END THE WALK — the plugin-wide meaning of the platform escape
# The destination lands INSIDE the answer option's description, so choosing IS confirming.
# The considered alternatives lost their slot and moved into the question text as sourced prose.
#
# PINNING PHILOSOPHY: assert the TEMPLATE A MODEL COPIES, not the prose around it. A rail that a
# re-worded but behaviourally-identical edit breaks — or that a behaviourally-broken but
# identically-worded edit passes — is not a rail. So the structural checks below parse the fenced
# blocks (option counts, per-option description presence / substance / non-placeholder-ness,
# mandated fields present as slots, the follow-up prompts' question+option structure) and only the
# machine-parsed derive payloads are pinned as exact strings.
#
# Run: bash tests/interaction-keterangan/test-oq-single-prompt.sh
# CI-safe: bash + python3 only.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
IW="$P/skills/resolve-oq/references/interactive-walk.md"
RC="$P/skills/resolve-oq/references/recommendation-context.md"
SK="$P/skills/resolve-oq/SKILL.md"
AM="$P/skills/resolve-oq/references/auto-memory-handoff.md"
BM="$P/skills/resolve-oq/references/binding-mode.md"
HR="$P/skills/execute-bolts/references/halt-recovery.md"
PC="$P/skills/execute-bolts/references/propose-and-confirm-prompt.md"

FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
has()  { grep -qF "$2" "$1"; }

for f in "$IW" "$RC" "$SK" "$AM" "$BM" "$HR" "$PC"; do
  [ -f "$f" ] || { fail "missing file: $f"; echo "oq single-prompt pins FAILED"; exit 1; }
done

# ---------------------------------------------------------------- shared python helpers
# Written to a temp module so every check below can use a QUOTED heredoc — an unquoted one
# lets the shell eat the backticks and $ in the asserted markdown.
OQLIB="$(mktemp -d)"
trap 'rm -rf "$OQLIB"' EXIT
export OQLIB
cat > "$OQLIB/oqlib.py" <<'OQLIBPY'
import re, sys, os

RC_ = [0]
def chk(cond, good, bad):
    print(("  ✓ " + good) if cond else ("  ✗ FAIL: " + bad))
    if not cond: RC_[0] = 1

def block_after(src, heading, which=0):
    """The `which`-th fenced block following `heading`."""
    i = src.index(heading)
    blocks = re.findall(r"```[a-z]*\n(.*?)\n```", src[i:], re.S)
    assert len(blocks) > which, "no fenced block #%d after %r" % (which, heading)
    return blocks[which]

def options_of(block):
    """[(label, description_or_None)] from a YAML-ish option list."""
    out = []
    for chunk in re.split(r"^\s*-\s*label:", block, flags=re.M)[1:]:
        label = chunk.split("\n", 1)[0].strip().strip(chr(34))
        m = re.search(r"description:\s*" + chr(34) + r"(.*?)" + chr(34), chunk, re.S)
        out.append((label, " ".join(m.group(1).split()) if m else None))
    return out

def literal_len(desc):
    """Characters of real prose OUTSIDE {template braces} — a description that is wholly a
    placeholder expression (e.g. {same keterangan as the full shape}) scores ~0."""
    depth, n = 0, 0
    for ch in desc:
        if ch == "{": depth += 1
        elif ch == "}": depth = max(0, depth - 1)
        elif depth == 0 and not ch.isspace(): n += 1
    return n

BANNED = ("same keterangan", "as above", "idem", "per step 2b>", "sda", "tbd", "n/a")
ID_WORDS = ("yang","tidak","kalau","jadi","akan","aku","sudah","tetap","pindah","dinyatakan",
            "mendarat","kamu","sebagai","kalimat","tanpa","dulu","luar","satu","kali","lagi",
            "jawab","ini","apa","kapan","memilih","entri","ditandai","supaya","belum","bisa",
            "lewati","saja","menunggu","tercatat","pilihan","alasan","dengan","pakai","mau")

def assert_keterangan(where, n, label, desc):
    """The user-mandated per-option keterangan contract, asserted structurally."""
    tag = "%s option [%d] (%s)" % (where, n, (label or "?")[:26])
    chk(desc is not None, tag + " has a description",
        tag + " has NO description — keterangan contract violated")
    if desc is None:
        return
    chk(len(desc) >= 40, tag + " description is substantive (%d chars)" % len(desc),
        tag + " description is too thin (%d chars)" % len(desc))
    chk(literal_len(desc) >= 20,
        tag + " description is literal prose, not a placeholder expression",
        tag + " description is (near-)wholly a {placeholder} — a model would copy it verbatim")
    low = desc.lower()
    chk(not any(b in low for b in BANNED),
        tag + " description names no substitute-elsewhere placeholder",
        tag + " description defers to another file instead of stating the mechanic")
    hits = {w for w in ID_WORDS if re.search(r"\b%s\b" % w, desc, re.I)}
    chk(len(hits) >= 2, tag + " description reads as narration prose (markers: %s)"
        % ", ".join(sorted(hits))[:40],
        tag + " description does not read as narration (markers: %s)" % sorted(hits))
OQLIBPY

echo "== 1. the canonical template a model copies: 4 slots, correct affordances =="

python3 - "$IW" <<'PY'
import sys, os
sys.path.insert(0, os.environ['OQLIB'])
from oqlib import *
src = open(sys.argv[1], encoding='utf-8').read()
full = block_after(src, '#### The prompt, verbatim')
opts = options_of(full)

chk(len(opts) == 4,
    "canonical template declares exactly 4 options (the platform cap)",
    "canonical template declares %d options — cap is 4" % len(opts))
chk(not re.search(r'\[\s*5\s*\]', full),
    "no [5] slot in the canonical template",
    "a [5] slot survives — the platform will not dispatch it")

labels = [l for l, _ in opts]
chk(len(labels) > 0 and '(recommended)' in labels[0],
    "slot [1] is the recommended answer",
    "slot [1] is not the recommended answer: %r" % (labels[:1],))
chk(sum('(recommended)' in l for l in labels) == 1,
    "exactly ONE option is marked (recommended)",
    "%d options marked (recommended) — must be exactly 1" % sum('(recommended)' in l for l in labels))
for idx, want in ((1, 'skip'), (2, 'defer'), (3, 'out of scope')):
    got = labels[idx].lower() if len(labels) > idx else ''
    chk(want in got, "slot [%d] is %s" % (idx + 1, want.title()),
        "slot [%d] is %r, expected %s" % (idx + 1, got, want))

# Skip must OWN a slot — it is what Esc used to mean, and Esc no longer means it.
chk(any(l.lower().strip() == 'skip' for l in labels),
    "Skip owns a real option slot (it can no longer ride Esc)",
    "Skip has no slot — Esc now ends the walk, so Skip would be unreachable")

for n, (label, desc) in enumerate(opts, 1):
    assert_keterangan("canonical", n, label, desc)

# mandated FIELDS present as slots in the recommended option's description
d1 = opts[0][1] or ''
for needle, name in (('High-stakes', 'the high-stakes business+P1 marker'),
                     ('business AND P1', 'the gate that scopes the high-stakes marker'),
                     ('Sumber:', 'the citation field'),
                     ('Kalau salah', 'the fallback-if-wrong field'),
                     ('Confidence', 'the confidence field'),
                     ('mendarat', 'the destination disclosure')):
    chk(needle in d1, "slot [1] description carries %s" % name,
        "slot [1] description has NO slot for %s — a model copies the template, not the prose" % name)

# the panel above the question carries the marker in its OTHER mandated position
panel = full[:full.index('question:')]
chk('High-stakes business OQ' in panel and 'ONLY when category: business AND P1' in panel,
    "panel banner carries the high-stakes marker, gated to business+P1",
    "panel banner lost the high-stakes marker or its gate")
sys.exit(RC_[0])
PY
[ $? -eq 0 ] || FAILED=1

echo "== 2. the no-recommendation template is written out, not deferred =="

python3 - "$IW" <<'PY'
import sys, os
sys.path.insert(0, os.environ['OQLIB'])
from oqlib import *
src = open(sys.argv[1], encoding='utf-8').read()
norec = block_after(src, '#### When there is NO recommendation')
opts = options_of(norec)

chk(0 < len(opts) <= 4,
    "no-recommendation template declares %d options (<= cap; the answer slot is unspent)" % len(opts),
    "no-recommendation template declares %d options" % len(opts))
labels = [l.lower() for l, _ in opts]
chk(not any('(recommended)' in l for l in labels),
    "no-recommendation template marks NOTHING as recommended",
    "an option is marked (recommended) with no citation-probed recommendation — fabrication")
for want in ('skip', 'defer', 'out of scope'):
    chk(any(want in l for l in labels), "no-recommendation template offers %s" % want.title(),
        "no-recommendation template is missing %s" % want)
for n, (label, desc) in enumerate(opts, 1):
    assert_keterangan("no-recommendation", n, label, desc)

q = norec[norec.index('question:'):norec.index('options:')]
chk('rekomendasi' in q.lower() or 'recommendation' in q.lower(),
    "no-recommendation question text says why there is no recommendation",
    "no-recommendation question text does not explain the missing recommendation")
# D5's shortcut must NOT be advertised here — there is no recommendation for it to compose with
chk('tidak mengubah apa pun' in q or 'nothing to accept' in q.lower(),
    "no-recommendation shape states that a bare destination override changes nothing",
    "no-recommendation shape advertises the bare-override shortcut with no recommendation behind it")
sys.exit(RC_[0])
PY
[ $? -eq 0 ] || FAILED=1

echo "== 3. Esc ends the WALK; Skip is a slot; no typed sentinel exists =="

python3 - "$IW" "$HR" "$PC" <<'PY'
import sys, os
sys.path.insert(0, os.environ['OQLIB'])
from oqlib import *
iw  = open(sys.argv[1], encoding='utf-8').read()
hr  = open(sys.argv[2], encoding='utf-8').read()
pcp = open(sys.argv[3], encoding='utf-8').read()

# The Step-2b SLOT table only — scoped deliberately: the later per-action transition table also
# has an Esc row, and a whole-file row scan would let a broken slot table hide behind it.
slot_tbl = iw[iw.index('| Slot | Carries | Notes |'):]
slot_tbl = slot_tbl[:slot_tbl.index('\n\n')]
rows = dict((m.group(1).strip(), m.group(2).strip().lower())
            for m in re.finditer(r'^\|\s*\*?\*?([^|*]+?)\*?\*?\s*\|\s*(.*?)\s*\|', slot_tbl, re.M))
chk(len(rows) >= 6, "slot table publishes %d rows (4 slots + Other + Esc)" % len(rows),
    "slot table publishes only %d rows" % len(rows))
esc = rows.get('Esc', '')
chk('end the walk' in esc, "slot table: Esc = end the walk",
    "slot table: Esc means %r — it must end the walk" % esc)
chk('skip' not in esc, "slot table: Esc does NOT mean skip-one-item",
    "slot table: Esc still carries Skip semantics")
chk('skip' in rows.get('[2]', '').lower() or 'skip' in rows.get('`[2]`', '').lower(),
    "slot table: slot [2] is Skip",
    "slot table: slot [2] is %r — Skip must own a slot" % rows.get('`[2]`', rows.get('[2]', '')))
chk('answer' in rows.get('*Other*', rows.get('Other', '')),
    "slot table: Other is the free-text answer channel",
    "slot table: Other is not specified as the answer-capture channel")

# the precedent this is consistent with must still say what we claim it says
chk("Cancel rides the built-in" in hr and "Esc escape" in hr,
    "precedent holds: halt-recovery reads Esc as cancel-the-activity",
    "halt-recovery no longer reads Esc as cancel — the consistency claim has rotted")
chk("Cancel chain" in pcp and "Esc escape" in pcp,
    "precedent holds: propose-and-confirm reads Esc as cancel-the-activity",
    "propose-and-confirm no longer reads Esc as cancel — the consistency claim has rotted")
chk('halt-recovery.md' in iw and 'propose-and-confirm-prompt.md' in iw,
    "Step 2b cites both precedent surfaces for the Esc reading",
    "Step 2b asserts a plugin-wide Esc meaning without citing the precedents")

# NO typed end-the-walk sentinel may appear in ANY prompt block a model copies.
for heading, name in (('#### The prompt, verbatim', 'full shape'),
                      ('#### When there is NO recommendation', 'no-recommendation shape')):
    blk = block_after(iw, heading)
    chk('STOP' not in blk and 'BERHENTI' not in blk,
        "%s: no typed end-the-walk sentinel in the prompt" % name,
        "%s: a typed sentinel survives — it would swallow a legitimate answer" % name)
    q = blk[blk.index('question:'):blk.index('options:')]
    chk('Esc' in q, "%s: Esc is stated in the question text (discoverable)" % name,
        "%s: Esc semantics are folklore — not in the question text" % name)
    chk('Skip' in q, "%s: Skip is stated in the question text" % name,
        "%s: Skip is folklore — not in the question text" % name)
    chk('Other' in q, "%s: the Other free-text channel is stated in the question text" % name,
        "%s: Other channel undocumented in the question text" % name)
    chk('walk' in q.lower(), "%s: the question text says what Esc does to the WALK" % name,
        "%s: the question text never distinguishes ending the walk from skipping an item" % name)

# the deletion is RECORDED so a future author does not reintroduce it
chk('would silently swallow a legitimate answer' in iw or 'swallow a legitimate answer' in iw,
    "the sentinel's deletion is justified in-file (regression guard)",
    "nothing records WHY the typed sentinel was removed — it will come back")
sys.exit(RC_[0])
PY
[ $? -eq 0 ] || FAILED=1

# the instruction that told the human to TYPE a sentinel must be gone everywhere
if grep -rqF 'ketik persis' "$P/skills/resolve-oq"; then
  fail "a 'type this token exactly' sentinel instruction survives in the resolve-oq tree"
else
  ok "no 'ketik persis <token>' sentinel instruction anywhere in resolve-oq"
fi

echo "== 4. the Other parse order — a bare destination override composes with the answer =="

python3 - "$IW" <<'PY'
import sys, os
sys.path.insert(0, os.environ['OQLIB'])
from oqlib import *
src = open(sys.argv[1], encoding='utf-8').read()
i = src.index('#### Reading the "Other" free text')
j = src.index('**Per-action state transitions', i)
sec = src[i:j]

def pos(needle):
    return sec.index(needle) if needle in sec else -1

p_over = pos('Destination override FIRST')
p_ans  = pos('Non-empty remainder is the answer')
p_bare = pos('Empty remainder after a bare override')
chk(p_over >= 0 and p_ans >= 0 and p_bare >= 0,
    "the three parse branches are all specified",
    "a parse branch is missing (override=%d answer=%d bare=%d)" % (p_over, p_ans, p_bare))
chk(0 <= p_over < p_ans < p_bare,
    "parse ORDER is override -> remainder-as-answer -> bare-override-composes",
    "parse order is wrong: override=%d answer=%d bare=%d" % (p_over, p_ans, p_bare))

# D5: the bare override must ACCEPT the recommendation, not fall through to Skip
bare = sec[p_bare:]
chk('accept the RECOMMENDED answer' in bare or 'accept the recommended answer' in bare.lower(),
    "a bare '-> <file>.md' accepts the RECOMMENDED answer (D5)",
    "a bare destination override does not compose with the recommendation — an accepted answer is discarded")
chk('Action `A`' in bare or 'action `A`' in bare,
    "the bare-override branch records action A (a real resolution)",
    "the bare-override branch records no resolution action")
chk('no-recommendation shape' in bare and 'nothing to accept' in bare,
    "carve-out: with no recommendation a bare override changes nothing (never a guess)",
    "no carve-out for a bare override when there is no recommendation to accept")
# no sentinel branch may precede the parse
chk('Sentinel first' not in sec,
    "no sentinel branch in the parse order",
    "a sentinel branch survives in the Other parse order")
# an empty Other must still narrate, not silently no-op
chk('narrate' in sec.lower(),
    "every non-answer Other outcome is narrated, not a silent no-op",
    "an Other branch resolves to a silent no-op")
sys.exit(RC_[0])
PY
[ $? -eq 0 ] || FAILED=1

echo "== 5. the follow-up prompts — the only prompts that collect RECORDED state =="

python3 - "$IW" <<'PY'
import sys, os
sys.path.insert(0, os.environ['OQLIB'])
from oqlib import *
src = open(sys.argv[1], encoding='utf-8').read()

# ---- Defer: ONE call, TWO questions (the 4-option cap is per QUESTION, not per call)
defer = block_after(src, '**If `Defer`**')
chk(defer.lstrip().startswith('questions:'),
    "Defer follow-up is ONE AskUserQuestion CALL (a `questions:` array)",
    "Defer follow-up is not specified as a single multi-question call")
qs = re.split(r'^\s*-\s*question:', defer, flags=re.M)[1:]
chk(len(qs) == 2,
    "Defer follow-up carries exactly 2 questions (sub-target + reason) in that one call",
    "Defer follow-up carries %d questions — expected 2" % len(qs))

names = ('defer_to sub-target', 'defer reason')
for n, (q, name) in enumerate(zip(qs, names), 1):
    chk('header:' in q, "Defer Q%d (%s) has a header" % (n, name),
        "Defer Q%d (%s) has no header" % (n, name))
    body = q.split('header:')[0]
    chk(len(body.strip()) > 40, "Defer Q%d (%s) states the actual question, not a bare code" % (n, name),
        "Defer Q%d (%s) question text is too thin to answer from" % (n, name))
    opts = options_of(q)
    chk(0 < len(opts) <= 4, "Defer Q%d (%s) declares %d options (<= 4 per question)" % (n, name, len(opts)),
        "Defer Q%d (%s) declares %d options — over the per-question cap" % (n, name, len(opts)))
    for k, (label, desc) in enumerate(opts, 1):
        assert_keterangan("Defer Q%d" % n, k, label, desc)

q1_labels = [l.lower() for l, _ in options_of(qs[0])]
chk('stakeholder' in q1_labels and 'binding' in q1_labels,
    "Defer Q1 offers exactly the two schema values stakeholder / binding",
    "Defer Q1 labels are %r — must be the defer_to schema values" % q1_labels)
chk('greenfield' in defer or 'OMIT this whole entry' in defer,
    "Defer Q1 is marked brownfield-only (omitted in greenfield)",
    "Defer Q1 is unconditional — greenfield would be offered a binding target that never runs")

# Q2's canned reasons must not lose the who/when the vault entry mandates
q2_descs = ' '.join(d or '' for _, d in options_of(qs[1])).lower()
chk('other' in q2_descs, "Defer Q2 options route PIC/date specifics to Other",
    "Defer Q2 canned reasons swallow the who/when with no route to free text")

after = src[src.index('**If `Defer`**'):][:4000]
# phrasing-agnostic: a negation applied to "defaulted or derived", plus the invariant it breaches
chk(re.search(r'\b(never|neither|not)\b[^.]{0,80}\bdefault(ed)?\b[^.]{0,40}\bderived\b', after, re.I)
    and 'invariant-#5' in after,
    "the Defer follow-up's values may never be defaulted or derived (invariant #5)",
    "nothing forbids defaulting defer_to / deferred_reason")
chk('abandons the Defer' in after[:4000],
    "Esc on the Defer follow-up abandons it — no canned reason substituted",
    "Esc on the Defer follow-up has no specified outcome")

# ---- Out of scope: ONE call, one question, real keterangan
oos = block_after(src, '**If `Out of Scope`**')
oopts = options_of(oos)
chk(0 < len(oopts) <= 4, "OOS follow-up declares %d options (<= 4)" % len(oopts),
    "OOS follow-up declares %d options" % len(oopts))
chk('question:' in oos and 'header:' in oos,
    "OOS follow-up carries the question text + a header",
    "OOS follow-up is not a specified prompt")
for k, (label, desc) in enumerate(oopts, 1):
    assert_keterangan("OOS", k, label, desc)
oos_after = src[src.index('**If `Out of Scope`**'):][:4000]
chk('never' in oos_after and 'invariant-#5' in oos_after,
    "the OOS rationale may never be defaulted or derived (invariant #5)",
    "nothing forbids inventing an out_of_scope_reason")
sys.exit(RC_[0])
PY
[ $? -eq 0 ] || FAILED=1

echo "== 6. the prompt budget + the ONE-prompt rail =="

python3 - "$IW" <<'PY'
import sys, os
sys.path.insert(0, os.environ['OQLIB'])
from oqlib import *
src = open(sys.argv[1], encoding='utf-8').read()
i = src.index('**Prompt budget per OQ')
sec = src[i:i + 1600]
rows = re.findall(r'^\|\s*(.+?)\s*\|\s*\*\*(\d)\*\*', sec, re.M)
budget = {}
for path, n in rows:
    budget[path.lower()] = int(n)
chk(len(budget) >= 5, "prompt budget publishes %d paths" % len(budget),
    "prompt budget publishes only %d paths" % len(budget))
def find(sub):
    return next((v for k, v in budget.items() if sub in k), None)
for sub, want, name in (('answer', 1, 'Answer'), ('skip', 1, 'Skip'),
                        ('end the walk', 1, 'end the walk'),
                        ('defer', 2, 'Defer'), ('out of scope', 2, 'Out of scope')):
    got = find(sub)
    chk(got == want, "budget: %s costs %d prompt(s)" % (name, want),
        "budget: %s costs %r, expected %d" % (name, got, want))
chk('per QUESTION, not per CALL' in src,
    "the per-question/per-call distinction is stated (why Defer stays at 2)",
    "nothing states that the 4-option cap is per question — Defer will regress to 3")
# the two round trips that were removed must not be re-specifiable
for needle, what in (('Ask the user for the answer', 'a separate answer prompt'),
                     ('ask user to confirm or override', 'a separate destination prompt'),
                     ('This OQ looks cross-cutting', 'a separate cross-cutting prompt')):
    chk(needle not in src, "round trip removed: %s is gone" % what,
        "%s survives — the collapse is undone" % what)
sys.exit(RC_[0])
PY
[ $? -eq 0 ] || FAILED=1

has "$IW" "ONE \`AskUserQuestion\` per OQ" && ok "the ONE-prompt rail is stated in the step heading" || fail "ONE-prompt rail unstated"
has "$IW" "picking an option IS answering" && ok "the merge is stated: choosing = answering" || fail "the action/answer merge is unstated"
has "$IW" "That disclosure is what makes the old \"confirm the destination?\" prompt unnecessary" \
  && ok "destination-by-disclosure rationale recorded" || fail "destination disclosure rationale missing"
has "$IW" "the ONE sanctioned second prompt on this path" \
  && ok "Defer/OOS keep their reason prompt (invariant #5: no invented state)" \
  || fail "a minority path lost its reason prompt — state would have to be invented"

echo "== 7. the shape has exactly ONE normative home =="

python3 - "$RC" <<'PY'
import sys, os
sys.path.insert(0, os.environ['OQLIB'])
from oqlib import *
src = open(sys.argv[1], encoding='utf-8').read()
i = src.index('## AskUserQuestion presentation')
j = src.index('\n## ', i + 10)
sec = src[i:j]

# the duplicate specification must be GONE: no slot list, no option template, no Esc semantics
chk('```' not in sec,
    "recommendation-context no longer carries a prompt/slot code block",
    "recommendation-context still restates the prompt shape in a code block")
chk(not re.search(r'^\s*\[\d\]\s', sec, re.M),
    "recommendation-context enumerates no [N] slots",
    "recommendation-context still enumerates slot numbers — two normative homes")
# naming Esc as "owned by Step 2b" is a POINTER and allowed; stating what it DOES is a
# second normative home and is not.
ESC_SEMANTICS = ('Esc =', 'Esc  =', 'Esc →', 'Esc  →', 'ends the walk', 'end the walk',
                 'Esc cancels', 'Esc: ')
chk(not any(p in sec for p in ESC_SEMANTICS),
    "recommendation-context points at Esc without restating its semantics",
    "recommendation-context restates what Esc DOES — a second normative home that can drift")
chk('CANONICAL for this prompt' in sec and 'not restated here' in sec,
    "recommendation-context declares interactive-walk canonical AND says it does not restate it",
    "recommendation-context does not point at a single canonical home")
chk('**ONE prompt per OQ.**' in sec, "recommendation-context agrees: one prompt per OQ",
    "recommendation-context does not state ONE prompt per OQ")

# what it DOES still own: how the recommendation + the alternatives are built
chk('NEVER left blank' in src and 'fabricated citation' in src,
    "recommend-mode keeps its alternative-grounding rail (never blank, never fabricated)",
    "the alternative-grounding rail was lost when the slot was cut")
chk('question text' in sec and 'Alternatif' in sec,
    "recommendation-context routes the alternatives into the question text",
    "recommendation-context does not say where the alternatives now live")
chk('do NOT take a slot' in sec or 'does NOT take a slot' in sec,
    "recommendation-context states the alternatives cost no slot",
    "recommendation-context still spends a slot on an alternative")
sys.exit(RC_[0])
PY
[ $? -eq 0 ] || FAILED=1

echo "== 8. language precedence covers EVERYTHING human-facing, not just descriptions =="

python3 - "$IW" <<'PY'
import sys, os
sys.path.insert(0, os.environ['OQLIB'])
from oqlib import *
src = open(sys.argv[1], encoding='utf-8').read()
i = src.index('#### The prompt, verbatim')
caveat = src[i:src.index('```', i)]
low = caveat.lower()
for needle, name in (('question body', 'the question body'),
                     ('bullet', 'the question bullets'),
                     ('narration', 'the Step-2c narration'),
                     ('description', 'the option descriptions'),
                     ('label', 'the option labels')):
    chk(needle in low, "language precedence scoped to %s" % name,
        "language precedence does NOT cover %s — an English user gets hardcoded Indonesian" % name)
chk('precedence' in low and 'output-language.md' in caveat,
    "the caveat cites the canonical precedence rule",
    "the caveat asserts a language policy without citing output-language.md")
chk('default rendering' in low or 'not a fixed' in low,
    "the Indonesian strings are declared a DEFAULT rendering, not a string catalog",
    "the Indonesian strings read as a fixed catalog — precedence rule 2 cannot apply")
chk('Tier-1' in caveat,
    "Tier-1 structural tokens are pinned English inside the localized prompt",
    "Tier-1 token carve-out lost")
sys.exit(RC_[0])
PY
[ $? -eq 0 ] || FAILED=1

echo "== 9. the derive contract is unchanged (exact strings — machine-parsed) =="

has "$IW" '"event":"oq-resolved","id":"OQ-XXX","at":"<iso>","action":"A"'     && ok "Answer  -> oq-resolved / action A"      || fail "Answer derive args changed"
has "$IW" '"event":"oq-deferred","id":"OQ-XXX","at":"<iso>","action":"B"'     && ok "Defer   -> oq-deferred / action B"      || fail "Defer derive args changed"
has "$IW" '"event":"oq-out-of-scope","id":"OQ-XXX","at":"<iso>","action":"C"' && ok "OOS     -> oq-out-of-scope / action C"  || fail "Out-of-scope derive args changed"
has "$IW" '{"open_questions":{"OQ-XXX":{"defer_to":"stakeholder"}}}'          && ok "Defer patch: defer_to stakeholder"      || fail "stakeholder defer patch changed"
has "$IW" '{"open_questions":{"OQ-XXX":{"defer_to":"binding"}}}'              && ok "Defer patch: defer_to binding"          || fail "binding defer patch changed"
has "$IW" "are the recorded contract — they are NOT the slot" \
  && ok "slot numbers explicitly separated from the recorded action letters" \
  || fail "nothing stops an implementer emitting action:\"1\" after the renumber"
if grep -qE '"event":[^}]*"action":"[0-9]"' "$IW" "$SK" "$RC" "$BM"; then
  fail "a numeric \"action\" value leaked into a derive --event payload"
else
  ok "no numeric \"action\" in any derive payload — letters only"
fi
grep -qF '"action":"1"' "$IW" \
  && ok "the action:\"1\" counter-example is spelled out for implementers" \
  || fail "no explicit counter-example warning against action:\"1\""

# the transition table must route the NEW slots, and Skip must not end the walk
python3 - "$IW" <<'PY'
import sys, os
sys.path.insert(0, os.environ['OQLIB'])
from oqlib import *
src = open(sys.argv[1], encoding='utf-8').read()
i = src.index('| Prompt slot | Action |')
tbl = src[i:src.index('\n\n', i)]
rows = [r for r in tbl.splitlines() if r.startswith('|')][2:]
def row_with(sub):
    return next((r for r in rows if sub in r), '')
skip = row_with('D — Skip')
chk('`[2]`' in skip, "transition table: Skip is slot [2]",
    "transition table: Skip is not routed to slot [2] (%r)" % skip[:70])
chk('no derive run' in skip and 'walk continues' in skip.lower(),
    "transition table: Skip runs no derive AND the walk continues",
    "transition table: Skip does not continue the walk")
esc = row_with('*Esc*')
chk('end the walk' in esc and 'Step 3' in esc,
    "transition table: Esc ends the walk and jumps to Step 3",
    "transition table: Esc row missing or wrong (%r)" % esc[:70])
ans = row_with('A — Answer')
chk('override' in ans.lower(),
    "transition table: the bare destination override routes to action A",
    "transition table: the bare override has no Answer route")
chk(not any('STOP' in r for r in rows),
    "transition table: no sentinel row",
    "transition table: a sentinel row survives")
sys.exit(RC_[0])
PY
[ $? -eq 0 ] || FAILED=1

echo "== 10. cross-surface consistency (SKILL.md / binding-mode / --auto) =="

python3 - "$SK" <<'PY'
import sys, os
sys.path.insert(0, os.environ['OQLIB'])
from oqlib import *
src = open(sys.argv[1], encoding='utf-8').read()
i = src.index('## Resolution outcomes')
sec = src[i:src.index('\n## ', i + 10)]
rows = [r for r in sec.splitlines() if r.startswith('|')][2:]
def row_with(sub):
    return next((r for r in rows if sub in r), '')
chk('`[2]`' in row_with('**Skip**'), "SKILL.md outcome table: Skip is slot [2]",
    "SKILL.md outcome table: Skip is not slot [2]")
chk('`[3]`' in row_with('**Defer**'), "SKILL.md outcome table: Defer is slot [3]",
    "SKILL.md outcome table: Defer is not slot [3]")
chk('`[4]`' in row_with('**Out of Scope**'), "SKILL.md outcome table: Out of Scope is slot [4]",
    "SKILL.md outcome table: Out of Scope is not slot [4]")
esc_row = row_with('**Esc**')
chk('end the walk' in esc_row.lower() or 'jump to Step 3' in esc_row,
    "SKILL.md outcome table: Esc ends the walk",
    "SKILL.md outcome table: Esc does not end the walk")
for letter in ('| `A` |', '| `B` |', '| `C` |'):
    chk(letter in sec, "SKILL.md carries action letter %s" % letter.strip('| `'),
        "SKILL.md lost action letter %s" % letter.strip('| `'))
chk('4-action menu' not in src, "SKILL.md no longer routes to the pre-collapse 4-action menu",
    "SKILL.md still routes to the pre-collapse 4-action menu")
chk('per question' in src.lower(),
    "SKILL.md states the option cap is per question",
    "SKILL.md does not state the per-question cap — the Defer follow-up will regress")
chk('no typed `STOP` sentinel' in src or 'no typed' in src,
    "SKILL.md records that no typed sentinel exists",
    "SKILL.md does not record the sentinel deletion")
sys.exit(RC_[0])
PY
[ $? -eq 0 ] || FAILED=1

has "$BM" "The recorded \`action\` letters are unchanged" \
  && ok "--binding propagated-OQ walk keeps the same derive contract" \
  || fail "binding-mode does not pin the derive contract under the collapse"
grep -qF 'STOP' "$BM" && fail "a typed sentinel survives in binding-mode" || ok "binding-mode carries no typed sentinel"

# The propagated walk drops Defer, so its enumeration must be CONTIGUOUS from [1] and must not
# claim a slot number the shortened list cannot render. A prose mention of "[3] dropped" next to a
# list that still shows "[4]" is exactly the ambiguity this catches.
python3 - "$BM" <<'PY'
import sys, os
sys.path.insert(0, os.environ['OQLIB'])
from oqlib import *
src = open(sys.argv[1], encoding='utf-8').read()
i = src.index('**Walk Open Questions table.**')
sec = src[i:src.index('\n4. ', i)]
# only the enumerated option list itself (bullet lines), not prose that names a slot number
slots = [int(n) for n in re.findall(r'^\s*-\s*`\[(\d)\]`', sec, re.M)]
chk(bool(slots), "binding-mode enumerates the propagated walk's slots",
    "binding-mode does not enumerate the propagated walk's slots")
chk(slots == list(range(1, len(slots) + 1)),
    "binding-mode slots are contiguous from [1] (%s)" % slots,
    "binding-mode slots are %s — a dropped slot left a gap the platform cannot render" % slots)
chk('Defer' in sec and 'dropped' in sec,
    "binding-mode states Defer is the dropped affordance",
    "binding-mode does not say which affordance the propagated walk drops")
chk('Skip' in sec and 'Out of scope' in sec,
    "binding-mode's propagated walk still offers Skip and Out of scope",
    "binding-mode's propagated walk lost Skip or Out of scope")
chk('leave the remaining slot empty' not in sec,
    "binding-mode no longer describes a phantom spare slot",
    "binding-mode still tells the model to 'leave the remaining slot empty' — nothing remains")
chk('Esc' in sec and 'end the walk' in sec,
    "binding-mode's propagated walk uses the same Esc semantics",
    "binding-mode's propagated walk does not state the Esc semantics")
sys.exit(RC_[0])
PY
[ $? -eq 0 ] || FAILED=1

echo "== 10b. an Esc-terminated round is expressible in the self-check + summary =="

python3 - "$IW" "$SK" <<'PY'
import sys, os
sys.path.insert(0, os.environ['OQLIB'])
from oqlib import *
iw = open(sys.argv[1], encoding='utf-8').read()
sk = open(sys.argv[2], encoding='utf-8').read()

# Step 4 must not fire a false failure on the OQs the walk never reached.
i = iw.index('## Step 4 — Self-check before exit')
step4 = iw[i:iw.index('\n## ', i + 10)]
drop = next((l for l in step4.splitlines() if 'silently dropped' in l), '')
chk('presented' in drop,
    "Step 4's no-drop check is scoped to OQs that were PRESENTED",
    "Step 4 fails on an Esc-terminated round: unreached OQs read as silently dropped")
chk('unreached' in drop.lower() or 'never presented' in drop.lower(),
    "Step 4 names the unreached bucket explicitly",
    "Step 4 gives unreached OQs no name — a model will invent an outcome for them")
chk('invent' in drop.lower(),
    "Step 4 forbids inventing an outcome for unreached OQs",
    "nothing stops Step 4 back-filling an outcome to satisfy itself")

# Step 5 must have a bucket for them, distinct from skipped and from out-of-scope-this-round.
j = iw.index('## Step 5 — Present summary')
step5 = iw[j:]
chk('unreached' in step5.lower(),
    "Step 5 reports an 'unreached' bucket",
    "Step 5 has no bucket for OQs the walk never reached")
chk('never presented' in step5.lower() or 'belum sempat ditanyakan' in step5,
    "Step 5 glosses what unreached MEANS",
    "Step 5's unreached bucket is a bare count with no keterangan")
chk('never merged' in step5 or 'different thing' in step5,
    "Step 5 keeps unreached distinct from the scope-filtered bucket",
    "Step 5 conflates 'walk ended early' with 'filtered out by scope'")
chk('unreached' in sk.lower(),
    "SKILL.md's Step 5 summary line carries the unreached bucket too",
    "SKILL.md's summary line cannot express an Esc-terminated round")
sys.exit(RC_[0])
PY
[ $? -eq 0 ] || FAILED=1
has "$AM" "the ONE per-OQ prompt" \
  && ok "--auto table names the single prompt" || fail "--auto table still describes the multi-prompt walk"
has "$AM" "recorded state may never be defaulted or derived (invariant #5)" \
  && ok "--auto: the Defer/OOS follow-ups are never auto-defaulted" \
  || fail "--auto: nothing stops the follow-ups being defaulted under --auto"
has "$AM" "DELIBERATE chain-context divergence" \
  && ok "--auto scope-default rationale preserved" || fail "--auto scope-default annotation lost"
has "$P/skills/resolve-oq/references/auto-memory-handoff.md" \
  "High-stakes business OQs (P1 + category: business) NEVER auto-accept" \
  && ok "high-stakes never auto-accepts (unchanged by the collapse)" || fail "auto-accept carve-out lost"

echo "== 11. high-stakes marker survives in BOTH positions =="

has "$RC" "High-stakes business OQ." \
  && ok "high-stakes warning text intact in recommendation-context" || fail "high-stakes warning text lost"
has "$RC" "AI recommendation is a starting point, not authority" \
  && ok "high-stakes wording verbatim ('starting point, not authority')" || fail "high-stakes wording altered"
has "$RC" "it carries it in BOTH positions" \
  && ok "high-stakes: collapse carries the marker in both positions (not moved)" \
  || fail "high-stakes marker was relocated rather than carried"
has "$IW" "rides BOTH the panel banner above AND the" \
  && ok "collapsed prompt mandates both marker positions" || fail "collapsed prompt mandates only one position"

echo "== 12. behavior fixture + skill version =="

FX="$ROOT/tests/skill-triggering/resolve-oq.test.md"
if [ -f "$FX" ]; then
  if grep -qF '[A] Answer / [B] Defer / [C] Out-of-scope / [D] Skip' "$FX"; then
    fail "skill-triggering fixture still asserts the pre-collapse [A]/[B]/[C]/[D] menu as correct"
  else
    ok "skill-triggering fixture updated off the pre-collapse letter menu"
  fi
  if grep -qF 'Defer option hidden (greenfield)' "$FX"; then
    fail "fixture still asserts Defer is hidden in greenfield (contradicts the ALWAYS-visible rail)"
  else
    ok "fixture: Defer stays visible in greenfield; only the sub-target question is conditional"
  fi
  grep -qF '"action": "A|B|C|D"' "$FX" \
    && fail "fixture still claims a 'D' changelog action — Skip emits no event" \
    || ok "fixture: Skip emits no changelog event (no bogus action D)"
  has "$FX" "Esc ends the walk" && ok "fixture covers Esc = end the walk" || fail "fixture has no Esc-ends-walk case"
  has "$FX" "ONE call, TWO questions" && ok "fixture covers the two-question Defer follow-up" || fail "fixture has no Defer follow-up case"
  has "$FX" "BARE override" && ok "fixture covers the bare destination override composing with the recommendation" || fail "fixture has no D5 case"
else
  fail "skill-triggering fixture missing: $FX"
fi

VER="$(python3 - "$SK" <<'PY'
import sys
fm = open(sys.argv[1], encoding='utf-8').read().split('---', 2)[1]
try:
    import yaml
    d = yaml.safe_load(fm)
    print(d.get('version', '?') if isinstance(d, dict) else 'NOTMAP')
except ImportError:
    for ln in fm.splitlines():
        if ln.strip().startswith('version:'):
            print(ln.split(':', 1)[1].strip())
PY
)"
case "$VER" in
  2.[0-8].*|1.*|"?"|NOTMAP|"") fail "resolve-oq version not bumped past 2.8.x (got $VER)" ;;
  *) ok "resolve-oq version bumped for the behavior change (got $VER)" ;;
esac

echo
if [ "$FAILED" -eq 0 ]; then echo "ALL OQ SINGLE-PROMPT PINS OK"; else echo "oq single-prompt pins FAILED"; fi
exit $FAILED
