#!/usr/bin/env bash
# test-tool-matrix.sh — F1-1 (batch-B brief, v5.3.1 install-deps patch):
# structural + parse test for tool-matrix.yaml. The only prior automated
# check (tests/code-gates/test-gates-wired.sh) greps 2 of 9 tool ids
# ('semgrep gitleaks') — that gap is exactly how a lost '- id: pandoc'
# list-item line (commit 1b4b41f) shipped undetected: under a plain YAML
# parse the orphaned purpose/fallback_behavior/matrix keys silently MERGE
# into the previous ('jd') mapping (PyYAML keeps the last-seen value per
# duplicate key, no error, no warning) rather than raising anything a
# dict-shaped check would catch. This test adds the missing layer:
#
#   RAW  (python3 stdlib only — runs in every environment, no pyyaml needed):
#     g — within the tools: block, count('  - id:') == count('    purpose:')
#         == count('    fallback_behavior:') == count('    matrix:') == 9,
#         AND no tool-entry-shaped key (used_by/purpose/fallback_behavior/
#         matrix/notes) appears at 4-space indent outside an active
#         '  - id:' entry (the exact orphaned-mapping-key failure mode)
#     a  — (raw cross-check) every entry has exactly ONE of each required
#          key: used_by/purpose/fallback_behavior/matrix
#     d  — every matrix row whose install_cmd contains 'sudo ' carries
#          requires_sudo: true on that SAME row
#     e  — no install_cmd contains curl / wget / '| bash' (never-curl|bash)
#   YAML (pyyaml — python3, else /opt/homebrew/bin/python3.11, else SKIP
#         with a visible note; never fail solely for missing pyyaml):
#     a  — every parsed tools[] entry has id/used_by/purpose/
#          fallback_behavior/matrix (dict-shaped: catches missing keys,
#          NOT the duplicate-key merge — that is raw check g/a's job)
#     b  — tool count == 9 AND id set == union(defaults.* groups)
#     c  — every matrix row has os/pkg_mgr/install_cmd/verify_cmd/size_mb
#     f  — every defaults group ⊆ tool ids
#
# TDD is inverted here: the subject file is believed-good (just landed in
# commit 8f93566 — 9 tools, all with used_by). Baseline run below must
# PASS. Mutation probes then mutate TEMP COPIES ONLY (never the real file)
# to prove each detector actually fires, including a literal replay of the
# historical pandoc corruption (drop a '- id:' line).
#
# Run: bash tests/derived-artifacts/test-tool-matrix.sh </dev/null
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
TM="${ROOT}/plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml"
[ -f "$TM" ] || { echo "missing $TM"; exit 1; }

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t tmyaml)"
trap 'rm -rf "$WORK"' EXIT

# ── pyyaml fallback ladder (mirrors scripts/validate-pack.sh _yaml_available) ──
PYBIN=""
if python3 -c "import yaml" 2>/dev/null; then
  PYBIN="python3"
elif [ -x /opt/homebrew/bin/python3.11 ] && /opt/homebrew/bin/python3.11 -c "import yaml" 2>/dev/null; then
  PYBIN="/opt/homebrew/bin/python3.11"
fi

note "== tool-matrix.yaml structural + parse test (F1-1) =="
if [ -z "$PYBIN" ]; then
  note "SKIP: no python3 with pyyaml found (tried python3, /opt/homebrew/bin/python3.11)"
  note "SKIP: yaml-based assertions a(yaml)/b/c/f will not run this session"
  note "      (raw-line assertions g/a(raw)/d/e still run — python3 stdlib only)"
fi

# ──────────────────────────────────────────────────────────────────────────
# raw_checks.py — pure python3 stdlib, no imports beyond sys/re.
# Scans the tools: block by raw indentation (2 / 4 / 6 / 8 spaces) and never
# builds a dict keyed by 'id', so a duplicate/orphaned key cannot silently
# overwrite anything — it is counted and reported instead.
# ──────────────────────────────────────────────────────────────────────────
cat > "$WORK/raw_checks.py" <<'PYRAW'
import sys

def indent_of(s):
    return len(s) - len(s.lstrip(' '))

