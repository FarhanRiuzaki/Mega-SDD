#!/usr/bin/env bash
# ADVISORY reuse-duplication sweep. NEVER blocks (always exits 0) — doctrine:
# duplication is judgment-adjacent, a reviewer decision, never a hook.
# (R3, spec 2026-08-02-reuse-first-grounding-index.md.)
#
# Compares symbols ADDED in a commit range against the FULL script-owned symbol
# index (.mega-sdd/codebase/symbol-index.json — v5.28.0), falling back to the
# deep-scan reuse-index.yaml names when the index is absent. Match classes:
#   exact             same name, different file
#   case-shape        camelCase / snake_case / PascalCase spellings of one name
#   same-suffix-root  bare root <-> verb-prefixed, both directions
#   verb-synonym      get/fetch/load/find-prefixed spellings of one root
# The just-committed symbol itself (same file + same name in the index) is
# never reported — that is the definition, not a duplicate.
#
# Usage:
#   validate-reuse-duplication.sh [<cwd>] [--cwd=<dir>] [--range=<a>..<b>] [--json]
#     default range: HEAD~1..HEAD (the pre-R3 behavior)
#     --json: machine rows for the code-quality lens prompt (review-panel.md —
#             machine fact like the L0 block; empty rows → "rows": [])
# Human mode keeps the pre-R3 "[reuse-dup]" line contract for analyze.
#
# Honest bounds: the ADDED-side regex catches keyword-led definitions
# (function/def/fn/func/class/const-arrow); keyword-less method styles
# (C#/Java/Kotlin members) are NOT detected on the added side even though the
# index sees them — an accepted asymmetry, disclosed in spec R3. On a merge
# commit the default HEAD~1..HEAD is the first-parent diff (the whole merged
# branch re-reports); the review panel always passes an explicit --range.
# Match classes gained same-suffix-root at round fold (bare root <-> verb-
# prefixed, both directions); rows are class-sorted and capped at 40.

set -u
CWD=""; RANGE="HEAD~1..HEAD"; JSON=0; BAD=""
for arg in "$@"; do
  case "$arg" in
    --cwd=*)   CWD="${arg#--cwd=}" ;;
    --range=*) RANGE="${arg#--range=}" ;;
    --json)    JSON=1 ;;
    --*)       BAD="$arg" ;;
    *)         [ -z "$CWD" ] && CWD="$arg" ;;
  esac
done
skip0() { # advisory skip that HONORS --json (an evidence caller always gets an envelope)
  if [ "$JSON" = "1" ]; then printf '{"rows":[],"count":0,"truncated":0,"note":"%s"}\n' "$1"; else echo "[reuse-dup] $1"; fi
  exit 0
}
[ -z "$BAD" ] || skip0 "unknown flag $BAD (advisory — skipping)"
[ -n "$CWD" ] || CWD="$PWD"
[ -d "$CWD" ] || skip0 "cwd not a directory — skipping (advisory)"

CWD="$CWD" RANGE="$RANGE" JSON="$JSON" python3 <<'PYEOF'
import json, os, re, subprocess, sys

cwd = os.environ["CWD"]; rng = os.environ["RANGE"]; as_json = os.environ["JSON"] == "1"

def out(msg):
    if not as_json:
        print(msg)

def finish(rows, note=None):
    if as_json:
        print(json.dumps({"rows": rows, "count": len(rows), "truncated": 0, "note": note},
                         separators=(",", ":")))
    else:
        if note:
            out("[reuse-dup] " + note)
        out("[reuse-dup] advisory scan complete — %d possible duplication(s). (non-blocking)" % len(rows))
    sys.exit(0)

# ── the existing-symbol corpus: FULL index first, slice yaml as fallback ────
IDX = os.path.join(cwd, ".mega-sdd", "codebase", "symbol-index.json")
YAML = os.path.join(cwd, ".mega-sdd", "codebase", "reuse-index.yaml")
corpus = []  # (name, file, line, signature, source)
src_note = None
try:
    d = json.load(open(IDX, encoding="utf-8"))
    if not isinstance(d, dict):
        raise ValueError("top-level is not an object")
    for s in d.get("symbols") or []:
        if isinstance(s, dict) and s.get("name") and s.get("name") != "?":
            corpus.append((str(s["name"]), str(s.get("file") or ""),
                           s.get("line"), str(s.get("signature") or "")[:120],
                           "symbol-index"))
except (OSError, ValueError, AttributeError, TypeError):
    pass  # unreadable/mis-shaped index -> the yaml fallback lane below
if not corpus:
    try:
        text = open(YAML, encoding="utf-8").read()
        for m in re.finditer(r"name: ([A-Za-z_][A-Za-z0-9_]*)", text):
            corpus.append((m.group(1), "", None, "", "reuse-index.yaml"))
        src_note = "symbol-index.json absent — matched against reuse-index.yaml names only (slice coverage; run scripts/build-symbol-index.sh for the full corpus)"
    except OSError:
        finish([], "no symbol-index.json and no reuse-index.yaml — skipping (advisory)")
if not corpus:
    finish([], src_note or "empty corpus — skipping (advisory)")

