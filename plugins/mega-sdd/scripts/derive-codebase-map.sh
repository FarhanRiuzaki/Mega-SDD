#!/usr/bin/env bash
# derive-codebase-map.sh — deterministic assembler for codebase-map.md.
#
# WHY THIS EXISTS (spec §5b, 2026-07-30-token-and-latency-optimization.md)
# -----------------------------------------------------------------------
# The map was model-TYPED in full on every write (measured 37.6K cost-units) —
# worst on the --changed-only sync lane, whose merge semantics demand
# byte-identical carry-forward the model delivered by RETYPING every unchanged
# row at the 5.0x output weight. This script assembles the map instead: the
# model writes a small DELTA (changed rows + the judgment sections) and the
# script owns the mechanics — §1 tree rendered from Step 4's files.z, the
# Last_Scanned_Sha256 column joined from Step 5's hashes.txt (which exists
# ONLY on the --shallow-scan lane; the default lane always takes the
# in-process hashlib fallback), byte-copy carry-forward, vanished-file drops, schema
# shape, the staleness stamp, secret-scan chaining, atomic rename, validator
# refresh. The model REMAINS the extraction-output parser and the author of
# §5/§6/§7 — parsing tree-sitter captures in-script is deliberately out of
# scope (unverifiable on a box with no compiled grammars; see scan-procedure
# §Step 5's identical refusal).
#
# THE 4 ANTI-HALLUCINATION RAILS, STRUCTURAL HERE (previously prose-trusted):
#   1. Carried rows are byte-COPIES of the prior map (original
#      Last_Scanned_Sha256 kept); only delta rows get fresh hashes.
#   2. A prior map that cannot be parsed section-by-section in --mode=merge is
#      exit 3 `fallback_full`, nothing written — the caller re-runs full.
#   3. Prior §2/§4 rows whose File no longer exists on disk are DROPPED
#      (in-process existence check) and counted on stdout. §3 deletions ride
#      the model's whole-section replace (Handler has no reliable path key).
#   4. All 7 sections always present ("None detected", never omitted);
#      generated_at/generated_by/repo_root script-stamped; last_scanned_commit
#      minted by the script's own `git rev-parse --verify 'HEAD^{commit}'` and
#      OMITTED on failure or a literal `HEAD` (zero-commit poisoning rule).
#
# Usage:
#   derive-codebase-map.sh --cwd=<project-root> --mode=full|merge
#                          --delta=<dir> [--prior=<map>] [--out=<map>]
#                          [--plugin-root=<path>] [--quiet]
#
# Delta dir contract (model-written; rows in the map's own `| a | b |` format):
#   frontmatter.json  REQUIRED in full; merge = only the fields to refresh.
#                     Script-owned fields in it are IGNORED (generated_at,
#                     generated_by, repo_root, last_scanned_commit).
#   s1.md             optional §1 body override (else: files.z render in full;
#                     carry in merge)
#   s2.rows, s2.files rows WITHOUT the sha column + the replace-set of files
#   s3.rows           whole-section replace (absent in merge = carry)
#   s4.rows, s4.files replace-set like §2
#   s5.md s6.md s7.md judgment bodies (REQUIRED in full; carry in merge)
#
# stdout (suppressed by --quiet): one compact JSON object — status, mode,
#   out_path, sections{}, carried_rows, new_rows, dropped_rows{}, secret_findings,
#   validator, warnings[], bytes.
#
# Exit:
#   0  map written, validator PASS
#   2  usage / IO / incomplete delta. Nothing renamed into place.
#   3  fallback_full — merge preconditions failed (prior absent/corrupt, or a
#      touched section whose prior header is non-canonical and cannot be
#      composed into safely). Nothing written; re-run the scan as FULL (the
#      documented fallback).
#   4  validate-codebase-map.sh REJECTED the assembled map. NOTHING was renamed
#      — the prior map is intact; the rejected assembly is kept beside the
#      target as `<out>.rejected` for forensics. Validator ERROR (any rc other
#      than 0/1 — e.g. a broken python under it) is NOT a rejection: warn and
#      proceed, so a broken validator can never kill a phase-1 chain.
#
# SPAWN BUDGET: constant per write — this wrapper + python + `git rev-parse`
# + secret-scan.sh + validate-codebase-map.sh. No per-item fan-out anywhere
# (tree render, hash join, existence checks are all in-process).