def main():
    path = sys.argv[1]
    lines = open(path, encoding='utf-8').read().splitlines()

    tools_start = None
    for i, l in enumerate(lines):
        if l.strip() == 'tools:':
            tools_start = i
            break
    if tools_start is None:
        print("RESULT|G|FAIL|top-level 'tools:' key not found")
        return

    tools_end = len(lines)
    for i in range(tools_start + 1, len(lines)):
        if lines[i].strip() == 'defaults:':
            tools_end = i
            break

    entries = []       # [{id, line, keys:{name:count}, matrix_rows:[{line, fields:{}}]}]
    orphans = []        # [(line_no, key)]
    cur = None

    for offset in range(tools_start + 1, tools_end):
        raw = lines[offset]
        ln = offset + 1  # 1-based
        stripped = raw.strip()
        if stripped == '' or stripped.startswith('#'):
            continue
        ind = indent_of(raw)
        if ind == 2 and stripped.startswith('- id:'):
            if cur is not None:
                entries.append(cur)
            cur = {'id': stripped.split(':', 1)[1].strip(), 'line': ln,
                   'keys': {}, 'matrix_rows': []}
            continue
        if ind == 4:
            key = stripped.split(':', 1)[0].strip()
            if cur is None:
                orphans.append((ln, key))
                continue
            cur['keys'][key] = cur['keys'].get(key, 0) + 1
            continue
        if ind == 6 and stripped.startswith('- os:'):
            if cur is not None:
                cur['matrix_rows'].append({'line': ln, 'fields': {}})
            continue
        if ind == 8 and cur is not None and cur['matrix_rows']:
            key = stripped.split(':', 1)[0].strip()
            val = stripped.split(':', 1)[1].strip() if ':' in stripped else ''
            row = cur['matrix_rows'][-1]
            row['fields'][key] = row['fields'].get(key, 0) + 1
            if key == 'install_cmd':
                row['install_cmd_val'] = val
            if key == 'requires_sudo':
                row['requires_sudo_val'] = val
            continue
        # deeper/other indents (e.g. wrapped notes) are not part of the schema — ignored
    if cur is not None:
        entries.append(cur)

    n_id = len(entries)
    def total_key(k):
        return sum(e['keys'].get(k, 0) for e in entries)
    c_purpose = total_key('purpose')
    c_fallback = total_key('fallback_behavior')
    c_matrix = total_key('matrix')

    # ── g: orphaned-mapping-key class + the count-equality that is its
    #      whole-file signature (equivalent per the brief: a deleted '- id:'
    #      line changes n_id but leaves the orphaned keys' line counts intact)
    g_pass = True
    g_msgs = []
    if orphans:
        g_pass = False
        g_msgs.append("orphaned key(s) at 4-space indent outside any active '- id:' entry: " +
                       ", ".join(f"line {ln} '{k}:'" for ln, k in orphans))
    if not (n_id == c_purpose == c_fallback == c_matrix == 9):
        g_pass = False
        g_msgs.append(f"line-count mismatch: id={n_id} purpose={c_purpose} "
                       f"fallback_behavior={c_fallback} matrix={c_matrix} (all must ==9)")
    msg = ("g: id/purpose/fallback_behavior/matrix line counts all ==9, no orphaned keys"
           if g_pass else "; ".join(g_msgs))
    print(f"RESULT|G|{'PASS' if g_pass else 'FAIL'}|{msg}")

    # ── a (raw): every entry has exactly one of each required key ──
    a_pass = True
    a_msgs = []
    for e in entries:
        for k in ('used_by', 'purpose', 'fallback_behavior', 'matrix'):
            c = e['keys'].get(k, 0)
            if c != 1:
                a_pass = False
                a_msgs.append(f"id={e['id']} (line {e['line']}): '{k}:' appears {c}x (want 1)")
    msg = ("a(raw): every entry has exactly one used_by/purpose/fallback_behavior/matrix"
           if a_pass else "; ".join(a_msgs))
    print(f"RESULT|A_RAW|{'PASS' if a_pass else 'FAIL'}|{msg}")

    # ── d: every sudo install_cmd carries requires_sudo: true on the same row ──
    d_pass = True
    d_msgs = []
    for e in entries:
        for row in e['matrix_rows']:
            cmd = row.get('install_cmd_val', '')
            if 'sudo ' in cmd:
                flag = row.get('requires_sudo_val', '').strip().lower()
                if flag != 'true':
                    d_pass = False
                    d_msgs.append(f"id={e['id']} row line {row['line']}: install_cmd has "
                                   f"'sudo ' but requires_sudo: true is missing/false (got '{flag or '<absent>'}')")
    msg = ("d: every sudo install_cmd carries requires_sudo: true on the same row"
           if d_pass else "; ".join(d_msgs))
    print(f"RESULT|D|{'PASS' if d_pass else 'FAIL'}|{msg}")

    # ── e: never-curl|bash contract ──
    e_pass = True
    e_msgs = []
    for e_entry in entries:
        for row in e_entry['matrix_rows']:
            cmd = row.get('install_cmd_val', '')
            for banned in ('curl', 'wget', '| bash'):
                if banned in cmd:
                    e_pass = False
                    e_msgs.append(f"id={e_entry['id']} row line {row['line']}: install_cmd "
                                   f"contains banned token '{banned}': {cmd}")
    msg = ("e: no install_cmd contains curl / wget / '| bash'"
           if e_pass else "; ".join(e_msgs))
    print(f"RESULT|E|{'PASS' if e_pass else 'FAIL'}|{msg}")

    print("IDS|" + ",".join(e['id'] for e in entries))

