#!/usr/bin/env bash
# build-symbol-index.sh — the script-owned full-repo symbol index (R1, spec
# 2026-08-02-reuse-first-grounding-index.md).
#
# ONE bounded ast-grep pass over the enumerated source set →
# .mega-sdd/codebase/symbol-index.json. Zero model tokens: mechanical bytes
# never transit the model (the 5e-builder seam applied to scan). The index is
# ADVISORY reuse substrate — recomputable derived state; no gate trusts it.
#
# Usage:
#   build-symbol-index.sh [--cwd=<dir>] [--out=<path>] [--timeout=<sec>]
# Exit: 0 written · 2 usage · 3 ast-grep missing (one-line stderr; caller
#       records the absence honestly — never fake an index) · 4 build failed.
#
# Determinism: identical tree + identical ast-grep version → byte-identical
# index (rows deduped (file,line,ruleId), sorted (file,line,kind);
# generated_at excluded from that guarantee, everything else included).

set -u
CWD="."; OUT=""; TIMEOUT=120
for arg in "$@"; do
  case "$arg" in
    --cwd=*)     CWD="${arg#--cwd=}" ;;
    --out=*)     OUT="${arg#--out=}" ;;
    --timeout=*) TIMEOUT="${arg#--timeout=}" ;;
    *) echo "usage: build-symbol-index.sh [--cwd=<dir>] [--out=<path>] [--timeout=<sec>]" >&2; exit 2 ;;
  esac
done
[ -d "$CWD" ] || { echo "build-symbol-index.sh: --cwd not a directory: $CWD" >&2; exit 2; }
case "$TIMEOUT" in ''|*[!0-9]*) echo "build-symbol-index.sh: --timeout must be a positive integer" >&2; exit 2 ;; esac
[ -n "$OUT" ] || OUT="$CWD/.mega-sdd/codebase/symbol-index.json"

command -v ast-grep >/dev/null 2>&1 || {
  echo "build-symbol-index.sh: ast-grep not installed — no symbol index (install: brew/scoop install ast-grep, or /mega-sdd:install-deps)" >&2
  exit 3
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKS_DIR="${SCRIPT_DIR}/../skills/scan-codebase/queries/astgrep"
[ -d "$PACKS_DIR" ] || { echo "build-symbol-index.sh: rule packs missing at $PACKS_DIR" >&2; exit 4; }

CWD="$CWD" OUT="$OUT" TIMEOUT="$TIMEOUT" PACKS_DIR="$PACKS_DIR" python3 <<'PYEOF'
import json, os, re, subprocess, sys

cwd = os.environ["CWD"]; out = os.environ["OUT"]
timeout_s = max(1, int(os.environ["TIMEOUT"]))
packs_dir = os.environ["PACKS_DIR"]

# Extensions covered by the shipped packs (membership-only gate for the file
# enumeration — ast-grep assigns each file's language by its own ext mapping,
# so the values here are documentation of WHICH pack's lane covers the ext).
# .jsx maps to javascript (ast-grep's js grammar parses JSX; jsx.yml must
# never exist — it would double-count every .jsx symbol).
EXTS = {".ts": "typescript", ".tsx": "tsx", ".js": "javascript",
        ".jsx": "javascript", ".mjs": "javascript", ".cjs": "javascript",
        ".php": "php", ".py": "python", ".rs": "rust", ".go": "go",
        ".rb": "ruby", ".java": "java", ".cs": "csharp",
        ".kt": "kotlin", ".kts": "kotlin", ".swift": "swift",
        ".scala": "scala", ".c": "c", ".h": "c",
        ".cpp": "cpp", ".cc": "cpp", ".cxx": "cpp", ".hpp": "cpp", ".hh": "cpp",
        ".dart": "dart", ".ex": "elixir", ".exs": "elixir",
        ".lua": "lua", ".sh": "bash", ".bash": "bash", ".hs": "haskell"}
# Committed dirs git ls-files can still admit (exclusions.md is the owner of
# the full list). Segment-based, so a nested packages/app/node_modules/ is
# excluded too — matching the list's `**` semantics.
# any-depth: dependency trees + caches (nested packages/app/node_modules too)
EXCL_DIR_NAMES = {"node_modules", "vendor", "__pycache__", ".venv", "venv",
                  ".next", ".nuxt", ".svelte-kit", ".astro", ".turbo", ".git",
                  ".mega-sdd", "bower_components", ".yarn", ".pnpm-store",
                  ".gradle", ".cache", ".parcel-cache", ".pytest_cache",
                  ".mypy_cache", ".ruff_cache", ".tox", "htmlcov",
                  ".nyc_output", ".bundle"}
# top-level only: these names are legitimate NESTED source dirs (cargo's
# src/bin/*.rs multi-binary convention, go cmd trees) — pruning them anywhere
# drops real tracked source (round-2 finding B9)
EXCL_TOP = ("bin/", "obj/", "out/", "build/", "target/", "env/", "dist/",
            "coverage/", "storage/framework/", "bootstrap/cache/",
            "public/build/", "public/hot/")

def excluded(relpath):
    return relpath.startswith(EXCL_TOP) or            any(seg in EXCL_DIR_NAMES for seg in relpath.split("/")[:-1])

def run(cmd, tmo, inp=None):
    # bounded child process (repo law: every child gets a hard timeout)
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                          errors="replace", timeout=tmo, input=inp,
                          stdin=(None if inp is not None else subprocess.DEVNULL))