set -uo pipefail

CWD=""
MODE=""
DELTA=""
PRIOR=""
OUT=""
PLUGIN_ROOT=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*)         CWD="${arg#*=}" ;;
    --mode=*)        MODE="${arg#*=}" ;;
    --delta=*)       DELTA="${arg#*=}" ;;
    --prior=*)       PRIOR="${arg#*=}" ;;
    --out=*)         OUT="${arg#*=}" ;;
    --plugin-root=*) PLUGIN_ROOT="${arg#*=}" ;;
    --quiet)         QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERROR: --cwd=<project-root> required and must exist" >&2; exit 2
fi
if [ "$MODE" != "full" ] && [ "$MODE" != "merge" ]; then
  echo "ERROR: --mode=full|merge required" >&2; exit 2
fi
if [ -z "$DELTA" ] || [ ! -d "$DELTA" ]; then
  echo "ERROR: --delta=<dir> required and must exist" >&2; exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

# Interpreter probe — house pattern; `command -v python3` false-positives on
# Windows (WindowsApps stub). Fail CLOSED with the canonical remedy.
_RPY="${SCRIPT_DIR}/_lib/resolve-python.sh"
if [ -f "$_RPY" ]; then
  # shellcheck disable=SC1090
  . "$_RPY"
  if ! mega_sdd_python; then
    mega_sdd_python_remedy >&2
    echo >&2
    exit 2
  fi
else
  MEGA_SDD_PY="python3"
fi
export MEGA_SDD_PY

