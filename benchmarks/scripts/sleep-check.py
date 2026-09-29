#!/usr/bin/env python3
"""sleep-check.py — did the machine sleep during a headless run? (macOS, 2026-09-26)

  python3 benchmarks/scripts/sleep-check.py <results-dir> [<results-dir> ...] [--mark]

`caffeinate -i` prevents IDLE sleep only; a closed lid on battery still sleeps the machine and
the run's wall clock silently absorbs it (clinic lite-1 of the vanilla-ab block: 199 min). For
each results dir, reads started_at / finished_at from run.meta and the `pmset -g log` Sleep
entries in that window. Prints one line per dir. --mark appends an `outage_sleep=` line to
run.meta when a sleep is found and none is recorded yet (arm-metrics.py then reports the run
as not clean). Non-macOS or no pmset → UNREADABLE (never "no sleep" by absence).
"""
import datetime as dt, os, re, subprocess, sys

LINE = re.compile(r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} [+-]\d{4}) (Sleep|Wake) ')


def pm_events():
    try:
        out = subprocess.run(['pmset', '-g', 'log'], capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    ev = []
    for line in out.splitlines():
        m = LINE.match(line)
        if m:
            ev.append((dt.datetime.strptime(m.group(1), '%Y-%m-%d %H:%M:%S %z'), m.group(2)))
    return ev


def meta(rdir):
    d = {}
    p = os.path.join(rdir, 'run.meta')
    if os.path.isfile(p):
        for line in open(p):
            if '=' in line:
                k, v = line.rstrip('\n').split('=', 1)
                d.setdefault(k, v)
    return d


def main():
    args = [a for a in sys.argv[1:] if a != '--mark']
    mark = '--mark' in sys.argv
    ev = pm_events()
    rc = 0
    for rdir in args:
        m = meta(rdir)
        if ev is None or 'started_at' not in m or 'finished_at' not in m:
            print(f'UNREADABLE {rdir}'); rc = 2; continue
        a = dt.datetime.fromisoformat(m['started_at'].replace('Z', '+00:00'))
        b = dt.datetime.fromisoformat(m['finished_at'].replace('Z', '+00:00'))
        sleeps = [t for t, kind in ev if kind == 'Sleep' and a <= t <= b]
        name = os.path.basename(os.path.normpath(rdir))
        if not sleeps:
            print(f'no-sleep {name}')
            continue
        first = sleeps[0].astimezone(dt.timezone.utc).strftime('%H:%M:%SZ')
        print(f'SLEEP {name}: {len(sleeps)} sleep event(s), first {first}')
        if mark and 'outage_sleep' not in m:
            with open(os.path.join(rdir, 'run.meta'), 'a') as f:
                f.write(f'outage_sleep={len(sleeps)} pmset Sleep event(s) in the run window, first {first}\n')
    return rc


if __name__ == '__main__':
    sys.exit(main())