# ── enumerate: git ls-files (tracked, .gitignore-honoring) or find fallback ──
files, git_ok = [], False
try:
    p = run(["git", "ls-files", "-z"], 30)
    if p.returncode == 0:
        git_ok = True  # an EMPTY tracked list is an answer, not a fallback trigger
        files = [f for f in p.stdout.split("\0") if f]
except (subprocess.TimeoutExpired, OSError):
    pass
if not git_ok:
    # non-git tree: walk with the same prune prefixes
    for root, dirs, names in os.walk(cwd):
        rel = os.path.relpath(root, cwd)
        rel = "" if rel == "." else rel.replace(os.sep, "/") + "/"
        dirs[:] = [d for d in dirs
                   if d not in EXCL_DIR_NAMES and not (rel + d + "/").startswith(EXCL_TOP)]
        for n in names:
            files.append(rel + n)

files = sorted(f for f in files
               if os.path.splitext(f)[1] in EXTS and not excluded(f))

head = None
try:
    p = run(["git", "rev-parse", "--verify", "HEAD^{commit}"], 15)
    if p.returncode == 0:
        head = p.stdout.strip()
except (subprocess.TimeoutExpired, OSError):
    pass

agv = None
try:
    p = run(["ast-grep", "--version"], 15)
    if p.returncode == 0 and p.stdout.strip():
        m = re.search(r"\d+\.\d+[\w.\-]*", p.stdout.strip().splitlines()[0])
        agv = m.group(0) if m else None
except (subprocess.TimeoutExpired, OSError):
    pass

# ── one ast-grep pass, chunked only if argv would overflow ──────────────────
rules_parts = []
for f in sorted(os.listdir(packs_dir)):
    if f.endswith(".yml"):
        rules_parts.append(open(os.path.join(packs_dir, f), encoding="utf-8").read().strip())
rules = "\n---\n".join(rules_parts)

matches = []
# Chunk by BYTES, not path count: deep paths overflow ARG_MAX (macOS 1MB shared
# with env + the ~5.5KB inline rules) long before any fixed count is "safe".
CHUNK_BYTES = 262144
chunks, cur, cur_b = [], [], 0
for f in files:
    fb = len(f.encode("utf-8", "replace")) + 1
    if cur and cur_b + fb > CHUNK_BYTES:
        chunks.append(cur); cur, cur_b = [], 0
    cur.append(f); cur_b += fb
if cur:
    chunks.append(cur)
for chunk in chunks:
    try:
        # "--" ends option parsing: a tracked file named "-r.py" must be a PATH,
        # never an ast-grep flag (round-2 ship-blocker B1)
        p = run(["ast-grep", "scan", "--inline-rules", rules, "--json=compact", "--"] + chunk,
                timeout_s)
    except subprocess.TimeoutExpired:
        print("build-symbol-index.sh: ast-grep pass timed out (%ss)" % timeout_s, file=sys.stderr)
        sys.exit(4)
    except OSError as e:
        print("build-symbol-index.sh: ast-grep exec failed: %s" % e, file=sys.stderr)
        sys.exit(4)
    if p.returncode != 0:
        print("build-symbol-index.sh: ast-grep failed rc=%s: %s"
              % (p.returncode, p.stderr.strip().splitlines()[:1]), file=sys.stderr)
        sys.exit(4)
    try:
        matches.extend(json.loads(p.stdout or "[]"))
    except ValueError:
        print("build-symbol-index.sh: unparseable ast-grep output", file=sys.stderr)
        sys.exit(4)

# ── normalize: 1-based lines, first-line signature, per-kind name parse ─────
NAME_RE = re.compile(r"""(?:
    (?:function|class|interface|trait|enum|struct|type|module|def|fn|func|record)\s+([A-Za-z_][A-Za-z0-9_]*)
  | ([A-Za-z_][A-Za-z0-9_]*)\s*[(:=]
)""", re.VERBOSE)

# Glossary-language name derivation (round SB-3b/IM-2: the generic NAME_RE was
# written for the original 9 packs — on the new languages it named Haskell
# bindings after their LAST PARAMETER, typedefs "struct", enum classes "class",
# Scala objects "?"). Ordered per-ruleId branches; NAME_RE stays the fallback
# so the original 9 languages' behavior is byte-identical.
def _kw_name(sig, kws, dotted=False):
    ident = r"[A-Za-z_][\w.]*" if dotted else r"[A-Za-z_]\w*"
    m = re.search(r"(?:^|\s)(?:%s)\s+(%s)" % ("|".join(kws), ident), sig)
    return m.group(1) if m else None