if [ -z "$PLUGIN_ROOT" ]; then
  _FALLBACK_ROOT="$(cd "${SCRIPT_DIR}/.." 2>/dev/null && pwd)"
  _RPR_PLUGIN="${SCRIPT_DIR}/resolve-plugin-root.sh"
  if [ -f "$_RPR_PLUGIN" ]; then
    PLUGIN_ROOT="$(bash "$_RPR_PLUGIN" "$_FALLBACK_ROOT" 2>/dev/null)" || PLUGIN_ROOT="$_FALLBACK_ROOT"
  else
    PLUGIN_ROOT="$_FALLBACK_ROOT"
  fi
  [ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$_FALLBACK_ROOT"
fi

export MSDD_CWD="$CWD"
export MSDD_MODE="$MODE"
export MSDD_DELTA="$DELTA"
export MSDD_PRIOR="$PRIOR"
export MSDD_OUT="$OUT"
export MSDD_PLUGIN_ROOT="$PLUGIN_ROOT"
export MSDD_QUIET="$QUIET"

# NOT `exec`: the wrapper stays alive to map a broken-interpreter rc onto the
# documented exit 2 (see build-extract-static.sh — same rationale).
# shellcheck disable=SC2086
$MEGA_SDD_PY - <<'PY'
import datetime, hashlib, json, os, re, shutil, subprocess, sys, tempfile

cwd = os.path.abspath(os.environ["MSDD_CWD"])
mode = os.environ["MSDD_MODE"]
delta_dir = os.path.abspath(os.environ["MSDD_DELTA"])
plugin_root = os.environ["MSDD_PLUGIN_ROOT"]
quiet = os.environ.get("MSDD_QUIET", "0") == "1"

CANON = os.path.join(cwd, ".mega-sdd", "codebase", "codebase-map.md")
out_path = os.path.abspath(os.environ.get("MSDD_OUT") or CANON)
prior_path = os.path.abspath(os.environ.get("MSDD_PRIOR") or CANON)
scan_tmp = os.path.join(cwd, ".mega-sdd", "codebase", ".scan")

def die(msg, code=2):
    print("ERROR: " + msg, file=sys.stderr)
    sys.exit(code)

def dread(name):
    p = os.path.join(delta_dir, name)
    if not os.path.isfile(p):
        return None
    try:
        # utf-8-sig: a Windows-authored delta may carry a BOM; without -sig the
        # BOM either kills the JSON parse or silently hides the first table row
        with open(p, "r", encoding="utf-8-sig", errors="replace") as f:
            return f.read()
    except OSError as e:
        die("cannot read delta file %s (%s)" % (name, e))

warnings = []

# ── delta: frontmatter.json ──────────────────────────────────────────────────
fm_raw = dread("frontmatter.json")
if mode == "full" and fm_raw is None:
    die("full mode requires delta frontmatter.json")
try:
    fm_delta = json.loads(fm_raw) if fm_raw else {}
except ValueError as e:
    die("delta frontmatter.json is not valid JSON (%s)" % e)
if not isinstance(fm_delta, dict):
    die("delta frontmatter.json must be a JSON object")

# ── prior map parse (merge mode; rail 2 = fail to exit 3, write nothing) ────
SECTION_TITLES = [
    "## 1. Top-level structure",
    "## 2. Public interfaces",
    "## 3. Routes / Endpoints",
    "## 4. Data models / Schemas",
    "## 5. Naming conventions",
    "## 6. Pattern signatures",
    "## 7. Framework",
]

prior_fm = {}
prior_sections = {}
if mode == "merge":
    if not os.path.isfile(prior_path):
        die("merge mode but no prior map at %s — run a FULL scan" % prior_path, 3)
    try:
        with open(prior_path, "r", encoding="utf-8", errors="replace") as f:
            prior_text = f.read()
    except OSError as e:
        die("cannot read prior map (%s) — run a FULL scan" % e, 3)
    m = re.match(r"^---\n(.*?)\n---\n", prior_text, re.S)
    if not m:
        die("prior map has no frontmatter block — run a FULL scan", 3)
    for ln in m.group(1).splitlines():
        km = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$", ln)
        if km:
            prior_fm[km.group(1)] = km.group(2).strip()
    body = prior_text[m.end():]
    # FENCE-AWARE heading location (the validator is fence-aware too): a
    # section-title-looking line inside a ``` / ~~~ fence must not slice the map
    heading_pos = {}
    pos, in_fence = 0, False
    for ln in body.splitlines(keepends=True):
        s = ln.lstrip()
        if s.startswith("```") or s.startswith("~~~"):
            in_fence = not in_fence
        elif not in_fence:
            st = ln.rstrip("\n").rstrip()
            if st in SECTION_TITLES and st not in heading_pos:
                heading_pos[st] = pos
        pos += len(ln)
    idxs = []
    for t in SECTION_TITLES:
        if t not in heading_pos:
            die("prior map is missing section '%s' — run a FULL scan" % t, 3)
        idxs.append(heading_pos[t])
    if idxs != sorted(idxs):
        die("prior map sections are out of order — run a FULL scan", 3)
    for n, t in enumerate(SECTION_TITLES):
        start = idxs[n] + len(t)
        end = idxs[n + 1] if n + 1 < len(idxs) else len(body)
        prior_sections[n + 1] = body[start:end].strip("\n")

# ── helpers: markdown-table rows ────────────────────────────────────────────
def cell(line, n):
    """n-th cell (0-based) of a `| a | b |` row. ONLY safe when every cell
    BEFORE n is pipe-free — which is why merge composition is gated on the
    prior header being CANONICAL (File-first for §2), never on positions
    assumed blind (the silent-§2-wipe class)."""
    parts = line.split("|", n + 2)
    return parts[n + 1].strip() if len(parts) > n + 2 else ""

def norm_path(rel):
    """Normalize a File cell to a filesystem path: strip backtick wrapping and
    a trailing `:<line>` citation (SKILL.md mandates `src/foo.ts:42`-style
    citations; fixtures carry bare paths — both are valid inputs here)."""
    rel = rel.strip()
    if len(rel) >= 2 and rel.startswith("`") and rel.endswith("`"):
        rel = rel[1:-1].strip()
    m = re.match(r"^(.+?):\d+$", rel)
    if m:
        rel = m.group(1)
    return rel

def exists_rel(rel):
    return os.path.exists(os.path.join(cwd, norm_path(rel)))

# ── sha256 join for delta §2 rows ───────────────────────────────────────────
hashes = {}
hp = os.path.join(scan_tmp, "hashes.txt")
if os.path.isfile(hp):
    with open(hp, "r", encoding="utf-8", errors="replace") as f:
        for ln in f:
            hm = re.match(r"^([0-9a-fA-F]{64})\s+\*?(.+)$", ln.rstrip("\n"))
            if hm:
                p = hm.group(2).strip()
                hashes[p[2:] if p.startswith("./") else p] = hm.group(1)

def sha_for(rel):
    rel = norm_path(rel)
    if rel in hashes:
        return hashes[rel]
    p = os.path.join(cwd, rel)
    try:
        h = hashlib.sha256()
        with open(p, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 16), b""):
                h.update(chunk)
        return h.hexdigest()
    except OSError:
        warnings.append("sha_unavailable:%s" % rel)
        return ""

