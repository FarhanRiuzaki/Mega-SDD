#!/usr/bin/env bash
# build-citation-map.sh — W3: the citation map + every in-document sha256 stamp
# is SCRIPT-COMPUTED from file bytes (spec 2026-07-19-w-batch-script-derive.md).
#
# The model emits FSD.md with the LITERAL placeholder `(sha256: pending)` wherever
# a stamp belongs and never writes a hash character. This script then:
#   1. parses FSD.md's existing markers — '## N.' section headings, per-section
#      citation footers ('- [N] `path:Lx-Ly` (sha256: `pending`)'), and inline
#      '[Source: path … (sha256: pending)]' citations. Path recognition reuses the
#      canonical grammar _lib/citation_pattern.py PATH_REF_RE (two validators,
#      one grammar — NOT a new regex);
#   2. resolves each cited path in vault/-prefix → vault → project → codebase-map
#      order and computes sha256 via python3 hashlib over the file BYTES;
#   3. replaces the `pending` token of each resolvable citation's stamp with the
#      real 12-char prefix, in place (binary-safe surrogateescape decode + atomic
#      tmp+os.replace — before pandoc renders, so PDF/HTML inherit real stamps).
#      Special case: the '**Source vault:**' doc-control line is stamped with
#      sha256 of <vault>/vault.json;
#   4. writes <vault>/<doc>/.citation-map.json (schema 2.0, default doc: fsd) —
#      per-entry resolved_path
#      + source_sha256 (null + unresolved:true when the cited path resolves to no
#      file), emitted_text_sha256 = sha256 of the section's post-stamp byte slice,
#      top-level vault_sha256/mode, and missing_sources[] derived from the
#      '[Pending — …]' markers (consumer: orchestrate-flow chain-execution.md).
#
# WHY: a fabricated hash becomes impossible — the model's only inputs to the map
# are PATHNAMES; a fabricated pathname resolves to no file → UNRESOLVED, exit 1 →
# halt quality_gate_failed subtype citation_unresolvable (emit-fsd Step 4.6).
#
# Usage:
#   build-citation-map.sh --vault=<vault-dir> --cwd=<project-root> --mode=<mode> [--doc=<name>]
#     (--mode is recorded into the map only; it changes no computation)
#     (--doc names the doc lane, default fsd — it parameterizes ONLY the doc
#      subdir <vault>/<doc>/<DOC>.md, the map path <vault>/<doc>/.citation-map.json,
#      and the emitted_by label; with --doc absent or =fsd every code path is
#      byte-identical to the pre-flag script. P3 seam for emit-prd/emit-sit —
#      see references/emission-engine.md)
#
# Exit codes:
#   0  clean — ONE stdout line (quiet-gates diet M-05a)
#   1  any UNRESOLVED citation OR any leftover `pending` stamp outside code
#      fences (UNRESOLVED/LEFTOVER lines printed; map STILL written with
#      unresolved entries so the audit trail survives the halt)
#   2  usage error / FSD.md missing
#
# Idempotent: a second run leaves FSD.md byte-identical (only the literal
# `pending` token inside existing '(sha256: …)' stamps is ever replaced).

set -uo pipefail

VAULT=""
CWD=""
MODE=""
DOC="fsd"
for arg in "$@"; do
  case "$arg" in
    --vault=*) VAULT="${arg#*=}" ;;
    --cwd=*)   CWD="${arg#*=}" ;;
    --mode=*)  MODE="${arg#*=}" ;;
    --doc=*)   DOC="${arg#*=}" ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done
[ -n "$VAULT" ] && [ -d "$VAULT" ] || { echo "--vault=<vault-dir> required (dir must exist)" >&2; exit 2; }
[ -n "$CWD" ] && [ -d "$CWD" ] || { echo "--cwd=<project-root> required (dir must exist)" >&2; exit 2; }
case "$DOC" in
  ''|*[!a-z0-9-]*) echo "--doc must be lowercase alnum/hyphen (got: $DOC)" >&2; exit 2 ;;
esac
DOC_UPPER=$(printf '%s' "$DOC" | tr '[:lower:]' '[:upper:]')
[ -f "$VAULT/$DOC/$DOC_UPPER.md" ] || { echo "$DOC_UPPER.md not found at $VAULT/$DOC/$DOC_UPPER.md — run emit-$DOC Step 4 first" >&2; exit 2; }

LIB_DIR="$(cd "$(dirname "$0")" && pwd)/_lib"
[ -f "$LIB_DIR/citation_pattern.py" ] || { echo "missing _lib/citation_pattern.py" >&2; exit 2; }

VAULT="$VAULT" CWD="$CWD" MODE="$MODE" DOC="$DOC" DOC_UPPER="$DOC_UPPER" LIB_DIR="$LIB_DIR" python3 <<'PYEOF'
import hashlib, json, os, re, sys, tempfile
from datetime import datetime, timezone

sys.path.insert(0, os.environ["LIB_DIR"])
from citation_pattern import PATH_REF_RE  # canonical grammar — never a new regex