if __name__ == '__main__':
    main()
PYRAW

# ──────────────────────────────────────────────────────────────────────────
# yaml_checks.py — pyyaml-based dict-shaped assertions. Deliberately does
# NOT re-attempt to detect the duplicate-key merge (a dict cannot see it —
# that is raw_checks.py's job); this layer catches missing/malformed keys
# on the parsed shape and the defaults-block cross-reference.
# ──────────────────────────────────────────────────────────────────────────
cat > "$WORK/yaml_checks.py" <<'PYYAML'
import sys
import yaml

def main():
    path = sys.argv[1]
    try:
        doc = yaml.safe_load(open(path, encoding='utf-8'))
    except Exception as ex:
        print(f"RESULT|A_YAML|FAIL|yaml parse error: {ex}")
        print(f"RESULT|B|FAIL|yaml parse error: {ex}")
        print(f"RESULT|C|FAIL|yaml parse error: {ex}")
        print(f"RESULT|F|FAIL|yaml parse error: {ex}")
        return

    tools = doc.get('tools') or []
    defaults = doc.get('defaults') or {}

    # ── a (yaml): every parsed entry has the required keys, non-empty ──
    required = ['id', 'used_by', 'purpose', 'fallback_behavior', 'matrix']
    a_pass = True
    a_msgs = []
    for i, t in enumerate(tools):
        if not isinstance(t, dict):
            a_pass = False
            a_msgs.append(f"tools[{i}] is not a mapping")
            continue
        for k in required:
            if k not in t or t[k] in (None, '', []):
                a_pass = False
                a_msgs.append(f"tools[{i}] id={t.get('id', '?')}: missing/empty '{k}'")
    msg = ("a(yaml): every parsed tool has id/used_by/purpose/fallback_behavior/matrix"
           if a_pass else "; ".join(a_msgs))
    print(f"RESULT|A_YAML|{'PASS' if a_pass else 'FAIL'}|{msg}")

    # ── b: tool count == 9 AND id set == union(defaults.* groups) ──
    ids = [t.get('id') for t in tools if isinstance(t, dict)]
    id_set = set(ids)
    group_names = ['required_tools', 'recommended_minimum', 'fsd_extension', 'code_gates', 'full_stack']
    union = set()
    for g in group_names:
        union |= set(defaults.get(g) or [])
    count_ok = len(ids) == 9 and len(id_set) == 9
    union_ok = union == id_set
    b_pass = count_ok and union_ok
    msg = (f"b: tool count={len(ids)} unique={len(id_set)} (want 9); "
           f"union(defaults groups)==tool-id-set: {union_ok} "
           f"(union={sorted(union)} ids={sorted(id_set)})")
    print(f"RESULT|B|{'PASS' if b_pass else 'FAIL'}|{msg}")

    # ── c: every matrix row has os/pkg_mgr/install_cmd/verify_cmd/size_mb ──
    row_req = ['os', 'pkg_mgr', 'install_cmd', 'verify_cmd', 'size_mb']
    c_pass = True
    c_msgs = []
    for t in tools:
        if not isinstance(t, dict):
            continue
        rows = t.get('matrix') or []
        if not rows:
            c_pass = False
            c_msgs.append(f"id={t.get('id')}: matrix has no rows")
            continue
        for j, row in enumerate(rows):
            if not isinstance(row, dict):
                c_pass = False
                c_msgs.append(f"id={t.get('id')} row[{j}]: not a mapping")
                continue
            for k in row_req:
                if k not in row or row[k] in (None, ''):
                    c_pass = False
                    c_msgs.append(f"id={t.get('id')} row[{j}]: missing/empty '{k}'")
    msg = ("c: every matrix row has os/pkg_mgr/install_cmd/verify_cmd/size_mb"
           if c_pass else "; ".join(c_msgs))
    print(f"RESULT|C|{'PASS' if c_pass else 'FAIL'}|{msg}")

    # ── f: every defaults group is a subset of tool ids ──
    f_pass = True
    f_msgs = []
    for g in group_names:
        members = set(defaults.get(g) or [])
        extra = members - id_set
        if extra:
            f_pass = False
            f_msgs.append(f"defaults.{g} names id(s) not in tools[]: {sorted(extra)}")
    msg = ("f: every defaults group is a subset of tool ids" if f_pass else "; ".join(f_msgs))
    print(f"RESULT|F|{'PASS' if f_pass else 'FAIL'}|{msg}")

