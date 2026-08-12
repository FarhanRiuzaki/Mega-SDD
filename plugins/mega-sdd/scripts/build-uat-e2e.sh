#!/usr/bin/env bash
# build-uat-e2e.sh — the UAT automated-evidence lane's generator + gate helper
# (spec 2026-08-12-playwright-embed-design.md §D2).
#
# Modes:
#   (default)  Parse the ASSEMBLED <vault>/uat/UAT.md §2 (the xlsx-builder
#              grammar) and emit ONE Playwright skeleton per scenario:
#              <vault>/uat/e2e/<UAT-id>.spec.ts — EVERY step test.fixme()
#              (all-fixme by construction; selector substitution is a MODEL
#              step gated by --check). Also writes .gitignore + a
#              self-contained playwright.config.ts (PREVIEW_URL env).
#              A spec already carrying a non-fixme line is NEVER overwritten
#              (SKIP_EXISTING — a human/model substitution is work product).
#   --check    Anchor lint (the zero-invented-selector GATE): every non-fixme
#              action line MUST carry `// source: <path>:<line>` resolving
#              against a real file under --cwd. Violations → exit 1 with
#              ANCHOR_MISSING / ANCHOR_UNRESOLVED lines.
#   --annex    Rewrite the §5 annex region of UAT.md from on-disk evidence via
#              _lib/uat_annex.py (the shared renderer check_execution
#              byte-compares — B1 recompute precedent). Atomic.
#
# Exit: 0 ok · 1 lint violations · 2 usage / missing inputs.
# Every write is atomic (tmp + os.replace). Bounded, offline, no network.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$HERE/_lib/resolve-python.sh" 2>/dev/null || PYBIN=python3
PY="${PYBIN:-python3}"

VAULTS=(); CWD=""; MODE="generate"; FORCE=0
for arg in "$@"; do
  case "$arg" in
    --vault=*) VAULTS+=("${arg#--vault=}") ;;
    --cwd=*)   CWD="${arg#--cwd=}" ;;
    --check)   MODE="check" ;;
    --annex)   MODE="annex" ;;
    --force)   FORCE=1 ;;
    *) echo "usage: build-uat-e2e.sh --vault=<dir> [--vault=<dir2> ...] --cwd=<root> [--check|--annex] [--force]" >&2; exit 2 ;;
  esac
done
[ "${#VAULTS[@]}" -ge 1 ] || { echo "usage: --vault= required" >&2; exit 2; }
[ -n "$CWD" ] || CWD="$(pwd)"
PRIMARY="${VAULTS[0]}"
[ -f "$PRIMARY/uat/UAT.md" ] || { echo "missing $PRIMARY/uat/UAT.md — run /mega-sdd:emit uat first" >&2; exit 2; }

export _UAT_E2E_VAULT="$PRIMARY" _UAT_E2E_CWD="$CWD" _UAT_E2E_MODE="$MODE" _UAT_E2E_FORCE="$FORCE" _UAT_E2E_LIB="$HERE/_lib"

exec "$PY" - <<'PYEOF'
import hashlib, json, os, re, sys, tempfile

vault = os.environ["_UAT_E2E_VAULT"]
cwd = os.environ["_UAT_E2E_CWD"]
mode = os.environ["_UAT_E2E_MODE"]
force = os.environ["_UAT_E2E_FORCE"] == "1"
sys.path.insert(0, os.environ["_UAT_E2E_LIB"])

uat_md = os.path.join(vault, "uat", "UAT.md")
e2e_dir = os.path.join(vault, "uat", "e2e")
scaffold = os.path.join(vault, "uat", ".uat-scaffold.md")

def sha256_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def atomic_write(path, text):
    d = os.path.dirname(path)
    os.makedirs(d, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".tmp-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)

# ── §2 parser (the build-uat-xlsx.sh grammar: scenario heading + 7-cell rows) ──
HEAD_RE = re.compile(r"^### (UAT-[A-Z0-9-]+) — (.*?) \((F-[A-Z0-9-]+)\)\s*$")
SEC_RE = re.compile(r"^## (\d+)\.")

def parse_scenarios():
    scenarios = []  # (uat_id, title, f_id, [step_texts])
    cur = None
    section = 0
    for line in open(uat_md, encoding="utf-8"):
        line = line.rstrip("\n")
        m = SEC_RE.match(line)
        if m:
            section = int(m.group(1))
            continue
        if section != 2:
            continue
        h = HEAD_RE.match(line)
        if h:
            cur = (h.group(1), h.group(2), h.group(3), [])
            scenarios.append(cur)
            continue
        if cur is None or not line.strip().startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) != 7 or cells[0] == "No" or set(cells[0]) <= {"-"}:
            continue
        cur[3].append((cells[0], cells[1]))  # (No, Aksi)
    return scenarios