# ── symbols ADDED in the range (diff + lines, file attribution kept) ────────
try:
    # config-pinned: quotepath (unicode paths stay literal), noprefix (the
    # +++ b/ parse must hold), external diff drivers OFF (a driver silently
    # zeroes the sweep) — all three are field-verified defeat vectors
    p = subprocess.run(["git", "-c", "core.quotepath=false", "-c", "diff.noprefix=false",
                        "-c", "diff.external=", "diff", "--no-color", "--no-ext-diff",
                        "--unified=0", rng],
                       cwd=cwd, capture_output=True, text=True, errors="replace",
                       timeout=30, stdin=subprocess.DEVNULL)
except (subprocess.TimeoutExpired, OSError):
    finish([], "git diff unavailable — skipping (advisory)")
if p.returncode != 0:
    finish([], "git diff %s failed — skipping (advisory)" % rng)

DEF_RE = re.compile(r"""^\+\s*(?:export\s+)?(?:default\s+)?(?:public\s+|private\s+|protected\s+|internal\s+|static\s+|final\s+|async\s+|abstract\s+|pub(?:\([^)]*\))?\s+)*
    (?:function\s+|def\s+|fn\s+|func\s+(?:\([^)]*\)\s*)?|class\s+|interface\s+|trait\s+|struct\s+|module\s+
      |(?:const|let|var)\s+(?=[A-Za-z_][A-Za-z0-9_]*\s*=\s*(?:async\s*)?(?:\(|[A-Za-z_$][\w$]*\s*=>|function\b)))
    ([A-Za-z_][A-Za-z0-9_]*)""", re.VERBOSE)

NON_CODE = (".md", ".markdown", ".yml", ".yaml", ".json", ".txt", ".rst", ".csv")
added, cur_file = [], ""
for line in p.stdout.split("\n"):
    if line.startswith("+++ b/"):
        cur_file = line[6:]
        continue
    if cur_file.lower().endswith(NON_CODE):
        continue  # a fenced code block in a doc diff is prose, not a symbol
    m = DEF_RE.match(line)
    if m:
        added.append((m.group(1), cur_file))

if not added:
    finish([], src_note)

# ── matcher: exact / case-shape / verb-synonym ──────────────────────────────
VERBS = ("get", "fetch", "load", "find")

def shape(n):
    return re.sub(r"_", "", n).lower()

def root(n):
    # verb-stripped root; short roots (<3 chars) are noise, not signal
    sh = shape(n)
    for v in VERBS:
        if sh.startswith(v) and len(sh) - len(v) >= 3:
            return sh[len(v):]
    return None

CLS_ORDER = {"exact": 0, "case-shape": 1, "same-suffix-root": 2, "verb-synonym": 3}
by_shape, by_root = {}, {}
for c in corpus:
    by_shape.setdefault(shape(c[0]), []).append(c)
    r = root(c[0])
    if r:
        by_root.setdefault(r, []).append(c)

rows, seen = [], set()
for name, nfile in added:
    cands = []
    for c in by_shape.get(shape(name), []):
        cls = "exact" if c[0] == name else "case-shape"
        cands.append((cls, c))
    r = root(name)
    if r:
        for c in by_root.get(r, []):
            if shape(c[0]) != shape(name):
                cands.append(("verb-synonym", c))
        # verb-prefixed NEW vs bare-root corpus (getUserBalance vs userBalance)
        for c in by_shape.get(r, []):
            cands.append(("same-suffix-root", c))
    if len(shape(name)) >= 3:
        # bare NEW vs verb-prefixed corpus (accountTotal vs getAccountTotal)
        for c in by_root.get(shape(name), []):
            cands.append(("same-suffix-root", c))
    for cls, c in cands:
        cname, cfile, cline, csig, csrc = c
        if cname == name and cfile == nfile:
            continue  # the added definition itself (index refreshed post-commit)
        key = (name, nfile, cname, cfile)
        if key in seen:
            continue  # one row per pair — the strongest class wins via sort below
        seen.add(key)
        rows.append({"new_name": name, "new_file": nfile, "match_name": cname,
                     "match_file": cfile, "match_line": cline,
                     "match_class": cls, "signature": csig, "source": csrc})

# strongest classes first, then CAP — the quality-lens prompt must never be
# flooded (parity with R2's 40-row level-0 cap on the sibling symbol_slice)
rows.sort(key=lambda r: (CLS_ORDER.get(r["match_class"], 9), r["new_name"], r["match_file"]))
truncated = max(0, len(rows) - 40)
rows = rows[:40]
for r in rows:
    loc = "%s:%s" % (r["match_file"], r["match_line"]) if r["match_file"] else "reuse-index.yaml (see _source)"
    out("[reuse-dup][WARN] new '%s' (%s) may reinvent existing '%s' (%s) [%s]. Verify before merge."
        % (r["new_name"], r["new_file"], r["match_name"], loc, r["match_class"]))
if truncated:
    out("[reuse-dup] +%d more suppressed (strongest 40 shown)" % truncated)

def finish2(rows, note=None):
    if as_json:
        print(json.dumps({"rows": rows, "count": len(rows), "truncated": truncated,
                          "note": note}, separators=(",", ":")))
    else:
        if note:
            out("[reuse-dup] " + note)
        out("[reuse-dup] advisory scan complete — %d possible duplication(s). (non-blocking)" % len(rows))
    sys.exit(0)

finish2(rows, src_note)
PYEOF
exit 0