if __name__ == '__main__':
    main()
PYYAML

# ── helpers: run a check-script against a file, apply/inspect its RESULT lines ──
apply_results() {
  # $1 = captured stdout of a check script; every RESULT|NAME|STATUS|msg line
  # becomes an ok()/fail() call. Uses a here-string (not a pipe) so fail()
  # mutates FAILED in THIS shell, not a subshell.
  local out="$1" tag name status msg
  while IFS='|' read -r tag name status msg; do
    [ "$tag" = "RESULT" ] || continue
    if [ "$status" = "PASS" ]; then ok "$msg"; else fail "$msg"; fi
  done <<< "$out"
}

expect_fail() {
  # $1 = captured stdout, $2 = RESULT name to inspect, $3 = human label.
  # Used by mutation probes: we WANT this specific check to report FAIL —
  # that proves the detector fires on the corrupted copy.
  local out="$1" name="$2" label="$3" line
  line=$(printf '%s\n' "$out" | grep "^RESULT|${name}|" | head -1)
  if printf '%s\n' "$line" | grep -q "^RESULT|${name}|FAIL|"; then
    ok "${label} — detector fired (${line#RESULT|"$name"|FAIL|})"
  else
    fail "${label} — detector did NOT fire (got: ${line:-<no RESULT|$name| line>})"
  fi
}

run_raw()  { python3 "$WORK/raw_checks.py" "$1" 2>&1; }
run_yaml() { [ -n "$PYBIN" ] && "$PYBIN" "$WORK/yaml_checks.py" "$1" 2>&1; }

# ════════════════════════════════════════════════════════════════════════
# Baseline: current tool-matrix.yaml (believed-good, commit 8f93566) —
# every assertion must PASS.
# ════════════════════════════════════════════════════════════════════════
note ""
note "-- baseline: current tool-matrix.yaml --"
RAW_OUT="$(run_raw "$TM")"
apply_results "$RAW_OUT"
if [ -n "$PYBIN" ]; then
  YAML_OUT="$(run_yaml "$TM")"
  apply_results "$YAML_OUT"
else
  note "SKIP: a(yaml)/b/c/f — no pyyaml available this session"
fi

# ════════════════════════════════════════════════════════════════════════
# Mutation probes — TEMP COPIES ONLY. Each probe proves a detector fires;
# the real tool-matrix.yaml is never touched.
# ════════════════════════════════════════════════════════════════════════
note ""
note "-- mutation probes (temp copies; real file untouched) --"