# ── §1 tree render from files.z ─────────────────────────────────────────────
def render_tree(depth_cap):
    fz = os.path.join(scan_tmp, "files.z")
    if not os.path.isfile(fz):
        return None
    with open(fz, "rb") as f:
        raw = f.read()
    paths = sorted(
        p.decode("utf-8", "replace").removeprefix("./")
        for p in raw.split(b"\0") if p and p != b"."
    )
    tree = {}
    for p in paths:
        parts = p.split("/")[:depth_cap]
        node = tree
        for i, part in enumerate(parts):
            is_file = (i == len(p.split("/")) - 1) and (i == len(parts) - 1)
            node = node.setdefault(part + ("" if is_file else "/"), {})
    lines = []
    def walk(node, prefix):
        keys = sorted(node.keys(), key=lambda k: (not k.endswith("/"), k))
        for i, k in enumerate(keys):
            last = i == len(keys) - 1
            lines.append(prefix + ("└── " if last else "├── ") + k)
            walk(node[k], prefix + ("    " if last else "│   "))
    walk(tree, "")
    return "```\n" + "\n".join(lines) + "\n```" if lines else None

# ── assemble sections ───────────────────────────────────────────────────────
sections = {}
prov = {}
carried_rows = new_rows = 0
dropped = {"s2": 0, "s4": 0}

def sep_for(header):
    n = header.count("|") - 1
    return "|" + "---|" * n

HDRS = {
    2: "| File | Type | Symbol | Signature | Last_Scanned_Sha256 |",
    3: "| Method | Path | Handler |",
    4: "| Entity | File | Fields |",
}
# CANONICAL header cell lists — the merge composes rows ONLY when the prior's
# own header matches one of these (by NAME and ORDER). Anything else is a
# variant-shape prior: composing into it positionally is exactly the
# silent-§2-wipe class, so it is either carried verbatim (untouched) or
# exit 3 fallback_full (when the merge would have to modify it).
CANON_CELLS = {
    2: [["File", "Type", "Symbol", "Signature"],
        ["File", "Type", "Symbol", "Signature", "Last_Scanned_Sha256"]],
    4: [["Entity", "File", "Fields"]],
}
KEY_IDX = {2: 0, 4: 1}  # the File column's index IN THE CANONICAL shape

def is_sep_row(s):
    return re.match(r"^\|[\s:\-|]+\|$", s) is not None

