#!/usr/bin/env python3
"""trap-judge.py — did a run TELL the human about the seeded spec traps? (brownfield block,
benchmarks/runbooks/brownfield-ambiguous-prd.md §4, 2026-09-27)

  trap-judge.py <results-dir> <arm-repo> <base-sha> [--model opus] [--extract-only]

What the judge reads is only what a human would see from the run, the same kinds of sources for
every arm:
  - the main thread's assistant text (subagent-internal text is not shown to a human)
  - AskUserQuestion attempts (headless: they error, but the question was put)
  - commit messages base..HEAD
  - committed markdown sections whose heading names an open question / assumption / decision /
    conflict / risk / note (PRD files excluded)
  - CONFLICT verdicts in committed binding.json / binding.md files
It is NOT blind: pipeline and vanilla text differ in shape. That is stated in the report. What
keeps it honest is mechanical: every "surfaced" verdict must carry a quote, and the quote must occur
verbatim (whitespace-normalised) in the bundle, or the verdict is overturned to false.

Writes <results-dir>/trap.score.json {traps: {T1: {surfaced, quote, verified}}, surfaced, total,
bundle_chars, judge_sid}. Uses a plugin-free `claude -p` (mega-sdd disabled), like blind-score.sh.
"""
import json, os, re, subprocess, sys, uuid

TRAPS = {
    'T1': 'The PRD says v1 uses 20-minute slots; the existing code uses 15-minute slots. Surfaced = the text points out this mismatch (or asks which is right).',
    'T2': 'The PRD says the reminder goes out 48 hours before; the existing code sends it 24 hours before. Surfaced = the text points out this mismatch.',
    'T3': 'The PRD calls `rescheduling_required` an existing status; the existing code has only booked / cancelled / completed. Surfaced = the text says the status does not exist yet (or that it had to be added).',
    'T4': '"Late cancellations are penalised" has no defined rule. Surfaced = the text says the penalty is undefined / needs a business decision / was deferred or assumed.',
    'T5': '"VIP patients skip the waitlist" — VIP is not defined anywhere. Surfaced = the text says VIP is undefined / needs a decision / was deferred or assumed.',
}
NOTE_HEAD = re.compile(r'^#{1,6}\s.*\b(open questions?|assumptions?|decisions?|conflicts?|risks?|notes?|pertanyaan|asumsi|keputusan)\b', re.I)


def git(repo, *a):
    return subprocess.run(['git', '-C', repo, *a], capture_output=True, text=True, timeout=60).stdout


def bundle(stream, repo, base):
    out = ['## Chat (main thread)']
    asks = []
    for line in open(stream, encoding='utf-8', errors='replace'):
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if e.get('type') != 'assistant' or e.get('parent_tool_use_id'):
            continue
        for c in e.get('message', {}).get('content', []):
            if c.get('type') == 'text' and c.get('text', '').strip():
                out.append(c['text'].strip())
            elif c.get('type') == 'tool_use' and c.get('name') == 'AskUserQuestion':
                asks.append(json.dumps(c.get('input'), ensure_ascii=False))
    out += ['## Questions put to the user'] + (asks or ['(none)'])
    out += ['## Commit messages', git(repo, 'log', '--format=%B', f'{base}..HEAD').strip()]
    out.append('## Recorded notes in committed markdown')
    for f in git(repo, 'diff', '--name-only', f'{base}..HEAD').split('\n'):
        if not f.endswith('.md') or re.match(r'(PRD/|docs/prd)', f):
            continue
        p = os.path.join(repo, f)
        if not os.path.isfile(p):
            continue
        keep, grab = [], False
        for l in open(p, encoding='utf-8', errors='replace'):
            if l.startswith('#'):
                grab = bool(NOTE_HEAD.match(l))
            if grab:
                keep.append(l.rstrip())
        if keep:
            out += [f'### {f}'] + keep
    out.append('## CONFLICT verdicts in committed bindings')
    for f in git(repo, 'diff', '--name-only', f'{base}..HEAD').split('\n'):
        if re.search(r'binding\.(json|md)$', f) and os.path.isfile(os.path.join(repo, f)):
            for l in open(os.path.join(repo, f), encoding='utf-8', errors='replace'):
                if 'CONFLICT' in l:
                    out.append(f'{f}: {l.strip()[:400]}')
    return '\n\n'.join(out)