# Probe 1 (g) — replay the historical corruption: drop the '- id: pandoc'
# list-item line. purpose/fallback_behavior/matrix/used_by for what was
# pandoc silently merge into the preceding entry (jd) under YAML duplicate-
# key semantics.
cp "$TM" "$WORK/probe-orphan.yaml"
python3 - "$WORK/probe-orphan.yaml" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding='utf-8').read().splitlines(keepends=True)
out = [l for l in lines if l.strip() != '- id: pandoc']
assert len(out) == len(lines) - 1, "expected to drop exactly one line"
open(p, 'w', encoding='utf-8').writelines(out)
PY
OUT="$(run_raw "$WORK/probe-orphan.yaml")"
expect_fail "$OUT" "G" "probe(g): dropped '- id: pandoc' line (historical corruption replay)"
expect_fail "$OUT" "A_RAW" "probe(g): same mutation, per-entry duplicate-key cross-check"
if [ -n "$PYBIN" ]; then
  YOUT="$(run_yaml "$WORK/probe-orphan.yaml")"
  expect_fail "$YOUT" "B" "probe(g): same mutation, yaml-parsed tool count drops to 8 (cross-validated)"
fi

# Probe 1b (g) — drop the FIRST entry's '- id:' line: its keys then appear
# before ANY active list item, so the orphans-list branch (cur is None) fires
# directly (v5.3.2 — closes the unprobed-branch review note).
cp "$TM" "$WORK/probe-orphan-first.yaml"
python3 - "$WORK/probe-orphan-first.yaml" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding='utf-8').read().splitlines(keepends=True)
out = [l for l in lines if l.strip() != '- id: ast-grep']
assert len(out) == len(lines) - 1, "expected to drop exactly one line"
open(p, 'w', encoding='utf-8').writelines(out)
PY
OUT="$(run_raw "$WORK/probe-orphan-first.yaml")"
expect_fail "$OUT" "G" "probe(g): dropped FIRST '- id:' line — orphans-list (cur is None) branch fires"

# Probe 2 (e) — inject a curl | bash install_cmd (never-curl|bash contract).
cp "$TM" "$WORK/probe-curlbash.yaml"
python3 - "$WORK/probe-curlbash.yaml" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
old = '        install_cmd: "brew install pandoc"\n'
new = '        install_cmd: "curl -fsSL https://example.com/install.sh | bash"\n'
assert old in t, "fixture line not found — tool-matrix.yaml shape changed"
open(p, 'w', encoding='utf-8').write(t.replace(old, new, 1))
PY
OUT="$(run_raw "$WORK/probe-curlbash.yaml")"
expect_fail "$OUT" "E" "probe(e): install_cmd rewritten to 'curl ... | bash'"

# Probe 3 (d) — sudo install_cmd with requires_sudo: true stripped from
# that same row.
cp "$TM" "$WORK/probe-sudo.yaml"
python3 - "$WORK/probe-sudo.yaml" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
old = ('        install_cmd: "sudo apt install -y ripgrep"\n'
       '        requires_sudo: true\n')
new = '        install_cmd: "sudo apt install -y ripgrep"\n'
assert old in t, "fixture line not found — tool-matrix.yaml shape changed"
open(p, 'w', encoding='utf-8').write(t.replace(old, new, 1))
PY
OUT="$(run_raw "$WORK/probe-sudo.yaml")"
expect_fail "$OUT" "D" "probe(d): requires_sudo: true stripped from a sudo install_cmd row"

# Probe 4 (a) — drop the 'used_by:' line only (id stays, so g's count
# formula stays green; a must catch this on its own).
cp "$TM" "$WORK/probe-usedby.yaml"
python3 - "$WORK/probe-usedby.yaml" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding='utf-8').read().splitlines(keepends=True)
# remove only the FIRST 'used_by:' occurrence matching the ast-grep entry's value —
# the same value can repeat verbatim on other entries, so an
# unqualified strip would drop more than one line.
removed = False
result = []
for l in lines:
    if not removed and l.strip() == 'used_by: [scan-codebase]':
        removed = True
        continue
    result.append(l)
assert removed, "fixture line 'used_by: [scan-codebase]' not found"
open(p, 'w', encoding='utf-8').writelines(result)
PY
OUT="$(run_raw "$WORK/probe-usedby.yaml")"
expect_fail "$OUT" "A_RAW" "probe(a): dropped a 'used_by:' line (id/purpose/fallback/matrix counts stay ==9, only a(raw) catches it)"
if [ -n "$PYBIN" ]; then
  YOUT="$(run_yaml "$WORK/probe-usedby.yaml")"
  expect_fail "$YOUT" "A_YAML" "probe(a): same mutation, yaml-based required-key check"
