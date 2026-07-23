#!/usr/bin/env bash
# refresh-doc-stamps.sh — P3 (spec 2026-07-19-v5-execution-spec.md P3 row;
# research §4 "Maturity + freshness"): the doc-control state-stamp refresher
# for emitted docs (<vault>/<doc>/<DOC>.md — fsd today; prd/sit in P5).
#
# Contract (stamp-binding-boilerplate.sh precedent):
#   - SCRIPT-OWNED block: the doc-control/state-stamp block between the
#     delimiters `<!-- mega-sdd:doc-control` and `-->` is written ONLY by this
#     script — the model never types it. It carries exactly three fields:
#       maturity:     rung on the doc's maturity ladder (doc-pack-supplied —
#                     FSD pre-development→post-development; PRD
#                     draft-from-legacy→reviewed→final; SIT
#                     planned→partial→executed)
#       position:     pipeline position digest (e.g. "bolts 3/7 complete")
#       generated_at: pointer to the last FULL emission (ISO8601) — preserved
#                     on refresh unless --generated-at is passed
#   - Stamp-only writes: given an existing emitted doc, the ONLY bytes that
#     change are inside (or the insertion of) the doc-control block — every
#     other byte is untouched.
#   - Parser-invisible: the block is an HTML comment placed right after the
#     YAML frontmatter (or at file top when none). It contains no `## N.`
#     heading, no `(sha256: …)` stamp, no `[Source: …]` citation, no `[Pending`
#     marker and no `{{slot}}` — build-citation-map.sh, check-citation-drift.sh
#     and validate-fsd-slots.sh all read regions the block sits outside of.
#   - Idempotent: re-running with the same flags is a byte-identical no-op.
#   - Atomic write (tmp + os.replace) — a crash never truncates the doc.
#
# P3 ships this UNWIRED (no skill invokes it); P5 wires it at phase boundaries
# so a maturity/position bump costs ~0 tokens instead of a full re-emission.
# Shared-engine contract: references/emission-engine.md §Doc-control stamping.
#
# Usage:
#   refresh-doc-stamps.sh --vault=<vault-dir> --doc=<name> \
#     [--maturity=<value>] [--position=<value>] [--generated-at=<iso8601>]
#
#   On first stamp (block absent): the block is inserted; omitted fields
#   default to "unset" (generated_at defaults to current UTC).
#   On refresh (block present): ONLY the fields passed as flags change.
#
# Exit: 0 = stamped/refreshed (or idempotent no-op); 2 = usage error / doc missing.
set -uo pipefail

VAULT=""
DOC=""
MATURITY=""
POSITION=""
GENERATED_AT=""
BUMP=0
APPROVE=0
APPROVER=""
CHANGE_NOTE=""
for arg in "$@"; do
  case "$arg" in
    --vault=*)        VAULT="${arg#*=}" ;;
    --doc=*)          DOC="${arg#*=}" ;;
    --maturity=*)     MATURITY="${arg#*=}" ;;
    --position=*)     POSITION="${arg#*=}" ;;
    --generated-at=*) GENERATED_AT="${arg#*=}" ;;
    --bump)           BUMP=1 ;;
    --approve)        APPROVE=1 ;;
    --approver=*)     APPROVER="${arg#*=}" ;;
    --change-note=*)  CHANGE_NOTE="${arg#*=}" ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done
[ -n "$VAULT" ] && [ -d "$VAULT" ] || { echo "--vault=<vault-dir> required (dir must exist)" >&2; exit 2; }
case "$DOC" in
  ''|*[!a-z0-9-]*) echo "--doc=<name> required (lowercase alnum/hyphen; got: ${DOC:-<empty>})" >&2; exit 2 ;;
esac
DOC_UPPER=$(printf '%s' "$DOC" | tr '[:lower:]' '[:upper:]')
DOC_PATH="$VAULT/$DOC/$DOC_UPPER.md"
[ -f "$DOC_PATH" ] || { echo "$DOC_UPPER.md not found at $DOC_PATH — nothing to stamp" >&2; exit 2; }

