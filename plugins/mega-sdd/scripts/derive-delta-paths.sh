#!/usr/bin/env bash
# derive-delta-paths.sh — the delta lane's deterministic scope writer
# (spec 2026-08-11-free-text-delta-lane.md §D2).
#
#   derive-delta-paths.sh --vault=<vault-dir> [--cwd=<root>]
#
# Inverts the sync lane's derivation direction: no code moved — the VAULT was
# patched (diff-vault --from-prompt apply), so scope is derived from the
# PATCHED CLAIMS' anchors:
#   1. touched vault docs   <- <vault>/VAULT-DIFF.md rows (every `0N-*.md`
#                              doc literal in the diff-body sections)
#   2. affected claims      <- binding.json claims[] whose vault_source doc
#                              is in the touched set
#   3. anchor paths         <- those claims' anchor cells, parsed EXACTLY the
#                              way sync-intersect.sh parses the same field
# and writes <vault>/.delta-changed-paths.txt (one path per line, sorted,
# deduped — the same consumer contract as bind-codebase --paths=@<file>).
#
# Deliberately NOT .sync-changed-paths.txt: that basename is the sync lane's
# pinned discriminator with a scan-owned lifecycle; a vault-side delta is
# structurally invisible to the sync channel (vault paths are stripped from
# it), so the delta lane carries its own file with its own lifecycle
# (overwritten per from-prompt apply, consumed by the next bind hop).
#
# Exit codes (the caller keys the chain on these — nothing else):
#   0 = written        (paths file written; may be empty when every affected
#       claim is anchor-less — selection then rides the vault-section leg of
#       binding-contract.md §Claim-scoped re-bind, which reads VAULT-DIFF.md)
#   3 = no binding.json (greenfield/unbound vault — nothing to scope against;
#       the caller proposes the NORMAL chain, no scoped hop)
#   2 = FAIL-CLOSED    (ANY read/parse failure OR unprovable scope: missing
#       vault/VAULT-DIFF.md, unreadable or malformed binding.json, a claim's
#       vault_source in an unrecognizable shape, zero doc literals in the diff
#       sections, or touched docs matching ZERO claims — the caller MUST
#       propose a FULL re-bind; this script never converts uncertainty into a
#       scoped bind)
#
# WHY fail-closed: bind-codebase --paths does NOT fail-closed on a no-match
# path (an empty/wrong paths file yields an all-carried-forward re-bind that
# "succeeds" without re-verdicting the intended claims). The guard therefore
# lives HERE: a derivation that cannot be proven correct widens to the full
# re-bind, never narrows on a guess — proportional verification cuts
# inventory, never verification.
#
# Direction of error: touched-doc detection is doc-level and OVER-inclusive
# (any vault-doc literal in ANY non-Unchanged diff section counts) — an extra
# doc means extra claims re-verdict (wider bind, zero verification loss).
# Parsing is FENCE-STRIPPED and SECTION-BASED (headings inside code fences are
# not headings; section position does not matter), so a real section cannot be
# silently dropped by a quoted template or an out-of-order report. The residual
# missed-doc mode requires an applied row that names no doc at all — which
# report-format.md §Doc-literal mandate now precludes for EVERY category
# (Conflicts and Auto-resolved OQs included, not just Added/Changed/Removed).
#
# Evidence trail (reused shapes, never reinvented):
#   - VAULT-DIFF.md structure: skills/diff-vault/references/report-format.md
#     (Action-on-apply lines name the target vault doc, e.g. "append to
#     `03-data-model.md` Entities section")
#   - binding.json schema: skills/bind-codebase/references/binding-json-schema.md
#     (claims[].anchor "UserController.php:45 + routes/api.php:12" | null;
#     claims[].vault_source "03-data-model.md:42" | null)
#   - anchor parse: scripts/sync-intersect.sh claims[].anchor reader — split
#     on `\s*\+\s*`, strip the :line suffix, file-like filter ('/', ':', or
#     dot-extension); slash-less pieces pass through as basenames (the bind
#     side's reverse index derives from the same binding text, so string
#     identity holds). python3 stdlib only, like siblings.
set -u
CWD="."
VAULT=""
while [ $# -gt 0 ]; do case "$1" in
  --cwd) CWD="$2"; shift 2;;
  --cwd=*) CWD="${1#*=}"; shift;;
  --vault) VAULT="$2"; shift 2;;
  --vault=*) VAULT="${1#*=}"; shift;;
  *) echo "usage: derive-delta-paths.sh --vault=<dir> [--cwd=<root>]" >&2; exit 2;;
esac; done
[ -n "$VAULT" ] || { echo "FAIL: --vault is required (fail-closed: propose a FULL re-bind)" >&2; exit 2; }
[ -d "$VAULT" ] || { echo "FAIL: vault dir not found: $VAULT (fail-closed: propose a FULL re-bind)" >&2; exit 2; }
[ -f "$VAULT/binding.json" ] || { echo "NO-BINDING: $VAULT/binding.json absent — unbound vault, no scoped hop (caller proposes the normal chain)" >&2; exit 3; }