def prior_table(num):
    """Parse prior §num → (pre_lines, header_shape, data_rows, post_lines).
    header_shape: 'canonical4'/'canonical5'/'canonical'/'variant'/None(no table)."""
    prior = prior_sections.get(num, "")
    pre, rows, post = [], [], []
    header_shape = None
    seen_table = False
    for ln in prior.splitlines():
        s = ln.strip()
        if s.startswith("|"):
            if is_sep_row(s):
                continue
            cells = [c.strip() for c in s.strip().strip("|").split("|")]
            if not seen_table:
                seen_table = True
                shapes = CANON_CELLS.get(num, [])
                if any(cells == c for c in shapes):
                    header_shape = "canonical%d" % len(cells) if num == 2 else "canonical"
                else:
                    header_shape = "variant"
                continue  # the header line itself is re-rendered, not carried
            rows.append(ln)
        else:
            (post if seen_table else pre).append(ln)
    return pre, header_shape, rows, post

def join_row_sha(r):
    rel = cell(r, 0)
    body = r.rstrip()
    body = body[:-1].rstrip() if body.endswith("|") else body
    return "%s | %s |" % (body, sha_for(rel))

def delta_data_rows(raw, num):
    """Delta rows, with any model-included header/separator lines filtered."""
    out = []
    key_names = {2: "File", 3: "Method", 4: "Entity"}
    for ln in (raw or "").splitlines():
        s = ln.strip()
        if not s.startswith("|") or is_sep_row(s):
            continue
        if cell(s, 0) == key_names[num]:
            continue  # a header the model included — never a data row
        out.append(ln)
    return out

def build_table_section(num, delta_rows_name, files_name, join_sha):
    """§2 / §4. Full: all rows from the delta. Merge: canonical-gated compose."""
    global carried_rows, new_rows
    delta_rows_raw = dread(delta_rows_name)
    drows = delta_data_rows(delta_rows_raw, num)
    key_idx = KEY_IDX[num]
    # replace-set = the *.files list ∪ the delta rows' own File cells (a row for
    # file X implies X was re-extracted — forgetting the *.files companion must
    # not fail open into duplicate rows)
    rset = set()
    fraw = dread(files_name)
    if fraw is not None:
        rset |= {norm_path(ln) for ln in fraw.splitlines() if ln.strip()}
    rset |= {norm_path(cell(r, key_idx)) for r in drows if cell(r, key_idx)}
    if mode == "full":
        out_rows = [join_row_sha(r) if join_sha else r for r in drows]
        new_rows += len(out_rows)
        prov["s%d" % num] = "delta"
        if not out_rows:
            return "None detected"
        return HDRS[num] + "\n" + sep_for(HDRS[num]) + "\n" + "\n".join(out_rows)
    # merge
    pre, header_shape, prior_rows, post = prior_table(num)
    touched = bool(drows) or bool(rset)
    if header_shape == "variant":
        if touched:
            die("prior map §%d has a non-canonical column order — the merge cannot "
                "compose into it safely; re-run the scan as FULL" % num, 3)
        prov["s%d" % num] = "carried"
        warnings.append("s%d_drops_skipped_noncanonical_header" % num)
        return prior_sections.get(num, "") or "None detected"
    if header_shape is None and touched and prior_rows:
        die("prior map §%d has rows but no parseable header — re-run the scan as FULL" % num, 3)
    kept = []
    pad_legacy = (num == 2 and header_shape == "canonical4")
    padded = 0
    for ln in prior_rows:
        rel = cell(ln, key_idx)
        nrel = norm_path(rel) if rel else ""
        # existence FIRST: a vanished file that also appears in the replace-set
        # is semantically a DROP and must be counted as one, not silently
        # absorbed by the supersede branch
        if nrel and not exists_rel(rel):
            dropped["s%d" % num] += 1
            continue
        if nrel and nrel in rset:
            continue  # superseded by the delta's re-extraction
        if pad_legacy:
            body = ln.rstrip()
            body = body[:-1].rstrip() if body.endswith("|") else body
            ln = body + " |  |"
            padded += 1
        kept.append(ln)
        carried_rows += 1
    if padded:
        warnings.append("s%d_padded_legacy_rows:%d" % (num, padded))
    added = [join_row_sha(r) if join_sha else r for r in drows]
    new_rows += len(added)
    prov["s%d" % num] = "merged" if touched else "carried"
    all_rows = kept + added
    # the prior's literal "None detected" is the EMPTY-section placeholder, not
    # an annotation — it must never survive above a newly-populated table
    def keepable(l):
        return l.strip() and not (all_rows and l.strip() == "None detected")
    body_lines = [l for l in pre if keepable(l)]
    if all_rows:
        body_lines += [HDRS[num], sep_for(HDRS[num])] + all_rows
    body_lines += [l for l in post if keepable(l)]
    return "\n".join(body_lines).strip("\n") or "None detected"