vault = os.path.abspath(os.environ["VAULT"])
cwd = os.path.abspath(os.environ["CWD"])
mode = os.environ.get("MODE") or "unknown"
doc = os.environ.get("DOC") or "fsd"
doc_upper = os.environ.get("DOC_UPPER") or doc.upper()
fsd_path = os.path.join(vault, doc, f"{doc_upper}.md")
map_path = os.path.join(vault, doc, ".citation-map.json")

raw = open(fsd_path, "rb").read()
# Binary-safe: surrogateescape round-trips every non-UTF8 byte (CRLF-safe too —
# we split on \n only, so \r stays attached to its line).
text = raw.decode("utf-8", errors="surrogateescape")
lines = text.split("\n")

_sha_cache = {}
def sha256_file(p):
    if p not in _sha_cache:
        h = hashlib.sha256()
        with open(p, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        _sha_cache[p] = h.hexdigest()
    return _sha_cache[p]

def resolve(cited):
    """vault/-prefix → vault → project → codebase-map resolution order."""
    c = cited.strip().strip("`")
    cands = []
    if c.startswith("vault/"):
        cands.append(os.path.join(vault, c[len("vault/"):]))
    cands.append(os.path.join(vault, c))
    cands.append(os.path.join(cwd, c))
    cands.append(os.path.join(cwd, ".mega-sdd", "codebase", c))
    for p in cands:
        if os.path.isfile(p):
            return os.path.abspath(p)
    return None

STAMP_RE = re.compile(r"\(sha256:\s*(`?)pending\1\)")
SEC_RE = re.compile(r"^## (\d+)\.\s")
SUB_ID_RE = re.compile(r"\b((?:FR|US|OQ)-[A-Za-z0-9_]+)\b")
SRC_RE = re.compile(r"\[Source:([^\]]*)\]")
PENDING_MARK_RE = re.compile(r"\[Pending\s*[—–-]+\s*([^\]]+)\]")
FENCE_RE = re.compile(r"^\s*(```|~~~)")

def split_path_lines(m, hay):
    """PATH_REF_RE match → (path, source_lines-or-None). Handles both the bare
    ':12-20' suffix (consumed by the grammar) and the FSD ':L78-L92' form
    (which the grammar leaves after the leaf)."""
    tok = m.group(0)
    mm = re.search(r":(\d+[-–]?\d*)$", tok)
    if mm:
        return tok[: mm.start()], mm.group(1)
    rest = hay[m.end():]
    mm2 = re.match(r":(L\d+(?:\s*[-–]\s*L?\d+)?)", rest)
    if mm2:
        return tok, mm2.group(1)
    return tok, None

entries = []          # ordered map entries
entry_keys = {}       # (fsd_section, source_path) -> entry (dedup)
missing_sources = []
unresolved_lines = [] # "UNRESOLVED <section> <path>"
leftover_lines = []   # "LEFTOVER <lineno>: <line>"
stamps_applied = 0

def record(sec_label, source_path, source_lines, resolved_abs):
    key = (sec_label, source_path)
    if key in entry_keys:
        return entry_keys[key]
    e = {
        "fsd_section": sec_label,
        "source_path": source_path,
        "resolved_path": os.path.relpath(resolved_abs, cwd) if resolved_abs else None,
        "source_lines": source_lines,
        "source_sha256": sha256_file(resolved_abs) if resolved_abs else None,
        "emitted_text_sha256": None,  # filled after stamping (post-stamp byte slice)
    }
    if not resolved_abs:
        e["unresolved"] = True
    entry_keys[key] = e
    entries.append(e)
    return e

in_fence = False
cur_sec = "doc-control"
cur_sub = None
for i, line in enumerate(lines):
    if FENCE_RE.match(line):
        in_fence = not in_fence
        continue
    if in_fence:
        continue
    ms = SEC_RE.match(line)
    if ms:
        cur_sec, cur_sub = ms.group(1), None
        continue
    if re.match(r"^#{3,4}\s", line):
        mi = SUB_ID_RE.search(line)
        cur_sub = mi.group(1) if mi else cur_sub
        continue
    if line.startswith("**Sources for this section:**"):
        cur_sub = None  # footer cites the whole section, not the last sub-item
        continue
    sec_label = cur_sec if (cur_sub is None or cur_sec == "doc-control") else f"{cur_sec}.{cur_sub}"

    stamps = list(STAMP_RE.finditer(line))

    # Special case: the doc-control '**Source vault:**' line → sha256(vault.json).
    if "**Source vault:**" in line:
        vjson = os.path.join(vault, "vault.json")
        if os.path.isfile(vjson):
            h12 = sha256_file(vjson)[:12]
            new_line = line
            for st in reversed(stamps):
                tick = st.group(1)
                new_line = new_line[: st.start()] + f"(sha256: {tick}{h12}{tick})" + new_line[st.end():]
                stamps_applied += 1
            lines[i] = new_line
            record("doc-control", "vault.json", None, vjson)
        elif stamps:
            unresolved_lines.append("UNRESOLVED doc-control vault.json")
            record("doc-control", "vault.json", None, None)
        continue

    marks = PENDING_MARK_RE.findall(line)
    for t in marks:
        t = t.strip()
        pm = PATH_REF_RE.search(t)
        expected = pm.group(0) if pm else (t.split() or ["?"])[0]
        missing_sources.append({"section": cur_sec, "expected_source": expected, "reason": t})

    if not stamps and "[Source:" not in line and not re.match(r"\s*-\s*\[", line):
        continue

    # Candidate citations on this line, with absolute spans in `line`.
    candidates = []  # (start, end, path, source_lines)
    srcs = list(SRC_RE.finditer(line))
    if srcs:
        for sm in srcs:
            pm = PATH_REF_RE.search(sm.group(1))
            if pm:
                path, slines = split_path_lines(pm, sm.group(1))
                candidates.append((sm.start(1) + pm.start(), sm.start(1) + pm.end(), path, slines))
    elif re.match(r"\s*-\s*\[", line):
        close = line.find("]")
        pm = PATH_REF_RE.search(line, close + 1 if close >= 0 else 0)
        if pm:
            path, slines = split_path_lines(pm, line)
            candidates.append((pm.start(), pm.end(), path, slines))
    elif stamps:
        # Generic fallback: nearest path before each stamp anywhere on the line.
        for st in stamps:
            before = [m for m in PATH_REF_RE.finditer(line) if m.end() <= st.start()]
            if before:
                pm = before[-1]
                path, slines = split_path_lines(pm, line)
                candidates.append((pm.start(), pm.end(), path, slines))

    # Record every candidate citation (stamped or not — e.g. '(commit:)' bolt
    # citations still get a REAL file sha256 in the map).
    resolved_by_span = {}
    for (cs, ce, path, slines) in candidates:
        rp = resolve(path)
        resolved_by_span[(cs, ce)] = (path, rp)
        record(sec_label, path, slines, rp)
        if rp is None:
            unresolved_lines.append(f"UNRESOLVED {sec_label} {path}")

    # Stamp replacement, right-to-left so original spans stay valid.
    new_line = line
    for st in reversed(stamps):
        before = [k for k in resolved_by_span if k[1] <= st.start()]
        if not before:
            leftover_lines.append(f"LEFTOVER {i + 1}: {line.strip()}")
            continue
        path, rp = resolved_by_span[max(before, key=lambda k: k[1])]
        if rp is None:
            continue  # already reported UNRESOLVED; pending stays (halt path)
        tick = st.group(1)
        new_line = new_line[: st.start()] + f"(sha256: {tick}{sha256_file(rp)[:12]}{tick})" + new_line[st.end():]
        stamps_applied += 1
    lines[i] = new_line

# ── Post-stamp section byte slices → emitted_text_sha256 ──
final_text = "\n".join(lines)
final_bytes = final_text.encode("utf-8", errors="surrogateescape")
offsets, pos, in_fence = [], 0, False
sec_starts = []  # (byte_offset, sec_number)
for line in lines:
    if FENCE_RE.match(line):
        in_fence = not in_fence
    elif not in_fence:
        ms = SEC_RE.match(line)
        if ms:
            sec_starts.append((pos, ms.group(1)))
    pos += len(line.encode("utf-8", errors="surrogateescape")) + 1
slices = {"doc-control": (0, sec_starts[0][0] if sec_starts else len(final_bytes))}
for idx, (off, num) in enumerate(sec_starts):
    end = sec_starts[idx + 1][0] if idx + 1 < len(sec_starts) else len(final_bytes)
    slices[num] = (off, end)
for e in entries:
    major = e["fsd_section"].split(".")[0]
    if major in slices:
        s, t = slices[major]
        e["emitted_text_sha256"] = hashlib.sha256(final_bytes[s:t]).hexdigest()

# ── Atomic writes: FSD.md (only when changed) + the map (always) ──
if final_bytes != raw:
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(fsd_path), prefix=f".{doc_upper}.md.")
    with os.fdopen(fd, "wb") as f:
        f.write(final_bytes)
    os.replace(tmp, fsd_path)

vjson = os.path.join(vault, "vault.json")
cmap = {
    "schema_version": "2.0",
    "emitted_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "emitted_by": f"emit-{doc} via scripts/build-citation-map.sh",
    "vault_sha256": sha256_file(vjson) if os.path.isfile(vjson) else None,
    "mode": mode,
    "sections": entries,
    "missing_sources": missing_sources,
}
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(map_path), prefix=".citation-map.")
with os.fdopen(fd, "wb") as f:
    f.write((json.dumps(cmap, indent=2) + "\n").encode("utf-8"))
os.replace(tmp, map_path)

if unresolved_lines or leftover_lines:
    for l in unresolved_lines + leftover_lines:
        print(l)
    print(f"✗ citation-map: {len(unresolved_lines)} unresolved citation(s), "
          f"{len(leftover_lines)} leftover pending stamp(s) — map written with unresolved entries; "
          f"halt quality_gate_failed:citation_unresolvable")
    sys.exit(1)

print(f"✓ citation-map: {len(entries)} entries ({stamps_applied} stamped, "
      f"{len(missing_sources)} missing-source) → {os.path.relpath(map_path, cwd)}")
sys.exit(0)
PYEOF
exit $?
