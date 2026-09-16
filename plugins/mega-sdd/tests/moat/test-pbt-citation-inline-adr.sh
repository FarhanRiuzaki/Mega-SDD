#!/usr/bin/env bash
# test-pbt-citation-inline-adr.sh — pins the PBT `Cites: §D-NNN` resolver of
# validate-bolt-artifacts.sh (--file-path on a unit). Layout-2 / layout-3 keep ADRs
# INLINE as `### D-NNN: title` headings in vault.md / context.md (no decisions/ dir),
# so the inventory must read those headings: a cite of an inline ADR is valid, a cite
# of an ADR that exists nowhere still halts pbt_citation_invalid.
# Run: bash plugins/mega-sdd/tests/moat/test-pbt-citation-inline-adr.sh </dev/null
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$(cd "$HERE/../.." && pwd)"
V="$PLUGIN/scripts/validate-bolt-artifacts.sh"
[ -f "$V" ] || { echo "FAIL (validator missing: $V)"; exit 1; }
rc=0
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t pbtcite)"
trap 'rm -rf "$WORK"' EXIT

mkproj() { # $1=project-dir $2=vault-doc-name (vault.md | context.md) $3=inline ADR id
  mkdir -p "$1/.mega-sdd/vaults/demo/units"
  printf '{"vault_version": "1.0", "open_questions": []}\n' > "$1/.mega-sdd/vaults/demo/vault.json"
  printf '# Vault\n\n## Decisions\n\n### %s: Use bcrypt\n\nPassword hashes use bcrypt (cost 12).\n' "$3" \
    > "$1/.mega-sdd/vaults/demo/$2"
}
mkunit() { # $1=project-dir $2=cited ADR id — the unit body carries the PBT Cites: line
  cat > "$1/.mega-sdd/vaults/demo/units/U-001.md" <<EOF
---
unit_id: U-001
task_type: create
target_files:
  - path: src/auth.py
    operation: create
---
# U-001

## Property-based tests
- Property: every stored hash verifies against its plaintext. Cites: §$2
EOF
}
run_v() { # $1=project-dir → rc of the per-file validator (state at .mega-sdd/.bolt-artifacts-state.json)
  bash "$V" --cwd="$1" --file-path="$1/.mega-sdd/vaults/demo/units/U-001.md" --quiet </dev/null >/dev/null 2>&1
}
has_pbt_issue() { # $1=project-dir $2=expected missing id
  python3 -c "
import json,sys; s=json.load(open('$1/.mega-sdd/.bolt-artifacts-state.json'))
i=[x for x in s['issues'] if x['halt_type']=='pbt_citation_invalid']
assert len(i)==1 and i[0]['missing_decisions']==['$2'], s['issues']
" 2>/dev/null
}
no_pbt_issue() { # $1=project-dir
  ! grep -q pbt_citation_invalid "$1/.mega-sdd/.bolt-artifacts-state.json" 2>/dev/null
}

# a) layout-2: inline `### D-001:` heading in vault.md satisfies `Cites: §D-001`
P2="$WORK/l2"; mkproj "$P2" vault.md D-001; mkunit "$P2" D-001
run_v "$P2"; R=$?
if [ "$R" -eq 0 ] && no_pbt_issue "$P2"; then
  echo "PASS (layout-2: inline ### D-001 heading in vault.md resolves Cites: §D-001 — no pbt_citation_invalid)"
else
  echo "FAIL (layout-2 inline ADR cite false-flagged: rc=$R state: $(tr -d '\n' < "$P2/.mega-sdd/.bolt-artifacts-state.json" 2>/dev/null | cut -c1-300))"; rc=1
fi

# b) same vault, cite of an ADR that exists nowhere -> still halts (inventory did not go permissive)
mkunit "$P2" D-999
run_v "$P2"; R=$?
if [ "$R" -eq 1 ] && has_pbt_issue "$P2" D-999; then
  echo "PASS (layout-2: Cites: §D-999 with no such ADR -> pbt_citation_invalid, missing_decisions=[D-999])"
else
  echo "FAIL (unknown ADR cite not caught on layout-2: rc=$R)"; rc=1
fi

# c) layout-3: the inline heading lives in context.md — same resolver, same verdicts
P3="$WORK/l3"; mkproj "$P3" context.md D-002; mkunit "$P3" D-002
run_v "$P3"; R=$?
if [ "$R" -eq 0 ] && no_pbt_issue "$P3"; then
  echo "PASS (layout-3: inline ### D-002 heading in context.md resolves Cites: §D-002)"
else
  echo "FAIL (layout-3 inline ADR cite false-flagged: rc=$R)"; rc=1
fi
mkunit "$P3" D-001
run_v "$P3"; R=$?
if [ "$R" -eq 1 ] && has_pbt_issue "$P3" D-001; then
  echo "PASS (layout-3: Cites: §D-001 when context.md only declares D-002 -> pbt_citation_invalid)"
else
  echo "FAIL (unknown ADR cite not caught on layout-3: rc=$R)"; rc=1
fi

[ $rc -eq 0 ] && echo "ALL PASS"
exit $rc