# §1
try:
    depth_cap = int(str(fm_delta.get("scan_depth", prior_fm.get("scan_depth", "8"))).strip() or "8")
except ValueError:
    die("scan_depth must be an integer, got %r" % fm_delta.get("scan_depth"))
s1 = dread("s1.md")
if s1 is not None:
    sections[1] = s1.strip("\n"); prov["s1"] = "delta"
elif mode == "merge":
    # merge: carry the prior §1 rather than re-render — files.z may be a STALE
    # enumeration from an older run (the incremental walk is partial by design);
    # a model that re-walked the changed dirs passes the result as s1.md.
    sections[1] = prior_sections.get(1, "") or "None detected"; prov["s1"] = "carried"
else:
    rendered = render_tree(depth_cap)
    if rendered is not None:
        sections[1] = rendered; prov["s1"] = "files.z"
    else:
        die("full mode needs s1.md in the delta or a Step-4 files.z to render §1 from")

# §2 / §3 / §4
sections[2] = build_table_section(2, "s2.rows", "s2.files", True)
s3_delta = dread("s3.rows")
if mode == "merge" and s3_delta is None:
    sections[3] = prior_sections.get(3, "") or "None detected"; prov["s3"] = "carried"
else:
    rows3 = delta_data_rows(s3_delta, 3)
    new_rows += len(rows3)
    sections[3] = (HDRS[3] + "\n" + sep_for(HDRS[3]) + "\n" + "\n".join(rows3)) if rows3 else "None detected"
    prov["s3"] = "delta"
sections[4] = build_table_section(4, "s4.rows", "s4.files", False)

# §5–7 (judgment — model-authored, carried when untouched)
for num, name in ((5, "s5.md"), (6, "s6.md"), (7, "s7.md")):
    body_d = dread(name)
    if body_d is not None:
        sections[num] = body_d.strip("\n") or "None detected"; prov["s%d" % num] = "delta"
    elif mode == "merge":
        sections[num] = prior_sections.get(num, "") or "None detected"; prov["s%d" % num] = "carried"
    else:
        die("full mode requires %s in the delta (judgment section)" % name)

# full-mode pre-check for the validator's required frontmatter — fail at
# exit 2 BEFORE any write instead of a post-assembly validator rejection
if mode == "full":
    for req in ("languages_detected", "engine"):
        if req not in fm_delta or fm_delta.get(req) in (None, "", []):
            die("full mode requires frontmatter.json to carry '%s' (validator-required)" % req)

# ── frontmatter (rail 4: script-owned fields minted here) ───────────────────
FM_ORDER = ["generated_by", "generated_at", "repo_root", "scan_depth",
            "scan_includes", "scan_excludes", "languages_detected",
            "package_managers", "test_frameworks", "engine", "precision_tier",
            "precision_downgrade_reason", "tree_sitter_version",
            "astgrep_version", "grammars_used", "last_scanned_commit",
            "truncated_sections"]