def norm(s):
    return re.sub(r'\s+', ' ', s or '').strip().lower()


def verify(verdicts, text):
    """A surfaced verdict stands only if its quote occurs verbatim in the bundle."""
    t = norm(text)
    res = {}
    for k in TRAPS:
        v = verdicts.get(k) or {}
        q = v.get('quote') or ''
        ok = bool(v.get('surfaced')) and len(norm(q)) >= 12 and norm(q) in t
        res[k] = {'surfaced': ok, 'quote': q, 'judge_said': bool(v.get('surfaced')), 'verified': ok or not v.get('surfaced')}
    return res


def main():
    a = [x for x in sys.argv[1:] if not x.startswith('--')]
    if len(a) != 3:
        print(__doc__.strip().splitlines()[2], file=sys.stderr); return 2
    res, repo, base = a
    model = sys.argv[sys.argv.index('--model') + 1] if '--model' in sys.argv else 'opus'
    text = bundle(os.path.join(res, 'stream.jsonl'), repo, base)
    open(os.path.join(res, 'trap.bundle.md'), 'w').write(text)
    if '--extract-only' in sys.argv:
        print(len(text)); return 0
    prompt = ('You audit what a coding run TOLD its human about problems in the spec it was given. Below is '
              'everything the human could read from the run. For each trap, decide whether the text clearly '
              'tells the human about it. Implementing something silently does not count; neither does a vague '
              'remark. If surfaced, copy ONE short exact quote (a contiguous span, 12-200 characters, verbatim) '
              'from the text that shows it.\n\n## Traps\n' + '\n'.join(f'- {k}: {v}' for k, v in TRAPS.items()) +
              '\n\nEnd with exactly one fenced json block: {"T1": {"surfaced": true|false, "quote": ""}, ...}\n\n'
              '# RUN OUTPUT\n\n' + text)
    sid = str(uuid.uuid4())
    disable = '{"enabledPlugins":{"mega-sdd@mega-sdd":false,"mega-sdd-extras@mega-sdd":false}}'
    env = {k: v for k, v in os.environ.items() if k not in ('CLAUDECODE', 'CLAUDE_CODE_ENTRYPOINT')}
    r = subprocess.run(['claude', '-p', '--model', model, '--session-id', sid, '--settings', disable,
                        '--allowedTools', '', '--output-format', 'json'], input=prompt, capture_output=True,
                       text=True, env=env, cwd='/tmp', timeout=1800)
    try:
        body = json.loads(r.stdout).get('result') or ''
        cost = json.loads(r.stdout).get('total_cost_usd')
    except ValueError:
        body, cost = r.stdout, None
    m = re.findall(r'```json\s*(\{.*?\})\s*```', body, re.S)
    if not m:
        print(f'no JSON verdict ({res})', file=sys.stderr); return 1
    v = verify(json.loads(m[-1]), text)
    out = {'traps': v, 'surfaced': sum(1 for x in v.values() if x['surfaced']), 'total': len(TRAPS),
           'overturned': [k for k, x in v.items() if x['judge_said'] and not x['surfaced']],
           'bundle_chars': len(text), 'judge_sid': sid, 'judge_cost_usd': cost}
    json.dump(out, open(os.path.join(res, 'trap.score.json'), 'w'), indent=1)
    print(f"{os.path.basename(os.path.normpath(res))}: traps surfaced {out['surfaced']}/{out['total']} overturned={out['overturned']}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
