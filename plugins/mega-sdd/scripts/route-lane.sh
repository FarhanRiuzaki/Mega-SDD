#!/usr/bin/env bash
# route-lane.sh — pick the lane for a build request from OBSERVABLE signals.
# Deterministic, read-only (writes nothing, not even .mega-sdd/), zero model
# tokens. The front door runs it FIRST for a PRD/brief so a light task never
# walks into the pipeline by accident.
#
# Why (benchmarks/results/vanilla-ab, research/2026-09-27-vanilla-vs-megasdd-
# results.md): on greenfield PRDs vanilla Claude Code was 2.3–12x faster and
# 9–22x cheaper than the lite/classic pipeline with equal or better quality.
# The pipeline's claimed value (binding CONFLICT gate, OQ handling) needs
# existing code or an ambiguous spec to act on — neither exists in a clear
# greenfield PRD. So the pipeline is reserved for tasks that show those signals.
#
# Lanes (each one strictly adds to the one before):
#   direct    main session implements, tests, commits; no vault, no units,
#             no subagents, no .mega-sdd/ writes; ends with delivery-check.sh
#   assisted  direct + ONE batched ask for the spec's open business items
#             BEFORE coding (when it has any) + ONE blind review subagent over
#             the whole diff before the final commit
#   guarded   the spec pipeline (lite for a new PRD): vault, binding verdicts +
#             CONFLICT gate, units, bolts, review panel — only for an existing
#             vault or on request (--guarded); see the brownfield result below
#
# Signals (a signal fires on evidence, never on judgment):
#   guarded   vault_present     a mega-sdd vault already exists (delta/revision)
#   assisted  existing_code     >= CODE_MIN (10) git-tracked source files outside
#                               config/type stubs — an app, not a scaffold.
#                               (research/2026-09-27-brownfield-results.md)
#             spec_open_items   list items under an "Open questions" /
#                               "Pertanyaan terbuka" heading that are not
#                               "none / tidak ada / resolved", or inline TBD,
#                               TBC, TODO, ??, [OPEN], "to be decided/confirmed",
#                               "belum diputuskan/ditentukan/final"
#             security_surface  >= 2 distinct security words outside out-of-scope /
#                               negated lines (the review-panel
#                               signal-4 list: auth, password, payment, role …)
#             multi_flow        derive-project-scale.sh says "standard" (not xs)
# Open items do NOT buy the pipeline: on the clinic PRD (2 P1 + 4 P2 open
# questions) the lite pipeline matched vanilla's quality at 8.8x the cost. What
# an open business item needs is a human answer before coding — one batched
# ask — which the assisted lane gives at near-zero cost.
# Override (always wins, recorded as override): --lane=direct|assisted|guarded.
#
# Usage: route-lane.sh --cwd=<root> [--prd=<file> | --text=<brief>] [--lane=<l>]
#                      [--code-min=N]
# Prints ONE JSON line: {"lane","signals_fired","evidence","override"}.
# Exit 0 always on a readable request; 2 = usage.
set -u
CWD="$PWD"; PRD=""; TEXT=""; LANE=""; CODE_MIN=10
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}";;
  --prd=*) PRD="${arg#*=}";;
  --text=*) TEXT="${arg#*=}";;
  --lane=*) LANE="${arg#*=}";;
  --code-min=*) CODE_MIN="${arg#*=}";;
  -h|--help) sed -n '2,38p' "$0"; exit 0;;
  *) echo "route-lane: unknown arg $arg" >&2; exit 2;;
