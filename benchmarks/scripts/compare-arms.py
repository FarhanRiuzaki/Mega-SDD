#!/usr/bin/env python3
"""compare-arms.py — vanilla vs mega-sdd, per scenario, n runs per arm (2026-09-26).

  python3 benchmarks/scripts/compare-arms.py <manifest.json> [--md out.md] [--json out.json]

manifest.json (one row per run; `quality` optional until the blind scoring is done):
  {"min_clean_runs": 3,
   "targets": {"xs": {"review_ready_min": 60}, "clinic": {"review_ready_min": 120}},
   "runs": [{"scenario": "xs", "arm": "vanilla",   "metrics": "<arm-metrics.json>", "quality": "<score.json>"},
            {"scenario": "xs", "arm": "lite-8.8.1", "metrics": "...", "quality": "..."}]}

  metrics  = output of benchmarks/scripts/arm-metrics.py --json
  quality  = benchmarks/runbooks/vanilla-vs-megasdd.md §Quality score file:
             {"completion": 0..1, "ac_pass": n, "ac_total": n, "critical": n, "important": n,
              "minor": n, "rubric": 0..100}

Per scenario and arm: every run listed (clean or not, with the reason), then median + min–max
over CLEAN runs only. Relative = arm median / vanilla median (for time, tokens and cost < 1 is
better; for rubric and completion > 1 is better). Absolute = the scenario target, reported next
to the relative figure — neither hides the other.

Verdict per metric is mechanical and deliberately conservative:
  INSUFFICIENT  either arm has fewer than min_clean_runs clean runs, or the metric is missing
  BETTER/WORSE  the two arms' clean ranges do not overlap (every arm run beats / loses to every
                vanilla run)
  OVERLAP       the ranges overlap — no claim either way at this n
No p-values: with n=3 per arm a significance claim is not supportable, so none is made.
"""
import json, os, statistics, sys

# (group, key, label, lower_is_better)
METRICS = [
    ('speed', 'review_ready_min', 'time to review-ready (min)', True),
    ('speed', 'wall_min', 'wall (min)', True),
    ('speed', 'api_time_min', 'API time (min)', True),
    ('speed', 'stream_silence_over_5m_min', 'silence >5 m (min, proxy idle)', True),
    ('tokens', 'total', 'tokens total', True),
    ('tokens', 'input', 'tokens input (uncached)', True),
    ('tokens', 'output', 'tokens output', True),
    ('tokens', 'cache_read', 'tokens cache read', True),
    ('tokens', 'cost_usd', 'cost (USD)', True),
    ('light', 'tool_calls', 'tool calls', True),
    ('light', 'subagent_dispatches', 'subagent dispatches', True),
    ('light', 'ask_attempts', 'interaction points', True),
    ('light', 'distinct_files_read', 'distinct files read', True),
    ('light', 'docs_md_added', 'markdown lines added outside .mega-sdd/', True),
    ('light', 'process_added', 'process artefact lines committed (.mega-sdd/)', True),
    ('light', 'code_test_added', 'code + test lines added', True),
    ('quality', 'completion', 'task completion (0-1)', False),
    ('quality', 'ac_rate', 'acceptance criteria pass rate', False),
    ('quality', 'critical', 'Critical findings', True),
    ('quality', 'important', 'Important findings', True),
    ('quality', 'rubric', 'blind rubric score (0-100)', False),
]


def load(path, base):
    if not path:
        return None
    p = path if os.path.isabs(path) else os.path.join(base, path)
    try:
        return json.load(open(p))
    except (OSError, ValueError):
        return None


def value(run, group, key):
    if group == 'quality':
        q = run.get('_q')
        if not q:
            return None
        if key == 'ac_rate':
            return q['ac_pass'] / q['ac_total'] if q.get('ac_total') else None
        return q.get(key)
    m = run.get('_m') or {}
    if key in ('docs_md_added', 'process_added', 'code_test_added'):
        shape = (m.get('light') or {}).get('diff_shape')
        if not shape:
            return None
        if key == 'code_test_added':
            return shape['code']['added'] + shape['test']['added']
        return shape['docs_md' if key == 'docs_md_added' else 'process']['added']
    return (m.get(group) or {}).get(key)


