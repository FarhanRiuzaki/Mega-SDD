#!/usr/bin/env bash
# 9.0 P1 exit criterion (docs/superpowers/specs/2026-09-27-v9-simplification-design.md §5):
# no surviving file routes to, reads from, or dispatches a deleted classic skill
# (generate-intent, bind-codebase, generate-units, scan-codebase), and every reference
# path a surviving SKILL.md / command names resolves on disk.
#
# Allowed on purpose: "Relocated from skills/<removed>/..." provenance notes in relocated
# files. P1b pruned the last removed-skill-id legs (hooks/pre-tool-use DEGENERATE-MAP gate
# + Factory-arm alternates), so the id grep below is strict over the whole plugin.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"
rc=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; rc=1; }
RM='generate-intent|bind-codebase|generate-units|scan-codebase'

for s in generate-intent bind-codebase generate-units scan-codebase; do
  [ -e "$P/skills/$s" ] && bad "skills/$s still exists" || ok "skills/$s is gone"
done

hits=$(grep -rnE "skills/($RM)/" "$P" --exclude-dir=tests 2>/dev/null | grep -v -i 'relocated from' || true)
[ -z "$hits" ] && ok "no path into a removed skill directory (provenance notes excepted)" || { bad "paths into removed skill dirs:"; echo "$hits" | head -20; }

ids=$(grep -rnE "mega-sdd:($RM)" "$P" --exclude-dir=tests 2>/dev/null || true)
[ -z "$ids" ] && ok "no dispatch / proposal of a removed skill id anywhere in the plugin (tests excluded)" || { bad "removed skill ids still dispatched/proposed:"; echo "$ids" | head -20; }

# every `references/...md` / `<skill>/references/...md` / `plugins/mega-sdd/references/...md`
# path named in a surviving SKILL.md or command resolves
missing=$(python3 - "$P" <<'EOF'
import os, re, sys, glob
P = sys.argv[1]
bad = []
files = glob.glob(os.path.join(P, 'skills', '*', 'SKILL.md')) + glob.glob(os.path.join(P, 'commands', '*.md'))
pat = re.compile(r'(plugins/mega-sdd/references/[A-Za-z0-9_./-]+\.md|(?:\.\./)?[a-z-]+/references/[A-Za-z0-9_./-]+\.md|(?<![\w/-])references/[A-Za-z0-9_./-]+\.md)')
for f in files:
    skill_dir = os.path.dirname(f)
    for m in pat.finditer(open(f, encoding='utf-8', errors='replace').read()):
        ref = m.group(1)
        if ref.startswith('plugins/mega-sdd/'):
            cand = [os.path.join(os.path.dirname(os.path.dirname(P)), ref)]
        elif ref.startswith('references/'):
            cand = [os.path.join(skill_dir, ref), os.path.join(P, ref)]
        else:
            r = ref[3:] if ref.startswith('../') else ref
            cand = [os.path.join(P, 'skills', r)]
        if not any(os.path.isfile(c) for c in cand):
            bad.append(f'{os.path.relpath(f, P)} -> {ref}')
print('\n'.join(sorted(set(bad))))
EOF
)
[ -z "$missing" ] && ok "every reference path named by a SKILL.md / command resolves" || { bad "unresolved reference paths:"; echo "$missing"; }
exit $rc