esac; done
case "$LANE" in ""|direct|assisted|guarded) ;; *) echo "route-lane: --lane must be direct|assisted|guarded" >&2; exit 2;; esac
[ -n "$PRD" ] && [ ! -f "$PRD" ] && { echo "route-lane: PRD not found: $PRD" >&2; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCALE='{}'
[ -n "$PRD" ] && SCALE="$(bash "$SCRIPT_DIR/derive-project-scale.sh" --prd="$PRD" 2>/dev/null | tail -1)"

python3 - "$CWD" "$PRD" "$TEXT" "$LANE" "$CODE_MIN" "$SCALE" <<'EOF'
import glob, json, os, re, subprocess, sys
cwd, prd, text, lane_flag, code_min, scale = sys.argv[1:7]
code_min = int(code_min)
fired, ev = [], {}

# vault = what derive-state routes on (state_probes.probe_vaults + _vault_docs; parity: test-lanes L11)
ANY = ('vault.json', '0[0-6]-*.md', 'context.md', 'vault.md', 'model.md', 'flows.md', 'constraints.md')
vaults = sorted({os.path.dirname(p) for rel, marks in (('.mega-sdd/vaults', ANY), ('docs/mega-sdd/vaults', ANY[:1]), ('vaults', ANY[:1]))
                 for m in marks for p in glob.glob(os.path.join(glob.escape(cwd), rel, '*', m))
                 if os.path.isfile(p) and not os.path.dirname(p).endswith('-bound')})
if vaults:
    fired.append('vault_present'); ev['vaults'] = [os.path.relpath(v, cwd) for v in vaults]

CODE = re.compile(r'\.(tsx?|jsx?|mjs|cjs|vue|svelte|php|py|rb|go|rs|java|kt|cs|swift|dart|scala|ex|exs)$')
SKIP = re.compile(r'(^|/)(node_modules|vendor|dist|build|\.next|\.mega-sdd)/|\.config\.[a-z]+$|\.d\.ts$|(^|/)next-env\.d\.ts$')
try:
    files = subprocess.run(['git', '-C', cwd, 'ls-files'], capture_output=True, text=True, check=True, timeout=30).stdout.split('\n')
except subprocess.TimeoutExpired:
    files = None                                            # a repo too big to list in 30 s is not a scaffold
except (OSError, subprocess.CalledProcessError):
    files = []                                              # not a git repo: nothing tracked yet
code = [f for f in files if CODE.search(f) and not SKIP.search(f)] if files is not None else None
ev['source_files'] = len(code) if code is not None else 'ls-files timed out'
if code is None or len(code) >= code_min:
    fired.append('existing_code')

body = text
if prd:
    body = open(prd, encoding='utf-8', errors='replace').read()
body = re.sub(r'```.*?```', '', body, flags=re.S)          # fenced examples are not claims
INLINE = re.compile(r'\bTBD\b|\bTBC\b|\bTODO\b|\?\?|\[OPEN\]|\bto be (decided|confirmed|determined)\b'
                    r'|\bbelum (diputuskan|ditentukan|final)\b', re.I)
OQ_HEAD = re.compile(r'^#{1,6}\s.*\b(open questions?|pertanyaan terbuka)\b', re.I)
NONE = re.compile(r'\b(tidak ada|none|n/a|nihil|resolved|terjawab)\b', re.I)
open_items, in_oq = [], False
for l in body.splitlines():
    if l.startswith('#'):
        in_oq = bool(OQ_HEAD.match(l))
        continue
    item = re.match(r'\s*([-*+]|\d+[.)])\s+(.*)', l)
    if in_oq and item and not NONE.search(item.group(2)):
        open_items.append(item.group(2).strip()[:120])
    elif INLINE.search(l):
        open_items.append(l.strip()[:120])
ev['open_items'] = len(open_items)
if open_items:
    fired.append('spec_open_items'); ev['open_items_sample'] = open_items[:3]

VOCAB = ("auth", "session", "token", "crypto", "password", "payment", "upload", "role", "permission",
         "access", "admin", "acl", "kata sandi", "sandi", "pembayaran", "unggah", "hak akses", "peran",
         "izin", "otorisasi", "autentikasi", "otentikasi", "persetujuan")
STEMS = ("authenticat", "authoriz", "oauth")
# an out-of-scope / negated line is not a security surface ("Di luar lingkup:
# autentikasi, panel admin" fired on the xs PRD); nor is a Non-goals section
NEG = re.compile(r'\b(di luar lingkup|out of scope|out-of-scope|non-goals?|tidak ada|tanpa|not in scope|no)\b', re.I)
NEG_HEAD = re.compile(r'^#{1,6}\s.*\b(out of scope|di luar lingkup|non-goals?)\b', re.I)
kept, skip = [], False
for l in body.splitlines():
    if l.startswith('#'):
        skip = bool(NEG_HEAD.match(l))
    if not skip and not NEG.search(l):
        kept.append(l)
low = '\n'.join(kept).lower()
words = sorted({w for w in VOCAB if re.search(r'(?<![a-z])' + re.escape(w).replace(r'\ ', r'\s+') + r's?(?![a-z])', low)}
               | {s for s in STEMS if s in low})
ev['security_words'] = words
if len(words) >= 2:
    fired.append('security_surface')
try:
    sc = json.loads(scale or '{}')
except ValueError:
    sc = {}
if sc.get('project_scale'):
    ev['project_scale'] = sc['project_scale']
    if sc['project_scale'] != 'xs':
        fired.append('multi_flow')

# existing code does NOT buy the pipeline (brownfield block: same 5/5 traps as vanilla at ~6x
# the cost). Only an existing vault — the user's own pipeline artefact — keeps it by default.
if 'vault_present' in fired:
    lane = 'guarded'
elif any(s in fired for s in ('existing_code', 'spec_open_items', 'security_surface', 'multi_flow')):
    lane = 'assisted'
else:
    lane = 'direct'
out = {'lane': lane_flag or lane, 'signals_fired': fired, 'evidence': ev,
       'override': ({'from': lane, 'to': lane_flag} if lane_flag and lane_flag != lane else None)}
print(json.dumps(out, ensure_ascii=False))
EOF