V_CWD="$CWD" V_VAULT="$VAULT" python3 <<'PYEOF'
import json, os, re, sys

cwd = os.path.abspath(os.environ["V_CWD"])
vault = os.environ["V_VAULT"]


def die(msg):
    # Fail-closed: ANY read/parse failure -> exit 2, never a guessed scope.
    print("FAIL: %s (fail-closed: propose a FULL re-bind)" % msg, file=sys.stderr)
    sys.exit(2)


def norm(p):
    """Repo-relative normal form: forward slashes, no ./, no trailing /."""
    p = str(p).strip().strip("'\"").replace("\\", "/")
    if not p:
        return None
    if re.match(r"^[A-Za-z]:/", p) or os.path.isabs(p):
        rel = os.path.relpath(p, cwd).replace("\\", "/")
        if rel == ".." or rel.startswith("../"):
            return None
        p = rel
    while p.startswith("./"):
        p = p[2:]
    return p.rstrip("/") or None


# 1. Touched vault docs <- VAULT-DIFF.md diff sections. FENCE-STRIPPED,
# SECTION-BASED (round-hardened): fenced blocks are removed FIRST so a quoted
# heading/template can neither truncate the body nor fake a section; then the
# report is partitioned by its real `## ` headings and every section EXCEPT
# the header preamble, Summary, and Unchanged contributes its vault-doc
# literals — regardless of section order or duplicate heading text.
vd_path = os.path.join(vault, "VAULT-DIFF.md")
try:
    with open(vd_path, encoding="utf-8", errors="replace") as f:
        report = f.read()
except OSError as e:
    die("cannot read %s (%s) — the delta lane needs the diff report" % (vd_path, e))

defenced = re.sub(r"(?ms)^(`{3,}|~{3,}).*?^\1[ \t]*$", "", report)
touched_docs = set()
for sec in re.split(r"(?m)^## ", defenced)[1:]:
    heading = sec.split("\n", 1)[0].strip().lower()
    if heading.startswith("summary") or heading.startswith("unchanged"):
        continue
    touched_docs |= set(re.findall(r"\b0\d-[a-z0-9-]+\.md\b", sec))
if not touched_docs:
    die("no vault-doc literal found in %s diff sections — cannot prove scope" % vd_path)

# 2. Affected claims <- binding.json claims[].vault_source doc in touched set.
bj_path = os.path.join(vault, "binding.json")
try:
    with open(bj_path, encoding="utf-8") as f:
        bj = json.load(f)
except (OSError, ValueError) as e:
    die("unreadable/unparseable binding.json at %s (%s)" % (bj_path, e))
if not isinstance(bj, dict) or not isinstance(bj.get("claims"), list):
    die("binding.json has no claims[] list (%s)" % bj_path)

paths = set()
affected = 0
anchorless = 0
for c in bj["claims"]:
    if not isinstance(c, dict):
        die("binding.json claims[] entry is not an object (%s)" % bj_path)
    vs = c.get("vault_source")
    if not vs or str(vs).strip() in ("null", "—", "n/a"):
        continue
    m = re.match(r"\s*(0\d-[a-z0-9-]+\.md)", str(vs))
    if not m:
        # Fail-closed on shape drift: a non-null vault_source that is not a
        # vault-doc reference means the binding's source space moved — a
        # doc-match against it can no longer be proven correct.
        die("claim %s has unrecognizable vault_source %r" % (c.get("id"), vs))
    if m.group(1) not in touched_docs:
        continue
    affected += 1
    anc = c.get("anchor")
    if not anc or anc in ("—", "n/a"):
        anchorless += 1
        continue
    # Anchor parse — sync-intersect.sh recipe verbatim: split '+', file-like
    # filter, strip :line; slash-less pieces pass through as basenames.
    got = False
    for piece in re.split(r"\s*\+\s*", str(anc)):
        piece = piece.strip()
        if not piece:
            continue
        if ":" in piece or "/" in piece or re.search(r"\.[A-Za-z0-9]+$", piece):
            p = norm(re.sub(r":\d+(-\d+)?$", "", piece))
            if p:
                paths.add(p)
                got = True
    if not got:
        anchorless += 1

if affected == 0:
    # Fail-closed: touched docs matched ZERO claims (incl. the degenerate
    # empty-claims binding) — a "scoped" bind would re-verdict nothing it
    # should; the full re-bind is the only provable answer.
    die("touched docs %s matched zero binding claims" % sorted(touched_docs))

out = os.path.join(vault, ".delta-changed-paths.txt")
try:
    with open(out, "w", encoding="utf-8") as f:
        for p in sorted(paths):
            f.write(p + "\n")
except OSError as e:
    die("cannot write %s (%s)" % (out, e))

print(json.dumps({
    "touched_docs": sorted(touched_docs),
    "affected_claims": affected,
    "anchorless_claims": anchorless,
    "paths": len(paths),
    "out": out,
}, ensure_ascii=False))
PYEOF