SCRIPT_OWNED = {"generated_by", "generated_at", "repo_root", "last_scanned_commit"}

fm = {}
for k, v in prior_fm.items():
    if k in FM_ORDER:
        fm[k] = v  # raw prior rendering, carried verbatim
for k, v in fm_delta.items():
    if k in SCRIPT_OWNED:
        warnings.append("ignored_script_owned_frontmatter:%s" % k)
        continue
    if k not in FM_ORDER:
        warnings.append("unknown_frontmatter_key:%s" % k)  # a typo'd key must not vanish silently
        continue
    if isinstance(v, list):
        fm[k] = json.dumps(v)
    elif isinstance(v, (int, float)):
        fm[k] = str(v)
    elif v is None:
        fm.pop(k, None)
    else:
        v = str(v)
        fm[k] = '"%s"' % v.replace('"', '\\"') if (":" in v or " " in v) and not v.startswith('"') else v

fm["generated_by"] = "mega-sdd:scan-codebase"
fm["generated_at"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
fm["repo_root"] = "./"
try:
    r = subprocess.run(["git", "-C", cwd, "rev-parse", "--verify", "HEAD^{commit}"],
                       capture_output=True, text=True, timeout=30)
    stamp = r.stdout.strip()
    if r.returncode == 0 and re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", stamp):
        fm["last_scanned_commit"] = stamp
    else:
        fm.pop("last_scanned_commit", None)  # zero-commit / literal-HEAD poisoning rule
except Exception:
    fm.pop("last_scanned_commit", None)

fm_lines = ["---"]
for k in FM_ORDER:
    if k in fm and fm[k] != "":
        fm_lines.append("%s: %s" % (k, fm[k]))
fm_lines.append("---")

# ── compose + atomic write ──────────────────────────────────────────────────
parts = ["\n".join(fm_lines), "", "# Codebase Map", ""]
for n, t in enumerate(SECTION_TITLES):
    parts.append(t)
    parts.append("")
    parts.append(sections[n + 1])
    parts.append("")
content = "\n".join(parts).rstrip("\n") + "\n"

os.makedirs(os.path.dirname(out_path), exist_ok=True)
tmp = out_path + ".tmp.%d" % os.getpid()
try:
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(content)
except Exception as e:
    try: os.unlink(tmp)
    except OSError: pass
    die("cannot write %s (%s)" % (out_path, e))

# ── secret-scan gate (Step 10a — structural: the write path cannot skip it) ──
secret_findings = []
ss = os.path.join(plugin_root, "scripts", "secret-scan.sh")
if not os.path.isfile(ss):
    try: os.unlink(tmp)
    except OSError: pass
    die("secret-scan.sh not found under --plugin-root (%s) — the Step-10a gate is mandatory" % ss)
try:
    r = subprocess.run(["bash", ss, "--redact", tmp], capture_output=True, text=True, timeout=120)
    out = r.stdout.strip()
    if out:
        try:
            rep = json.loads(out)
            secret_findings = rep.get("findings", rep if isinstance(rep, list) else [])
        except ValueError:
            warnings.append("secret_scan_output_unparsed")
    if r.returncode != 0:
        # secret-scan --redact is documented "exit 0 always (redaction applied)"
        # — a non-zero rc is a scanner MALFUNCTION (e.g. its bare python3 hitting
        # the WindowsApps stub), never a verdict. Proceeding would ship an
        # UNSCRUBBED credential to a committable path. Fail CLOSED.
        try: os.unlink(tmp)
        except OSError: pass
        die("secret-scan.sh malfunctioned (rc=%d) — the Step-10a redaction gate "
            "cannot be skipped; fix its python (see /mega-sdd:install-deps) and re-run"
            % r.returncode)
except SystemExit:
    raise
except Exception as e:
    try: os.unlink(tmp)
    except OSError: pass
    die("secret-scan invocation failed (%s)" % e)

# ── validator GATE on the TEMP, BEFORE the rename ───────────────────────────
# A rejected assembly must never overwrite a good prior map. The gate call
# grades exactly the file just written (--file-path=tmp; its state scribble is
# pointed at the EPHEMERAL delta dir so the canonical state is untouched).
# FAIL (rc 1) → exit 4, NOTHING renamed, the rejected artifact kept beside the
# target for forensics. Validator ERROR (any other non-zero — e.g. its bare
# `python3` hitting the WindowsApps stub) is NOT a gate verdict: warn + proceed,
# a broken validator must not become a phase-1 chain-killer.
validator = "SKIPPED"
rejected_path = None
vs = os.path.join(plugin_root, "scripts", "validate-codebase-map.sh")
if os.path.isfile(vs):
    try:
        # --cwd = a SYSTEM-TEMP scratch dir: the validator sources
        # resolve-project-root.sh, which walks UP from its cwd — a cwd inside
        # the project (the delta dir) would land its state scribble in the
        # CANONICAL .mega-sdd/.codebase-map-state.json, recording a verdict
        # about a temp file the project's real state must never carry.
        _vtmp = tempfile.mkdtemp(prefix="msdd-vgate-")
        try:
            r = subprocess.run(["bash", vs, "--cwd=" + _vtmp, "--file-path=" + tmp, "--quiet"],
                               capture_output=True, text=True, timeout=120)
        finally:
            shutil.rmtree(_vtmp, ignore_errors=True)
        if r.returncode == 0:
            validator = "PASS"
        elif r.returncode == 1:
            validator = "FAIL"
        else:
            validator = "ERROR"
            warnings.append("validator_error_rc:%d" % r.returncode)
    except Exception:
        validator = "ERROR"
        warnings.append("validator_invoke_failed")
else:
    warnings.append("validator_missing")

def emit(status_val, code):
    result = {
        "status": status_val,
        "mode": mode,
        "out_path": out_path,
        "rejected_path": rejected_path,
        "sections": prov,
        "carried_rows": carried_rows,
        "new_rows": new_rows,
        "dropped_rows": dropped,
        "secret_findings": secret_findings,
        "validator": validator,
        "warnings": warnings,
        "bytes": len(content.encode("utf-8")),
    }
    if not quiet:
        print(json.dumps(result))
    sys.exit(code)

if validator == "FAIL":
    rejected_path = out_path + ".rejected"
    try:
        os.replace(tmp, rejected_path)
    except Exception:
        try: os.unlink(tmp)
        except OSError: pass
        rejected_path = None
    # secret_findings (if any) are IN this JSON — route them to
    # SECRET-FINDINGS.md before acting on the halt; the redacted values'
    # locations exist nowhere else.
    emit("validator_fail", 4)

try:
    os.replace(tmp, out_path)
except Exception as e:
    try: os.unlink(tmp)
    except OSError: pass
    die("cannot rename into place (%s)" % e)

# post-rename state refresh — canonical target only (a --out override has no
# canonical state to refresh; the gate above already graded the right file)
if os.path.isfile(vs) and os.path.abspath(out_path) == os.path.abspath(CANON):
    try:
        r = subprocess.run(["bash", vs, "--cwd=" + cwd, "--quiet"],
                           capture_output=True, text=True, timeout=120)
        if r.returncode not in (0,):
            warnings.append("state_refresh_rc:%d" % r.returncode)
    except Exception:
        warnings.append("state_refresh_failed")

emit("ok", 0)
PY
RC=$?
if [ "$RC" != "0" ] && [ "$RC" != "2" ] && [ "$RC" != "3" ] && [ "$RC" != "4" ]; then
  echo "ERROR: the deriver crashed or its interpreter failed to launch (rc=$RC) — if python is fine, this is a deriver bug; the traceback above is the evidence" >&2
  if type mega_sdd_python_remedy >/dev/null 2>&1; then mega_sdd_python_remedy >&2; fi
  exit 2
fi
exit "$RC"
