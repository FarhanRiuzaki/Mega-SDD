#!/usr/bin/env python3
"""arm-metrics.py — ARM-AGNOSTIC metrics for one headless run (vanilla OR mega-sdd), 2026-09-26.

  python3 benchmarks/scripts/arm-metrics.py <results-dir> [--repo <arm-clone> --base <sha>] [--json out.json]

The p3-* extractors key on mega-sdd artefacts (U-XXX commits, gate scripts, panel ledgers), so
they cannot read a vanilla arm. This one reads only what BOTH arms produce:

  <results-dir>/stream.jsonl   `claude -p --output-format stream-json` (every process of the run)
  <results-dir>/run.meta       launcher record (arm_kind, model, plugins=, purity=, resume_*/outage_*)
  <results-dir>/git-log.txt    optional, `git log --format="%h %cI %s"` of the arm after the run
  --repo/--base                optional, the arm clone + its pre-run sha → diff shape (review burden)

Output groups (every field is MEASURED from those inputs; nothing is estimated; a missing input
leaves the field null, never 0):
  speed    wall (first→last stream timestamp), Σ process duration, Σ API time, stream silence
           > 5 min (PROXY for waiting — headless human-wait is 0 by construction), time to the
           first / last commit (last commit = ready for review)
  tokens   modelUsage + total_cost_usd are cumulative per process: the last `result` record of
           each process is taken, then Σ over processes (a counter going down = a --resume):
           input / output / cache_read / cache_creation per model and total, cost
  light    tool calls by name, subagent dispatches, Skill calls, ask attempts (interaction
           points), distinct files Read, init roster size (plugins / skills), diff shape split
           code / test / docs-markdown (review burden)
  clean    processes (1 = no resume), resume_* / outage_* keys in run.meta, purity line
Quality is NOT here: it is scored after the run, blind to the arm, per
benchmarks/runbooks/vanilla-vs-megasdd.md §Quality.
"""
import collections, datetime as dt, json, os, re, subprocess, sys

SILENCE_S = 300
TEST_RE = re.compile(r'(^|/)(tests?|__tests__|spec)(/|$)|\.(test|spec)\.[a-z]+$|_test\.[a-z]+$')


def iso(s):
    return dt.datetime.fromisoformat(s.replace('Z', '+00:00')).astimezone(dt.timezone.utc)


def read_meta(rdir):
    meta = {}
    p = os.path.join(rdir, 'run.meta')
    if os.path.isfile(p):
        for line in open(p, encoding='utf-8', errors='replace'):
            if '=' in line:
                k, v = line.rstrip('\n').split('=', 1)
                meta[k] = v
    return meta


def scan_stream(path, sid_prefix):
    usage = collections.defaultdict(lambda: collections.Counter())
    cost, processes, dur_ms, api_ms = 0.0, 0, 0, 0
    tools, reads = collections.Counter(), set()
    stamps, init = [], None
    segments, last = [], None
    for line in open(path, encoding='utf-8', errors='replace'):
        try:
            e = json.loads(line)
        except ValueError:
            continue
        own = not sid_prefix or not e.get('session_id') or e['session_id'].startswith(sid_prefix)
        if e.get('timestamp') and own:
            try:
                stamps.append(iso(e['timestamp']))
            except ValueError:
                pass
        if e.get('type') == 'system' and e.get('subtype') == 'init' and init is None:
            init = e
        if e.get('type') == 'result':
            # total_cost_usd / duration_api_ms / modelUsage are CUMULATIVE per process and are
            # repeated on every turn completion of that process (background wake-ups included);
            # duration_ms is per turn. A counter that goes DOWN = a new process (--resume).
            dur_ms += e.get('duration_ms') or 0
            c, a = e.get('total_cost_usd') or 0.0, e.get('duration_api_ms') or 0
            if last is None or c < last[0] or (c == last[0] and a < last[1]):
                segments.append(e)
            else:
                segments[-1] = e
            last = (c, a)
        if e.get('type') == 'assistant':
            for c in (e.get('message') or {}).get('content') or []:
                if isinstance(c, dict) and c.get('type') == 'tool_use':
                    name = c.get('name', '?')
                    tools[name] += 1
                    if name == 'Read':
                        fp = (c.get('input') or {}).get('file_path')
                        if fp:
                            reads.add(fp)
    for e in segments:
        cost += e.get('total_cost_usd') or 0.0
        api_ms += e.get('duration_api_ms') or 0
        for model, u in (e.get('modelUsage') or {}).items():
            for k in ('inputTokens', 'outputTokens', 'cacheReadInputTokens', 'cacheCreationInputTokens'):
                usage[model][k] += u.get(k) or 0
    processes = len(segments)
    return usage, cost, processes, dur_ms, api_ms, tools, reads, sorted(stamps), init


