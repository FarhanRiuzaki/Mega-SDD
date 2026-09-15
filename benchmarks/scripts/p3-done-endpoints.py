#!/usr/bin/env python3
"""p3-done-endpoints.py — the DONE definition, made explicit per arm (owner amendment P3 #2).

For ONE arm results dir (run.meta + git-log.txt + stream.jsonl) prints, relative to the
session clock start (first stream record of the arm's own session id):

  DONE_code     last unit-scoped commit that touches CODE (feat/fix/test/style/refactor/
                chore(U-XXX) — NOT a docs(U-XXX) bolt-report-only commit)
  DONE_p5       the endpoint p0-extract-arm.sh has used so far = last `type(U-XXX):` commit
                of ANY type (this is the number every P0/P2 table carried)
  DONE_gate     the last code commit's per-unit gates all passed: max over units of the
                last run-postflight-scan / run-acceptance-tests / merge-panel-findings
                tool_result for that unit (stream-derived, never a commit time)
  B2            run-full-suite.sh result (batch-level gate; reported, not folded in)
  EXCLUDED      first detect-drift / analyze / render-html / emit call — the opt-in
                DOCS/emit + end-of-chain diagnostics lane, never part of DONE

usage: p3-done-endpoints.py <results-dir> [--outage START END]
"""
import json, re, sys, datetime as dt, os

UNIT_RE = re.compile(r'\bU-\d{3}\b')

def iso(s):
    return dt.datetime.fromisoformat(s.replace('Z', '+00:00')).astimezone(dt.timezone.utc)

def hms(sec):
    if sec is None:
        return '—'
    sec = int(round(sec)); h, r = divmod(sec, 3600); m, s = divmod(r, 60)
    return f'{h}h{m:02d}m{s:02d}s' if h else f'{m}m{s:02d}s'

def main():
    args = sys.argv[1:]; outage = None
    if '--outage' in args:
        i = args.index('--outage'); outage = (iso(args[i+1]), iso(args[i+2])); del args[i:i+3]
    rdir = args[0]
    meta = dict(l.rstrip('\n').split('=', 1) for l in open(f'{rdir}/run.meta') if '=' in l)
    sid = meta.get('sid', '')
    commits = []
    for line in open(f'{rdir}/git-log.txt'):
        p = line.rstrip('\n').split(' ', 2)
        if len(p) == 3:
            commits.append((iso(p[1]), p[2]))
    unit_commits = [(t, s) for t, s in commits if re.match(r'[a-z]+\(U-[A-Za-z0-9_,\- ]+\):', s)]
    code_commits = [(t, s) for t, s in unit_commits if not s.startswith('docs(')]
    done_p5 = max((t for t, _ in unit_commits), default=None)
    done_code = max((t for t, _ in code_commits), default=None)
    last_code_units = set(UNIT_RE.findall(max(code_commits, key=lambda c: c[0])[1])) if code_commits else set()

    start = None; cur = None
    open_bash = {}; gate_ts = {}   # unit -> {script: last ts}
    b2 = None; excluded = None
    with open(f'{rdir}/stream.jsonl', encoding='utf-8') as f:
        for line in f:
            try:
                e = json.loads(line)
            except Exception:
                continue
            if sid and e.get('session_id') and not e['session_id'].startswith(sid):
                continue
            if e.get('timestamp'):
                cur = iso(e['timestamp']); start = start or cur
            t = e.get('type')
            if t == 'assistant':
                for b in e['message'].get('content', []):
                    if b.get('type') == 'tool_use' and b.get('name') == 'Bash':
                        cmd = b['input'].get('command', '')
                        # every plugin script named in the command (controllers alias the
                        # scripts dir as $P and chain several scripts in one call), plus the
                        # controller-written detect-after helper seen in the clinic run
                        names = set(re.findall(r'(?:^|[/\s"\'])((?:run|merge|derive|write|validate|build|resolve|check|query|render|detect)[a-z0-9\-]*\.sh)', cmd))
                        if re.search(r'p0_post\.sh|detect[-_]after', cmd):
                            names |= {'run-postflight-scan.sh', 'run-acceptance-tests.sh'}
                        if names:
                            open_bash[b['id']] = (names, sorted(set(UNIT_RE.findall(cmd))), cmd)
            elif t == 'user':
                for b in e['message'].get('content', []):
                    if b.get('type') == 'tool_result' and b.get('tool_use_id') in open_bash:
                        names, units, cmd = open_bash.pop(b['tool_use_id'])
                        for script in names:
                            if script in ('run-postflight-scan.sh', 'run-acceptance-tests.sh', 'merge-panel-findings.sh'):
                                for u in units:
                                    gate_ts.setdefault(u, {})[script] = cur
                            elif script == 'run-full-suite.sh':
                                b2 = cur
                            elif script in ('run-analyze.sh', 'render-html.sh', 'run-detect-drift.sh') or 'emit' in script:
                                excluded = excluded or cur
    done_gate = None
    for u, d in gate_ts.items():
        if u in last_code_units or not last_code_units:
            for s, ts_ in d.items():
                if done_code and ts_ >= done_code:
                    done_gate = max(done_gate, ts_) if done_gate else ts_
    # if the last-code unit's gates were already run BEFORE its last commit (a fix-forward
    # commit after the gate), fall back to the latest gate of any unit after DONE_code
    if done_gate is None:
        for u, d in gate_ts.items():
            for s, ts_ in d.items():
                if done_code and ts_ >= done_code:
                    done_gate = max(done_gate, ts_) if done_gate else ts_

    def rel(t):
        if not t or not start:
            return None
        sec = (t - start).total_seconds()
        if outage and t > outage[1]:
            sec -= (outage[1] - outage[0]).total_seconds()
        return sec

    print(f'arm {os.path.basename(rdir)} sid {sid[:8]} start {start.strftime("%H:%M:%S")}Z'
          + (f' (net of outage {outage[0].strftime("%H:%M")}Z→{outage[1].strftime("%H:%M")}Z)' if outage else ''))
    print(f'  DONE_code  {hms(rel(done_code)):>10}  last code commit  {max(code_commits, key=lambda c: c[0])[1][:70] if code_commits else "—"}')
    print(f'  DONE_p5    {hms(rel(done_p5)):>10}  last type(U-*) commit (P0/P2 tables)  {max(unit_commits, key=lambda c: c[0])[1][:60] if unit_commits else "—"}')
    print(f'  DONE_gate  {hms(rel(done_gate)):>10}  last unit gate pass (postflight/acceptance/panel merge) for {",".join(sorted(last_code_units)) or "?"}')
    print(f'  B2 suite   {hms(rel(b2)):>10}  run-full-suite.sh result (batch gate, reported separately)')
    print(f'  EXCLUDED   {hms(rel(excluded)):>10}  first drift/analyze/html/emit call (never in DONE)')
    print(f'  gate calls seen for last-code unit: { {k: v.strftime("%H:%M:%S") for k, v in gate_ts.get(next(iter(sorted(last_code_units)), ""), {}).items()} }')

if __name__ == '__main__':
    main()