fi

# Probe 5 (c) — drop 'size_mb:' from one matrix row.
if [ -n "$PYBIN" ]; then
  cp "$TM" "$WORK/probe-sizemb.yaml"
  python3 - "$WORK/probe-sizemb.yaml" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding='utf-8').read().splitlines(keepends=True)
# remove only the FIRST 'size_mb:' occurrence (an arbitrary matrix row)
removed = False
result = []
for l in lines:
    if not removed and l.strip() == 'size_mb: 5':
        removed = True
        continue
    result.append(l)
assert removed, "fixture line 'size_mb: 5' not found"
open(p, 'w', encoding='utf-8').writelines(result)
PY
  YOUT="$(run_yaml "$WORK/probe-sizemb.yaml")"
  expect_fail "$YOUT" "C" "probe(c): dropped a 'size_mb:' row"
fi

# Probe 6 (b/f) — inject a bogus id into a defaults group that no tool
# actually has (breaks both b's union==id_set and f's subset check).
if [ -n "$PYBIN" ]; then
  cp "$TM" "$WORK/probe-defaults.yaml"
  python3 - "$WORK/probe-defaults.yaml" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
old = "  code_gates: [semgrep, gitleaks]"
new = "  code_gates: [semgrep, gitleaks, nonexistent-tool]"
assert old in t, "fixture line not found — defaults block shape changed"
open(p, 'w', encoding='utf-8').write(t.replace(old, new, 1))
PY
  YOUT="$(run_yaml "$WORK/probe-defaults.yaml")"
  expect_fail "$YOUT" "B" "probe(b): defaults.code_gates names 'nonexistent-tool' (union != id set)"
  expect_fail "$YOUT" "F" "probe(f): same mutation, defaults.code_gates not a subset of tool ids"
fi

# Check h (audit phase-1) — every used_by entry resolves to a live skill dir
# (or the 'hooks' layer). Rot class: the v5.3.1 lesson resurfaced at the
# 2026-08-10 audit — jd pointed at the removed 'replay', markdownlint-cli2 at
# the removed 'lint-units'.
SKILLS_DIR="${ROOT}/plugins/mega-sdd/skills"
usedby_scan() {
  python3 - "$1" "$SKILLS_DIR" <<'PY'
import os, re, sys
tm, skills = sys.argv[1], sys.argv[2]
live = {d for d in os.listdir(skills) if os.path.isdir(os.path.join(skills, d))}
live.add("hooks")  # the hook layer is a legitimate non-skill consumer
bad = []
for m in re.finditer(r'used_by:\s*\[([^\]]*)\]', open(tm, encoding='utf-8').read()):
    for name in m.group(1).split(','):
        name = name.strip()
        if name and name not in live:
            bad.append(name)
print(("H-FAIL " + " ".join(sorted(set(bad)))) if bad else "H-OK")
PY
}
HOUT="$(usedby_scan "$TM")"
case "$HOUT" in
  H-OK) ok "h: every used_by entry resolves to a live skill dir (or hooks)" ;;
  *)    fail "h: used_by names nonexistent skill(s): ${HOUT#H-FAIL }" ;;
esac

# Probe 7 (h) — replay the historical rot on a TEMP COPY; the detector must fire.
cp "$TM" "$WORK/probe-usedby.yaml"
python3 - "$WORK/probe-usedby.yaml" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
old = "used_by: [diff-vault, execute-bolts]"
assert old in t, "fixture used_by row not found - jd row shape changed"
open(p, 'w', encoding='utf-8').write(t.replace(old, "used_by: [diff-vault, replay]", 1))
PY
HOUT2="$(usedby_scan "$WORK/probe-usedby.yaml")"
case "$HOUT2" in
  H-FAIL*) ok "probe(h): reintroduced 'replay' rot detected" ;;
  *)       fail "probe(h): rot NOT detected — check h is inert" ;;
esac

note ""
if [ "$FAILED" -eq 0 ]; then note "PASS: tool-matrix.yaml structural + parse test"; exit 0
else note "FAIL: tool-matrix.yaml structural + parse test"; exit 1
fi