def fmt(v):
    if v is None:
        return 'belum diukur'
    if isinstance(v, float):
        return f'{v:,.2f}'
    return f'{v:,}'


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    mpath = args[0]
    opt = {a: args[i + 1] for i, a in enumerate(args) if a in ('--md', '--json') and i + 1 < len(args)}
    man = json.load(open(mpath))
    base = os.path.dirname(os.path.abspath(mpath))
    need = man.get('min_clean_runs', 3)
    targets = man.get('targets', {})
    runs = man.get('runs', [])
    for r in runs:
        r['_m'] = load(r.get('metrics'), base)
        r['_q'] = load(r.get('quality'), base)
        c = (r['_m'] or {}).get('clean') or {}
        r['_clean'] = bool(c.get('is_clean'))
        r['_why'] = 'metrics missing' if not r['_m'] else ('clean' if r['_clean'] else
                    f"not clean: processes={c.get('processes')} keys={c.get('resume_or_outage_keys')} purity={c.get('purity')}")
    md, out = [], {}
    for scen in sorted({r['scenario'] for r in runs}):
        sr = [r for r in runs if r['scenario'] == scen]
        arms = sorted({r['arm'] for r in sr}, key=lambda a: (a != 'vanilla', a))
        md.append(f'## Scenario `{scen}`\n')
        md.append('### Runs\n\n| arm | run | status | ' + ' | '.join(lbl for _, _, lbl, _ in METRICS) + ' |')
        md.append('|---|---|---|' + '---|' * len(METRICS))
        for r in sr:
            md.append(f"| {r['arm']} | {r.get('run', os.path.basename(str(r.get('metrics'))))} | {r['_why']} | "
                      + ' | '.join(fmt(value(r, g, k)) for g, k, _, _ in METRICS) + ' |')
        stats = {}
        for a in arms:
            clean = [r for r in sr if r['arm'] == a and r['_clean']]
            stats[a] = {'n_clean': len(clean)}
            for g, k, _, _ in METRICS:
                vals = [v for v in (value(r, g, k) for r in clean) if v is not None]
                stats[a][k] = {'n': len(vals), 'median': statistics.median(vals) if vals else None,
                               'min': min(vals) if vals else None, 'max': max(vals) if vals else None}
        md.append('\n### Summary (clean runs only)\n')
        md.append('| metric | ' + ' | '.join(f'{a} median [min–max] (n)' for a in arms)
                  + ' | ' + ' | '.join(f'{a} / vanilla' for a in arms if a != 'vanilla') + ' | verdict vs vanilla |')
        md.append('|---|' + '---|' * (len(arms) + max(0, len(arms) - 1) + 1))
        verdicts = {}
        for g, k, lbl, lower in METRICS:
            cells = []
            for a in arms:
                s = stats[a][k]
                cells.append('belum diukur' if s['median'] is None else
                             f"{fmt(s['median'])} [{fmt(s['min'])}–{fmt(s['max'])}] ({s['n']})")
            rel, verd = [], []
            v = stats.get('vanilla', {}).get(k)
            for a in arms:
                if a == 'vanilla':
                    continue
                s = stats[a][k]
                if not v or v['median'] is None or s['median'] is None:
                    rel.append('belum diukur')
                elif v['median'] == 0:
                    rel.append('n/a (vanilla = 0)')
                else:
                    rel.append(f"{s['median'] / v['median']:.2f}×")
                if not v or v['n'] < need or s['n'] < need:
                    verd.append(f'{a}: INSUFFICIENT')
                elif (s['max'] < v['min']) if lower else (s['min'] > v['max']):
                    verd.append(f'{a}: BETTER')
                elif (s['min'] > v['max']) if lower else (s['max'] < v['min']):
                    verd.append(f'{a}: WORSE')
                else:
                    verd.append(f'{a}: OVERLAP')
            verdicts[k] = verd
            md.append(f'| {lbl} | ' + ' | '.join(cells) + (' | ' + ' | '.join(rel) if rel else '') + ' | ' + '; '.join(verd) + ' |')
        tgt = targets.get(scen) or {}
        if tgt:
            md.append('\n### Absolute targets (reported beside the relative verdict, never instead of it)\n')
            md.append('| target | ' + ' | '.join(arms) + ' |\n|---|' + '---|' * len(arms))
            for k, limit in tgt.items():
                row = []
                for a in arms:
                    s = stats[a].get(k) or {}
                    if not s.get('n'):
                        row.append('belum diukur')
                    else:
                        row.append(f"{'PASS' if s['max'] <= limit else ('PARTIAL' if s['min'] <= limit else 'FAIL')} (median {fmt(s['median'])})")
                md.append(f'| {k} ≤ {limit} | ' + ' | '.join(row) + ' |')
        md.append('')
        out[scen] = {'stats': stats, 'verdicts': verdicts}
    text = '\n'.join(md)
    if '--md' in opt:
        open(opt['--md'], 'w').write(text + '\n')
    if '--json' in opt:
        json.dump(out, open(opt['--json'], 'w'), indent=1, default=str)
    print(text)
    return 0


if __name__ == '__main__':
    sys.exit(main())
