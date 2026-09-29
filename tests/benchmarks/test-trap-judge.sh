#!/usr/bin/env bash
# trap-judge.py — the bundle holds only what a human sees (main-thread text, asks, commits, note
# sections, CONFLICT verdicts) and a "surfaced" verdict survives only with a verbatim quote.
# No claude process is started (--extract-only + the verify() function).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; J="$ROOT/benchmarks/scripts/trap-judge.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; err=0; fail() { echo "FAIL: $1"; err=1; }
R="$T/repo"; mkdir -p "$R" "$T/res"; git -C "$R" init -q; git -C "$R" config user.email t@t; git -C "$R" config user.name t
echo base > "$R/a.txt"; git -C "$R" add -A; git -C "$R" commit -qm base; BASE=$(git -C "$R" rev-parse HEAD)
mkdir -p "$R/PRD" "$R/notes"
printf '# PRD\n## Open questions\n- the PRD itself says slots are 20 minutes\n' > "$R/PRD/prd.md"
printf '# Build notes\n## Assumptions\n- VIP is not defined in the PRD, so VIP priority is deferred\n## Usage\n- run npm test\n' > "$R/notes/NOTES.md"
git -C "$R" add -A; git -C "$R" commit -qm $'feat: waitlist\n\nReminder lead kept at 24h; the PRD says 48h but v1 sends at 24h.'
cat > "$T/res/stream.jsonl" <<'J2'
{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"text","text":"Heads-up: the PRD claims 20-minute slots but the code uses 15-minute slots."}]}}
{"type":"assistant","parent_tool_use_id":"toolu_sub","message":{"content":[{"type":"text","text":"SUBAGENT: rescheduling_required does not exist in the enum"}]}}
{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"tool_use","name":"AskUserQuestion","input":{"questions":[{"question":"What is the late-cancellation penalty?"}]}}]}}
J2
python3 "$J" "$T/res" "$R" "$BASE" --extract-only >/dev/null || fail "extract-only exits 0"
B="$T/res/trap.bundle.md"
grep -q '20-minute slots but the code uses 15' "$B" || fail "main-thread text is in the bundle"
grep -q 'SUBAGENT' "$B" && fail "subagent-internal text must not be in the bundle"
grep -q 'late-cancellation penalty' "$B" || fail "AskUserQuestion attempts are in the bundle"
grep -q 'the PRD says 48h but v1 sends at 24h' "$B" || fail "commit messages are in the bundle"
grep -q 'VIP is not defined in the PRD' "$B" || fail "note sections of committed markdown are in the bundle"
grep -q 'run npm test' "$B" && fail "non-note sections are not in the bundle"
grep -q 'the PRD itself says slots' "$B" && fail "PRD files are excluded"
python3 - "$J" "$B" <<'PY' || fail "verify(): quotes decide, not the judge's word"
import importlib.util, sys
s = importlib.util.spec_from_file_location('tj', sys.argv[1]); tj = importlib.util.module_from_spec(s); s.loader.exec_module(tj)
text = open(sys.argv[2]).read()
v = tj.verify({'T1': {'surfaced': True, 'quote': 'the PRD claims 20-minute slots but the code'},
               'T3': {'surfaced': True, 'quote': 'rescheduling_required does not exist in the enum'},
               'T4': {'surfaced': True, 'quote': 'a quote the judge made up entirely'},
               'T5': {'surfaced': True, 'quote': 'VIP'},
               'T2': {'surfaced': False, 'quote': ''}}, text)
assert v['T1']['surfaced'] is True, v['T1']
assert v['T3']['surfaced'] is False, 'subagent-only quote must be overturned'
assert v['T4']['surfaced'] is False, 'fabricated quote must be overturned'
assert v['T5']['surfaced'] is False, 'a quote under 12 chars is not evidence'
assert v['T2']['surfaced'] is False and v['T2']['verified'] is True
PY
[ $err -eq 0 ] && echo "PASS: trap-judge (bundle sources, quote verification)"
exit $err
