#!/usr/bin/env python3
"""p3-parallelism.py — per-unit timeline + actual concurrency of ONE headless arm.

Reads the arm's `stream.jsonl` (claude -p stream-json), its `git-log.txt` (written by
p0-extract-arm.sh) and the vault `units/_index.md` (depends_on DAG), and prints:

  1. one row per unit: dispatch → implementer end → first/last code commit →
     panel start/end → evidence commit, plus "ready_at" (all depends_on evidence
     written) and the delay between ready and dispatch;
  2. a time-weighted histogram of how many bolt-implementer agents were actually
     running concurrently across the bolt-stage (the honest "concurrency aktual");
  3. the wave clusters the controller actually used (dispatch bursts).

Deterministic; same inputs → same output. Owner amendment P3 #1
(research/2026-09-10-v8-autonomous-runbook.md §Amendemen P3).

usage: p3-parallelism.py <results-dir> <units-index.md> [--outage START END] [--json OUT]
"""
import json, re, sys, collections, datetime as dt

UNIT_RE = re.compile(r'\bU-\d{3}\b')
LENSES = ('spec-reviewer', 'security-reviewer', 'code-quality-reviewer',
          'standards-reviewer', 'design-reviewer', 'resolution-verifier')

def iso(ts):
    return dt.datetime.fromisoformat(ts.replace('Z', '+00:00')).astimezone(dt.timezone.utc)

def fmt(t):
    return t.strftime('%H:%M:%S') if t else '—'

def mins(a, b):
    return (b - a).total_seconds() / 60 if a and b else None

def parse_index(path):
    deps = {}
    for line in open(path, encoding='utf-8'):
        m = re.match(r'\|\s*(U-\d{3})\s*\|[^|]*\|[^|]*\|\s*([^|]*)\|', line)
        if m:
            deps[m.group(1)] = UNIT_RE.findall(m.group(2))
    return deps

def parse_gitlog(path):
    commits = []  # (ts, kind, units, subject)
    for line in open(path, encoding='utf-8'):
        parts = line.rstrip('\n').split(' ', 2)
        if len(parts) < 3:
            continue
        sha, ts, subj = parts
        t = iso(ts)
        m = re.match(r'([a-z]+)\((U-[A-Za-z0-9_,\- ]+)\):', subj)
        if m:
            commits.append((t, m.group(1), UNIT_RE.findall(m.group(2)), subj, 'code'))
        elif subj.startswith('chore(sdd): evidence'):
            commits.append((t, 'evidence', UNIT_RE.findall(subj), subj, 'evidence'))
        else:
            commits.append((t, 'other', UNIT_RE.findall(subj), subj, 'other'))
    commits.sort(key=lambda c: c[0])
    return commits