def git_log(rdir):
    p = os.path.join(rdir, 'git-log.txt')
    out = []
    if os.path.isfile(p):
        for line in open(p, encoding='utf-8', errors='replace'):
            parts = line.strip().split(' ', 2)
            if len(parts) >= 2:
                try:
                    out.append((iso(parts[1]), parts[2] if len(parts) > 2 else ''))
                except ValueError:
                    continue
    return sorted(out)


def diff_shape(repo, base):
    try:
        raw = subprocess.run(['git', '-C', repo, 'diff', '--numstat', f'{base}..HEAD'],
                             capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    shape = {k: {'files': 0, 'added': 0, 'deleted': 0} for k in ('code', 'test', 'docs_md', 'other')}
    for line in raw.splitlines():
        a, d, path = line.split('\t', 2)
        if a == '-':
            kind = 'other'
        elif path.endswith('.md'):
            kind = 'docs_md'
        elif TEST_RE.search(path):
            kind = 'test'
        elif re.search(r'\.(tsx?|jsx?|mjs|cjs|php|py|rb|go|rs|java|kt|cs|swift|vue|svelte|sql|prisma|css|scss)$', path):
            kind = 'code'
        else:
            kind = 'other'
        shape[kind]['files'] += 1
        if a != '-':
            shape[kind]['added'] += int(a)
            shape[kind]['deleted'] += int(d)
    return shape


def minutes(sec):
    return None if sec is None else round(sec / 60.0, 2)


def main():
    args = sys.argv[1:]
    if not args or args[0].startswith('-'):
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    rdir = args[0]
    opt = {a: args[i + 1] for i, a in enumerate(args) if a in ('--repo', '--base', '--json') and i + 1 < len(args)}
    meta = read_meta(rdir)
    stream = os.path.join(rdir, 'stream.jsonl')
    if not os.path.isfile(stream):
        print(f'UNREADABLE: {stream} missing', file=sys.stderr)
        return 2
    sid = (meta.get('sid') or '')[:8]
    usage, cost, processes, dur_ms, api_ms, tools, reads, stamps, init = scan_stream(stream, sid)
    start = stamps[0] if stamps else None
    wall = (stamps[-1] - stamps[0]).total_seconds() if len(stamps) > 1 else None
    silence = sum(g for g in ((b - a).total_seconds() for a, b in zip(stamps, stamps[1:])) if g > SILENCE_S) if stamps else None
    commits = git_log(rdir)
    code_commits = [c for c in commits if start and c[0] >= start]
    total = collections.Counter()
    for u in usage.values():
        total.update(u)
    out = {
        'arm': os.path.basename(os.path.normpath(rdir)),
        'arm_kind': meta.get('arm_kind', 'megasdd' if 'flags' in meta else None),
        'model': meta.get('model'),
        'speed': {
            'wall_min': minutes(wall),
            'process_duration_min': minutes(dur_ms / 1000.0) if processes else None,
            'api_time_min': minutes(api_ms / 1000.0) if processes else None,
            'stream_silence_over_5m_min': minutes(silence),
            'first_commit_min': minutes((code_commits[0][0] - start).total_seconds()) if code_commits else None,
            'review_ready_min': minutes((code_commits[-1][0] - start).total_seconds()) if code_commits else None,
        },
        'tokens': {
            'per_model': {m: dict(u) for m, u in usage.items()},
            'input': total['inputTokens'], 'output': total['outputTokens'],
            'cache_read': total['cacheReadInputTokens'], 'cache_creation': total['cacheCreationInputTokens'],
            'total': sum(total.values()),
            'cost_usd': round(cost, 2) if processes else None,
        },
        'light': {
            'tool_calls': sum(tools.values()),
            'tool_calls_by_name': dict(tools.most_common()),
            'subagent_dispatches': tools.get('Agent', 0) + tools.get('Task', 0),
            'skill_calls': tools.get('Skill', 0),
            'ask_attempts': tools.get('AskUserQuestion', 0),
            'distinct_files_read': len(reads),
            'init_plugins': len((init or {}).get('plugins') or []) if init else None,
            'init_skills': len((init or {}).get('skills') or []) if init else None,
            'commits': len(code_commits) if commits else None,
            'diff_shape': diff_shape(opt['--repo'], opt['--base']) if '--repo' in opt and '--base' in opt else None,
        },
        'clean': {
            'processes': processes,
            'resume_or_outage_keys': sorted(k for k in meta if k.startswith(('resume_', 'outage_'))),
            'purity': meta.get('purity'),
        },
    }
    out['clean']['is_clean'] = processes == 1 and not out['clean']['resume_or_outage_keys'] \
        and (out['clean']['purity'] or 'PASS').startswith('PASS')
    text = json.dumps(out, indent=1)
    if '--json' in opt:
        with open(opt['--json'], 'w') as f:
            f.write(text + '\n')
    print(text)
    return 0


if __name__ == '__main__':
    sys.exit(main())
