#!/usr/bin/env bash
# State anchor — parity pin (spec docs/superpowers/specs/2026-09-25-state-anchor-design.md §5 (b),
# D28). The own-commit subset check uses B3's sanctioned-extras predicate and B3/B4's
# unit_of(). unit_of is imported (postflight_rules); B3's `sanctioned` and `_TEST_PAT` live in
# a bash heredoc of validate-bolt-artifacts.sh and cannot be imported, so bolt_attrib.py
# carries a copy. This pin fails the moment the two copies drift.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
V="$REPO/plugins/mega-sdd/scripts/validate-bolt-artifacts.sh"
LIB="$REPO/plugins/mega-sdd/scripts/_lib"
python3 - "$V" "$LIB" <<'PY' && { echo "PASS state-anchor attribution parity"; exit 0; }
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
sys.path.insert(0, sys.argv[2])
import bolt_attrib, postflight_rules
fail = []
# 1. B3's test-file pattern, byte-identical
m = re.search(r'_TEST_PAT = re\.compile\(\s*r"([^"]+)"\)', src)
if not m or m.group(1) != bolt_attrib.TEST_PAT.pattern:
    fail.append("TEST_PAT differs from validate-bolt-artifacts.sh")
# 2. B3's sanctioned() prefixes and branches
body = re.search(r"def sanctioned\(p\):\n(.*?)\n\n", src, re.S)
want = ['p.startswith(".mega-sdd/") or p.startswith("docs/mega-sdd/")', "_in_bound_vault(p)", "_TEST_PAT.search(p)"]
if not body or any(w not in body.group(1) for w in want):
    fail.append("B3 sanctioned() changed shape — re-copy it into bolt_attrib.sanctioned")
# 3. the bound-vault roots globs
for pat in ('"*-bound"', '"*", "*-bound"', '"docs", "mega-sdd", "vaults", "*-bound"'):
    if pat not in src:
        fail.append("B3 _bound_vault_roots glob %s missing" % pat)
# 4. unit_of: the gate copy (PY_COMMON) and the imported one agree on the regexes
for name in ("UNIT_LEGACY", "UNIT_SCOPE", "UNIT_ANY"):
    mm = re.search(r'%s = re\.compile\(r"([^"]+)"\)' % name, src)
    if not mm or mm.group(1) != getattr(postflight_rules, name).pattern:
        fail.append("%s differs between validate-bolt-artifacts.sh and postflight_rules.py" % name)
# 5. B4's acceptance key vs the stricter own-commit key (every own match is B4-keyed)
if 'V5_TRAILER = re.compile(r"(?im)^SDD-Acceptance:\\s*v5\\b")' not in src:
    fail.append("B4 V5_TRAILER changed — re-check bolt_attrib.ACCEPTANCE_V5")
for f in fail:
    print("FAIL", f)
sys.exit(1 if fail else 0)
PY
echo "state-anchor attribution parity FAILED"; exit 1