# Versioning flags (spec 2026-07-23 §4): --bump (emission minor-bump) and
# --approve (human governance whole-bump) are mutually exclusive; each requires
# its companion flag. These are the ONLY paths that touch .doc-history.json.
if [ "$BUMP" -eq 1 ] && [ "$APPROVE" -eq 1 ]; then echo "--bump and --approve are mutually exclusive" >&2; exit 2; fi
[ "$BUMP" -eq 1 ] && [ -z "$CHANGE_NOTE" ] && { echo "--bump requires --change-note=<derived note>" >&2; exit 2; }
[ "$APPROVE" -eq 1 ] && [ -z "$APPROVER" ] && { echo "--approve requires --approver=\"Nama, Peran\"" >&2; exit 2; }

DOC_PATH="$DOC_PATH" DOC="$DOC" MATURITY="$MATURITY" POSITION="$POSITION" GENERATED_AT="$GENERATED_AT" BUMP="$BUMP" APPROVE="$APPROVE" APPROVER="$APPROVER" CHANGE_NOTE="$CHANGE_NOTE" python3 <<'PYEOF'
import os, re, sys, tempfile, json, subprocess
from datetime import datetime, timezone

doc_path = os.environ["DOC_PATH"]
doc = os.environ["DOC"]
maturity = os.environ.get("MATURITY") or None
position = os.environ.get("POSITION") or None
generated_at = os.environ.get("GENERATED_AT") or None

raw = open(doc_path, "rb").read()
# Binary-safe (build-citation-map.sh precedent): surrogateescape round-trips
# every non-UTF8 byte so "every other byte untouched" holds literally.
text = raw.decode("utf-8", errors="surrogateescape")

# ── Document-versioning engine (spec 2026-07-23 §4) ──────────────────────────
# The sidecar <vault>/<doc>/.doc-history.json is the single source of truth for
# version/status/history; the stamp's version/status fields and the visible
# "Riwayat Revisi" region are pure projections of it, re-rendered every run.
# With both flags absent AND no sidecar on disk, `hist` stays None and the
# legacy 3-field lane is byte-identical (no version/status field, no region).
hist_path = os.path.join(os.path.dirname(doc_path), ".doc-history.json")
bump = os.environ.get("BUMP", "0") == "1"
approve = os.environ.get("APPROVE", "0") == "1"
approver = os.environ.get("APPROVER") or ""
change_note = os.environ.get("CHANGE_NOTE") or ""

def sanitize_note(s):
    # slot-scan + table safety: a note must never introduce {{slot}} or break a row
    return s.replace("{{", "(").replace("}}", ")").replace("|", "\\|").replace("\n", " ").strip()

def git_short_hash(near):
    try:
        r = subprocess.run(["git", "-C", near, "rev-parse", "--short", "HEAD"],
                           capture_output=True, text=True, timeout=10)
        return r.stdout.strip() or "-" if r.returncode == 0 else "-"
    except Exception:
        return "-"

hist = None
if os.path.isfile(hist_path):
    try:
        hist = json.load(open(hist_path))
    except (OSError, ValueError):
        print(f"ERROR: {hist_path} unreadable — refusing to guess version state", file=sys.stderr)
        sys.exit(2)

def next_version(cur, kind):
    # kind: "bump" (minor) | "approve" (next whole). cur None → 0.1 / 1.0.
    if cur is None:
        return "0.1" if kind == "bump" else "1.0"
    major, minor = (int(x) for x in cur.split("."))
    if kind == "approve":
        return f"{major + 1}.0"
    return f"{major}.{minor + 1}"

if bump or approve:
    now = datetime.now(timezone.utc)
    cur = hist["version"] if hist else None
    if hist is None:
        hist = {"schema": 1, "doc": doc, "version": "", "status": "draft", "history": []}
    kind = "approve" if approve else "bump"
    hist["version"] = next_version(cur, kind)
    hist["status"] = "approved" if approve else "draft"
    row = {
        "version": hist["version"],
        "date": now.isoformat(timespec="seconds").replace("+00:00", "Z"),
        "actor": approver if approve else "emit (model-run)",
        "commit": git_short_hash(os.path.dirname(doc_path)),
        "note": sanitize_note(change_note) if change_note else ("Disetujui" if approve else "Emisi"),
    }
    if approve:
        row["event"] = "approval"
    hist["history"].append(row)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(hist_path), prefix=".doc-history.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(hist, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, hist_path)