if mode == "generate":
    scenarios = parse_scenarios()
    if not scenarios:
        print("no §2 scenarios found in UAT.md", file=sys.stderr)
        sys.exit(2)
    uat_sha = sha256_file(uat_md)
    scaf_sha = sha256_file(scaffold) if os.path.isfile(scaffold) else "0" * 64
    for uat_id, title, f_id, steps in scenarios:
        spec_path = os.path.join(e2e_dir, uat_id + ".spec.ts")
        if os.path.isfile(spec_path) and not force:
            body = open(spec_path, encoding="utf-8").read()
            # a non-fixme test line = human/model work product → never clobber
            if re.search(r"^\s*(?:test|it)\((?!\s*$)", body, re.M) or "await page." in body:
                print("SKIP_EXISTING {} (carries substituted steps; use --force to regenerate)".format(uat_id))
                continue
        lines = [
            "// generated-by: build-uat-e2e.sh",
            "// uat_md_sha256: " + uat_sha,
            "// scaffold_sha256: " + scaf_sha,
            "// Setiap langkah lahir sebagai test.fixme — substitusi selector adalah",
            "// langkah MODEL yang di-gate `build-uat-e2e.sh --check` (anchor `// source:`).",
            "import { test, expect } from '@playwright/test';",
            "",
            "test.describe('{} — {}', () => {{".format(uat_id, title.replace("'", "\\'")),
        ]
        for no, aksi in steps:
            safe = aksi.replace("\\", "\\\\").replace("'", "\\'")
            lines.append("  test.fixme('{}. {} — manual');".format(no, safe))
        lines.append("});")
        lines.append("")
        atomic_write(spec_path, "\n".join(lines))
        print("WROTE {} ({} steps, all fixme)".format(uat_id, len(steps)))
    gi = os.path.join(e2e_dir, ".gitignore")
    if not os.path.isfile(gi):
        atomic_write(gi, "node_modules/\ntest-results/\nplaywright-report/\n")
    cfg = os.path.join(e2e_dir, "playwright.config.ts")
    if not os.path.isfile(cfg):
        atomic_write(cfg, (
            "// self-contained — never mutates the target repo's package.json\n"
            "import { defineConfig } from '@playwright/test';\n"
            "export default defineConfig({\n"
            "  use: { baseURL: process.env.PREVIEW_URL, trace: 'on', screenshot: 'on' },\n"
            "});\n"
        ))
    pkg = os.path.join(e2e_dir, "package.json")
    if not os.path.isfile(pkg):
        # Own package.json — the run provisions @playwright/test HERE, never in
        # the target repo (live-proven 2026-08-12: a dep-less dir cannot resolve
        # @playwright/test from the npx cache; -p does not help the config's
        # require). Pin EXACT (registry-rot lesson); browser build must match —
        # uat-run.sh maps a mismatch to a SKIP with the install instruction.
        atomic_write(pkg, json.dumps({
            "name": "uat-e2e", "private": True,
            "devDependencies": {"@playwright/test": "1.62.1"},
        }, indent=2) + "\n")
    sys.exit(0)

if mode == "check":
    violations = 0
    # SEARCH, not line-anchored (round M2: `const btn = page.locator('#x')` —
    # variable indirection — escaped the anchored form). Any non-fixme line that
    # produces or asserts on a locator needs its anchor; the chained use of a
    # variable is covered because the DEFINITION line carries the selector.
    ACTION_RE = re.compile(r"\b(?:page\s*\.|expect\s*\()")
    ANCHOR_RE = re.compile(r"//\s*source:\s*(\S+?):(\d+)\s*$")
    if not os.path.isdir(e2e_dir):
        sys.exit(0)  # nothing generated yet — nothing to lint
    for name in sorted(os.listdir(e2e_dir)):
        if not name.endswith(".spec.ts"):
            continue
        spec = os.path.join(e2e_dir, name)
        for i, line in enumerate(open(spec, encoding="utf-8"), 1):
            if ("test.fixme(" in line or "import " in line.strip()[:7]
                    or not ACTION_RE.search(line)):
                continue
            m = ANCHOR_RE.search(line)
            if not m:
                print("ANCHOR_MISSING {}:{}".format(name, i))
                violations += 1
                continue
            path, lineno = m.group(1), int(m.group(2))
            target = os.path.join(cwd, path)
            ok = False
            if os.path.isfile(target):
                n = sum(1 for _ in open(target, "rb"))
                ok = lineno <= n
            if not ok:
                print("ANCHOR_UNRESOLVED {}:{} {}:{}".format(name, i, path, lineno))
                violations += 1
    sys.exit(1 if violations else 0)

if mode == "annex":
    import uat_annex
    body = open(uat_md, encoding="utf-8").read()
    render = uat_annex.render_annex(vault)
    lines = body.split("\n")
    # find the §5 heading; replace through EOF (annex is the last section) or append
    start = None
    for i, line in enumerate(lines):
        if line.strip() == uat_annex.ANNEX_HEADING:
            start = i
            break
    if start is None:
        new_body = body.rstrip("\n") + "\n\n" + render + "\n"
    else:
        new_body = "\n".join(lines[:start]).rstrip("\n") + "\n\n" + render + "\n"
    atomic_write(uat_md, new_body)
    print("ANNEX rewritten from evidence on disk")
    sys.exit(0)
PYEOF