def parse_name(sig, kind):
    if kind == "haskell-function":
        # `add x y = ...` — the binding name is the FIRST token, never the
        # last-parameter-before-= that NAME_RE's [(:=] alternation grabs
        m = re.match(r"([A-Za-z_]\w*)", sig)
        return m.group(1) if m else None
    if kind == "c-typedef":
        # `typedef struct point point_t;` — the introduced name is the tail
        m = re.search(r"(?:\(\s*\*\s*)?([A-Za-z_]\w*)\s*\)?\s*(?:\([^)]*\))?\s*;\s*$", sig)
        return m.group(1) if m else None
    if kind in ("kotlin-class", "cpp-enum", "c-enum"):
        # `enum class Color` must name Color, not "class"
        m = re.search(r"(?:enum\s+class|class|interface|enum|struct)\s+([A-Za-z_]\w*)", sig)
        return m.group(1) if m else None
    if kind == "kotlin-companion-object":
        m = re.search(r"companion\s+object\s*([A-Za-z_]\w*)?", sig)
        return (m.group(1) if m and m.group(1) else "companion") if m else None
    if kind in ("kotlin-typealias",):
        return _kw_name(sig, ["typealias"])
    if kind in ("scala-object", "scala-enum", "scala-given", "kotlin-object"):
        return _kw_name(sig, ["object", "enum", "given"])
    if kind == "swift-class":
        # class_declaration spans class/struct/enum/actor/extension in
        # tree-sitter-swift — name after whichever keyword is present
        return _kw_name(sig, ["class", "struct", "enum", "actor", "extension"])
    if kind == "swift-protocol":
        return _kw_name(sig, ["protocol"])
    if kind == "cpp-namespace":
        return _kw_name(sig, ["namespace"])
    if kind == "cpp-function":
        # out-of-line members: `int Repo::later()` names later, not Repo
        m = re.search(r"([A-Za-z_]\w*(?:::[A-Za-z_]\w*)+)\s*\(", sig)
        if m:
            return m.group(1).rsplit("::", 1)[1]
    if kind == "lua-function":
        # `function M.method(z)` / `function M:selfm(w)` — keep the dotted
        # path (searchable), normalize : to .
        m = re.search(r"function\s+([A-Za-z_][\w.:]*)", sig)
        return m.group(1).replace(":", ".") if m else None
    if kind == "elixir-def":
        # `defimpl Api, for: X` names Api; `defstruct ...` has no own name
        if re.match(r"\s*defstruct\b", sig):
            return "defstruct"
        m = re.search(r"def(?:p|macro|macrop|guard|guardp|delegate|module|impl|protocol)?\s+([A-Za-z_][\w.?!]*)", sig)
        return m.group(1) if m else None
    if kind in ("dart-method", "dart-function"):
        # getters/setters: `int get total` names total
        m = re.search(r"\b(?:get|set)\s+([A-Za-z_]\w*)", sig)
        if m:
            return m.group(1)
    if kind == "dart-constructor":
        m = re.search(r"([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?)\s*\(", sig)
        return m.group(1) if m else None
    if kind.endswith("-method") or kind.endswith("-function") or kind in ("ruby-singleton-method",):
        m = re.search(r"(?:def\s+(?:self\.)?|function\s+|fn\s+|func\s+(?:\([^)]*\)\s*)?)([A-Za-z_][A-Za-z0-9_]*)", sig)
        if m: return m.group(1)
    m = NAME_RE.search(sig)
    if m: return m.group(1) or m.group(2)
    return None

seen, symbols = set(), []
for m in matches:
    rid = m.get("ruleId", "")
    f = m.get("file", "").replace(os.sep, "/")
    line0 = m.get("range", {}).get("start", {}).get("line")
    if line0 is None or not f:
        continue
    key = (f, line0, rid)
    if key in seen:
        continue
    seen.add(key)
    _src = (m.get("text") or m.get("lines") or "")
    sig = ""
    for _ln in _src.split("\n"):
        _ln = _ln.strip()
        if not _ln:
            continue
        # attribute/annotation-only lines steal the name ([HttpGet("x")] ->
        # name=HttpGet); skip to the declaration line (round-2 finding B3)
        if (_ln.startswith("[") and _ln.endswith("]")) or re.fullmatch(r"@[\w.]+(\(.*\))?", _ln):
            continue
        sig = _ln[:200]
        break
    if not sig:
        sig = _src.split("\n", 1)[0].strip()[:200]
    lang = rid.split("-", 1)[0]
    name = parse_name(sig, rid)
    symbols.append({"name": name or "?", "kind": rid, "file": f,
                    "line": line0 + 1, "signature": sig, "lang": lang})

symbols.sort(key=lambda s: (s["file"], s["line"], s["kind"]))

os.makedirs(os.path.dirname(out), exist_ok=True)
from datetime import datetime, timezone
doc = {"generated_by": "mega-sdd:build-symbol-index",
       "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
       "head_commit": head, "astgrep_version": agv,
       "file_count": len(files), "symbol_count": len(symbols),
       "symbols": symbols}
tmp = out + ".tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(doc, fh, separators=(",", ":"), ensure_ascii=False)
    fh.write("\n")
os.replace(tmp, out)
print("symbol-index: %d symbols from %d files -> %s" % (len(symbols), len(files), out))
PYEOF