OPEN, CLOSE = "<!-- mega-sdd:doc-control", "-->"
H_OPEN, H_CLOSE = "<!-- mega-sdd:revision-history -->", "<!-- /mega-sdd:revision-history -->"
FIELDS = ("maturity", "position", "generated_at")

def render(fields):
    body = "".join(f"{k}: {fields[k]}\n" for k in FIELDS)
    extra = f"version: {hist['version']}\nstatus: {hist['status']}\n" if hist else ""
    return f"{OPEN}\ndoc: {doc}\n{body}{extra}{CLOSE}"

def render_history():
    rows = []
    for r in reversed(hist["history"]):  # latest first
        note = r["note"] + (f" (commit {r['commit']})" if r.get("commit") and r["commit"] != "-" else "")
        rows.append(f"| {r['version']} | {r['date'][:10]} | {r['actor']} | {note} |")
    return (f"{H_OPEN}\n**Riwayat Revisi:**\n\n"
            "| Versi | Tanggal | Oleh | Perubahan |\n|---|---|---|---|\n"
            + "\n".join(rows) + f"\n{H_CLOSE}")

block_re = re.compile(re.escape(OPEN) + r"\n.*?" + re.escape(CLOSE), re.DOTALL)
m = block_re.search(text)

if m:
    # Refresh: only flag-passed FIELDS change; version/status always re-render
    # from the sidecar (single source of truth), so the old block's copies are
    # ignored on read.
    old_block = m.group(0)
    fields = {}
    for k in FIELDS:
        fm = re.search(rf"^{k}: (.*)$", old_block, re.MULTILINE)
        fields[k] = fm.group(1) if fm else "unset"
    if maturity is not None:
        fields["maturity"] = maturity
    if position is not None:
        fields["position"] = position
    if generated_at is not None:
        fields["generated_at"] = generated_at
    new_text = text[: m.start()] + render(fields) + text[m.end():]
    action = "refreshed"
else:
    # First stamp: insert right after the YAML frontmatter (or at file top).
    fields = {
        "maturity": maturity or "unset",
        "position": position or "unset",
        "generated_at": generated_at
        or datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
    }
    insert_at = 0
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            nl = text.find("\n", end + 1)
            insert_at = (nl + 1) if nl != -1 else len(text)
    # Pure insertion — the remainder is NOT re-flowed (no lstrip): removing the
    # inserted `block + "\n\n"` substring restores the original bytes exactly.
    new_text = text[:insert_at] + render(fields) + "\n\n" + text[insert_at:]
    action = "stamped"

# Riwayat Revisi region — a projection of the sidecar, placed immediately after
# the doc-control block. Rendered ONLY when the sidecar exists (hist not None),
# so the legacy lane never grows a region. Applied to BOTH branches' new_text.
if hist:
    hre = re.compile(re.escape(H_OPEN) + r"\n.*?" + re.escape(H_CLOSE), re.DOTALL)
    hm = hre.search(new_text)
    if hm:
        new_text = new_text[: hm.start()] + render_history() + new_text[hm.end():]
    else:
        bm = block_re.search(new_text)   # doc-control block just placed above
        insert_at = new_text.find("\n", bm.end()) + 1
        new_text = new_text[:insert_at] + "\n" + render_history() + "\n" + new_text[insert_at:]

# Idempotent no-op compares the FINAL text (block + region) against the input:
# a region-only change still writes; a byte-identical result never rewrites.
if new_text == text:
    print(f"PASS: {doc}-doc-control already current (idempotent no-op)")
    sys.exit(0)

new_bytes = new_text.encode("utf-8", errors="surrogateescape")
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(doc_path), prefix=".doc-control.")
with os.fdopen(fd, "wb") as f:
    f.write(new_bytes)
os.replace(tmp, doc_path)
ver = f" · version: {hist['version']} ({hist['status']})" if hist else ""
print(f"PASS: {action} {doc}-doc-control (maturity: {fields['maturity']} · position: {fields['position']}){ver}")
sys.exit(0)
PYEOF
exit $?