def main():
    args = sys.argv[1:]
    outage = None; jout = None
    if '--outage' in args:
        i = args.index('--outage'); outage = (iso(args[i+1]), iso(args[i+2])); del args[i:i+3]
    if '--json' in args:
        i = args.index('--json'); jout = args[i+1]; del args[i:i+2]
    rdir, index_path = args[0], args[1]
    deps = parse_index(index_path)
    commits = parse_gitlog(f'{rdir}/git-log.txt')

    tasks = {}          # task_id -> dict
    tool_ts = {}        # tool_use_id -> ts
    tool_input = {}     # tool_use_id -> (name, input)
    cur = None
    bash_gates = []     # (ts_start, ts_end, script, units)
    open_bash = {}
    with open(f'{rdir}/stream.jsonl', encoding='utf-8') as f:
        for line in f:
            try:
                e = json.loads(line)
            except Exception:
                continue
            t = e.get('type')
            if e.get('timestamp'):
                cur = iso(e['timestamp'])
            if t == 'assistant':
                for b in e['message'].get('content', []):
                    if b.get('type') == 'tool_use':
                        tool_ts[b['id']] = cur
                        tool_input[b['id']] = (b.get('name'), b.get('input', {}))
                        if b.get('name') == 'Bash':
                            cmd = b['input'].get('command', '')
                            names = set(re.findall(r'(?:^|[/\s"\'])((?:run|merge|derive|write|validate|build|resolve|check|query|render|detect)[a-z0-9\-]*\.sh)', cmd))
                            if re.search(r'p0_post\.sh|detect[-_]after', cmd):
                                names.add('detect-after-helper(p0_post.sh)')
                            if names:
                                open_bash[b['id']] = (cur, '+'.join(sorted(names)), sorted(set(UNIT_RE.findall(cmd))))
            elif t == 'user':
                for b in e['message'].get('content', []):
                    if b.get('type') == 'tool_result' and b.get('tool_use_id') in open_bash:
                        s, script, units = open_bash.pop(b['tool_use_id'])
                        bash_gates.append((s, cur, script, units))
            elif t == 'system':
                st = e.get('subtype')
                if st == 'task_started' and e.get('task_type') == 'local_agent':
                    tid = e['task_id']; tu = e.get('tool_use_id')
                    prompt = e.get('prompt', '') or ''
                    desc = e.get('description', '') or ''
                    units = sorted(set(UNIT_RE.findall(desc)) or set(UNIT_RE.findall(prompt[:400])))
                    tasks[tid] = dict(id=tid, start=tool_ts.get(tu, cur), end=None, status=None,
                                      desc=desc, sub=e.get('subagent_type', ''), units=units)
                elif st == 'task_updated' and e.get('task_id') in tasks:
                    p = e.get('patch', {})
                    if p.get('end_time'):
                        tasks[e['task_id']]['end'] = dt.datetime.fromtimestamp(p['end_time']/1000, dt.timezone.utc)
                    if p.get('status'):
                        tasks[e['task_id']]['status'] = p['status']
                elif st == 'task_notification' and e.get('task_id') in tasks:
                    tk = tasks[e['task_id']]
                    tk['status'] = tk['status'] or e.get('status')
                    if not tk['end']:
                        tk['end'] = cur

    def kind(tk):
        d = tk['desc'].lower(); s = tk['sub']
        if 'bolt-implementer' in s or d.startswith('implement'):
            return 'impl'
        if any(l in s for l in LENSES):
            return 'lens'
        if 'adversarial' in d:
            return 'adv'
        return 'other:' + (s or '?')

    impls = [tk for tk in tasks.values() if kind(tk) == 'impl' and tk['units']]
    lenses = [tk for tk in tasks.values() if kind(tk) == 'lens' and tk['units']]
    others = collections.Counter(kind(tk) for tk in tasks.values())

    units = sorted(set(deps) | {u for tk in impls for u in tk['units']})
    rows = {}
    for u in units:
        my_impl = sorted([tk for tk in impls if u in tk['units']], key=lambda k: k['start'])
        my_lens = sorted([tk for tk in lenses if u in tk['units']], key=lambda k: k['start'])
        code = [c for c in commits if c[4] == 'code' and u in c[2]]
        evid = [c for c in commits if c[4] == 'evidence' and u in c[2]]
        rows[u] = dict(
            unit=u, deps=deps.get(u, []),
            dispatches=[(tk['start'], tk['end'], tk['status']) for tk in my_impl],
            impl_start=my_impl[0]['start'] if my_impl else None,
            impl_end=max((tk['end'] for tk in my_impl if tk['end']), default=None),
            first_commit=code[0][0] if code else None,
            last_commit=code[-1][0] if code else None,
            n_code=len(code), kinds=collections.Counter(c[1] for c in code),
            panel_start=my_lens[0]['start'] if my_lens else None,
            panel_end=max((tk['end'] for tk in my_lens if tk['end']), default=None),
            n_lens=len(my_lens),
            evidence=evid[0][0] if evid else None,
        )
    # ready_at = max over deps of (evidence commit or panel_end fallback)
    for u, r in rows.items():
        rs = []
        for d in r['deps']:
            dr = rows.get(d)
            if not dr:
                continue
            rs.append(dr['evidence'] or dr['panel_end'] or dr['last_commit'])
        r['ready_at'] = max([x for x in rs if x], default=None) if r['deps'] else None

    first_dispatch = min((r['impl_start'] for r in rows.values() if r['impl_start']), default=None)
    last_code = max((r['last_commit'] for r in rows.values() if r['last_commit']), default=None)
    last_evid = max((r['evidence'] for r in rows.values() if r['evidence']), default=None)

    def rel(t):
        return f'{mins(first_dispatch, t):6.1f}' if t and first_dispatch else '     —'

    print(f'bolt-stage: first dispatch {fmt(first_dispatch)}Z · last code commit {fmt(last_code)}Z '
          f'({mins(first_dispatch, last_code):.1f} m gross) · last evidence {fmt(last_evid)}Z')
    if outage:
        print(f'outage window excluded from concurrency: {fmt(outage[0])}Z → {fmt(outage[1])}Z')
    print('other agents:', dict(others))
    print()
    print('unit   deps                     ready  disp   implEnd cmt1   cmtN   panel1 panelN evid   |  wait  impl  →cmt  panel  cmt→evid  n_disp status')
    for u in units:
        r = rows[u]
        d = r['dispatches']
        wait = mins(r['ready_at'], r['impl_start']) if r['ready_at'] and r['impl_start'] else None
        implm = mins(r['impl_start'], r['impl_end'])
        tocmt = mins(r['impl_start'], r['first_commit'])
        panel = mins(r['panel_start'], r['panel_end'])
        c2e = mins(r['last_commit'], r['evidence'])
        st = ','.join((x[2] or '?')[:4] for x in d)
        f = lambda v: f'{v:5.1f}' if v is not None else '    —'
        print(f"{u}  {','.join(r['deps']) or '—':24} {rel(r['ready_at'])} {rel(r['impl_start'])} {rel(r['impl_end'])} "
              f"{rel(r['first_commit'])} {rel(r['last_commit'])} {rel(r['panel_start'])} {rel(r['panel_end'])} {rel(r['evidence'])} | "
              f"{f(wait)} {f(implm)} {f(tocmt)} {f(panel)} {f(c2e)}   {len(d)}   {st}")

    # concurrency histogram (time-weighted), implementers only, excluding the outage window
    def histogram(intervals, t0, t1):
        pts = []
        for s, e in intervals:
            if not s or not e:
                continue
            pts.append((max(s, t0), 1)); pts.append((min(e, t1), -1))
        pts.sort()
        hist = collections.Counter(); cur_n = 0; last = t0
        for t, dlt in pts:
            if t > last:
                seg = (last, t)
                dur = (seg[1] - seg[0]).total_seconds() / 60
                if outage:
                    o0, o1 = outage
                    ov = max(0.0, (min(seg[1], o1) - max(seg[0], o0)).total_seconds() / 60)
                    dur -= ov
                hist[cur_n] += dur
                last = t
            cur_n += dlt
        if t1 > last:
            hist[cur_n] += (t1 - last).total_seconds() / 60
        return hist

    end = last_evid or last_code
    impl_iv = [(tk['start'], tk['end']) for tk in impls]
    lens_iv = [(tk['start'], tk['end']) for tk in lenses]
    hi = histogram(impl_iv, first_dispatch, end)
    hl = histogram(impl_iv + lens_iv, first_dispatch, end)
    tot = sum(hi.values())
    print()
    print(f'concurrency aktual (time-weighted over {tot:.1f} net min, first dispatch → last evidence):')
    print('  implementers running :', ' · '.join(f'{k}: {v:.1f} m ({100*v/tot:.0f} %)' for k, v in sorted(hi.items())))
    print('  impl+lens agents     :', ' · '.join(f'{k}: {v:.1f} m ({100*v/tot:.0f} %)' for k, v in sorted(hl.items())))
    avg = sum(k*v for k, v in hi.items()) / tot if tot else 0
    print(f'  mean implementers in flight = {avg:.2f}; implementer-minutes = {sum(k*v for k,v in hi.items()):.1f}')

    # dispatch bursts (waves the controller actually used): dispatches within 3 min of each other
    ds = sorted((tk['start'], tk['units'][0]) for tk in impls)
    waves = []
    for s, u in ds:
        if waves and mins(waves[-1][-1][0], s) <= 3.0:
            waves[-1].append((s, u))
        else:
            waves.append([(s, u)])
    print()
    print('dispatch bursts (≤3 min apart = one burst):')
    for i, w in enumerate(waves, 1):
        print(f'  burst {i:2d} @ {rel(w[0][0])} m : ' + ', '.join(u for _, u in w))

    # gate scripts by name (wall spent inside gate scripts on the controller thread)
    gs = collections.defaultdict(lambda: [0, 0.0])
    for s, e, script, us in bash_gates:
        if first_dispatch and s >= first_dispatch:
            gs[script][0] += 1; gs[script][1] += mins(s, e) or 0
    print()
    print('controller-thread script calls after first dispatch (count · Σ min):')
    for k, (n, m) in sorted(gs.items(), key=lambda kv: -kv[1][1])[:14]:
        print(f'  {k:38} {n:4d} · {m:6.1f}')

    if jout:
        json.dump({u: {k: (v.isoformat() if isinstance(v, dt.datetime) else
                           ([(a.isoformat() if a else None, b.isoformat() if b else None, c) for a, b, c in v] if k == 'dispatches' else
                            (dict(v) if isinstance(v, collections.Counter) else v)))
                       for k, v in r.items()} for u, r in rows.items()}, open(jout, 'w'), indent=1, default=str)

if __name__ == '__main__':
    main()
