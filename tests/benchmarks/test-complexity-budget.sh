#!/usr/bin/env bash
# Complexity-budget ratchet (benchmarks/config/complexity-budget.json).
# Measures the plugin's footprint the same way every time and fails when any value exceeds
# its ceiling:
#   always_loaded_description_chars  frontmatter `description:` of every skill/agent/command —
#                                    the listing every Claude Code session pays for
#   t01_lite_commanded_bytes         benchmarks/scripts/measure-context.sh, T01 lite trace
#   t01_default_commanded_bytes      same, T01 default (files.optimized.txt) trace
#   skill_md_total_bytes             Σ bytes of skills/*/SKILL.md (bytes, not lines: the ≤500-line
#                                    rule alone let execute-bolts reach 48.9 KB in 201 lines)
#   scripts_total_lines / hooks_total_lines   executed plane to maintain
# A raise is legal only with a matching `raises` entry (see the budget file's _doc).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUDGET="$ROOT/benchmarks/config/complexity-budget.json"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
bash "$ROOT/benchmarks/scripts/measure-context.sh" "$ROOT" lite "$T/lite.json" >/dev/null || { echo "FAIL: measure-context lite"; exit 1; }
bash "$ROOT/benchmarks/scripts/measure-context.sh" "$ROOT" optimized "$T/opt.json" >/dev/null || { echo "FAIL: measure-context optimized"; exit 1; }
python3 - "$ROOT" "$BUDGET" "$T/lite.json" "$T/opt.json" <<'EOF'
import glob, json, os, re, sys
root, budget, lite, opt = sys.argv[1:5]
P = os.path.join(root, 'plugins/mega-sdd')

def desc_chars():
    tot = 0
    for f in sorted(glob.glob(f'{P}/skills/*/SKILL.md') + glob.glob(f'{P}/agents/*.md') + glob.glob(f'{P}/commands/*.md')):
        parts = open(f, encoding='utf-8').read().split('---')
        fm = parts[1] if len(parts) > 2 else ''
        m = re.search(r'^description:\s*(.*?)(?=^\w[\w-]*:|\Z)', fm, re.S | re.M)
        if m:
            tot += len(m.group(1).strip())
    return tot

def lines(d):
    # git-TRACKED files only: __pycache__ / local scratch must never move the budget.
    import subprocess
    files = subprocess.run(['git', '-C', root, 'ls-files', '-z', '--', os.path.relpath(d, root)],
                           capture_output=True, check=True).stdout.split(b'\0')
    return sum(open(os.path.join(root, f.decode()), 'rb').read().count(b'\n') for f in files if f)

def t01(path):
    t = json.load(open(path))['tasks']['T01-greenfield-chain']
    if t.get('missing_paths'):
        print(f'FAIL: T01 trace names missing files {t["missing_paths"]} — fix the trace list, the budget cannot be read')
        sys.exit(1)
    return t['bytes_loaded']

measured = {
    'always_loaded_description_chars': desc_chars(),
    't01_lite_commanded_bytes': t01(lite),
    't01_default_commanded_bytes': t01(opt),
    'skill_md_total_bytes': sum(os.path.getsize(f) for f in glob.glob(f'{P}/skills/*/SKILL.md')),
    'scripts_total_lines': lines(f'{P}/scripts'),
    'hooks_total_lines': lines(f'{P}/hooks'),
}
b = json.load(open(budget))
err = 0
for k, v in measured.items():
    ceil = b['ceilings'].get(k)
    if ceil is None:
        print(f'FAIL: no ceiling for {k} (measured {v})'); err = 1
    elif v > ceil:
        print(f'FAIL: {k} = {v} > ceiling {ceil} (+{v - ceil}) — shrink it, or raise the ceiling WITH a measured-benefit `raises` entry')
        err = 1
    elif v < ceil:
        print(f'note: {k} = {v} < ceiling {ceil} (−{ceil - v}) — lower the ceiling to lock the gain')
for r in b.get('raises', []):
    if not (r.get('change') and r.get('metric') and r.get('measured_benefit')):
        print(f'FAIL: raises entry needs change + metric + measured_benefit: {r}'); err = 1
if not err:
    print('PASS: complexity budget (' + ', '.join(f'{k}={v}' for k, v in measured.items()) + ')')
sys.exit(err)
EOF
