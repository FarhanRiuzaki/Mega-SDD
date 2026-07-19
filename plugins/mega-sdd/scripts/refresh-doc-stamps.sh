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
for arg in "$@"; do
  case "$arg" in
    --vault=*)        VAULT="${arg#*=}" ;;
    --doc=*)          DOC="${arg#*=}" ;;
    --maturity=*)     MATURITY="${arg#*=}" ;;
    --position=*)     POSITION="${arg#*=}" ;;
    --generated-at=*) GENERATED_AT="${arg#*=}" ;;
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

DOC_PATH="$DOC_PATH" DOC="$DOC" MATURITY="$MATURITY" POSITION="$POSITION" GENERATED_AT="$GENERATED_AT" python3 <<'PYEOF'
import os, re, sys, tempfile
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

OPEN, CLOSE = "<!-- mega-sdd:doc-control", "-->"
FIELDS = ("maturity", "position", "generated_at")

def render(fields):
    body = "".join(f"{k}: {fields[k]}\n" for k in FIELDS)
    return f"{OPEN}\ndoc: {doc}\n{body}{CLOSE}"

block_re = re.compile(re.escape(OPEN) + r"\n.*?" + re.escape(CLOSE), re.DOTALL)
m = block_re.search(text)

if m:
    # Refresh: only flag-passed fields change; everything else is preserved.
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
    new_block = render(fields)
    if new_block == old_block:
        print(f"PASS: {doc}-doc-control already current (idempotent no-op)")
        sys.exit(0)
    new_text = text[: m.start()] + new_block + text[m.end():]
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

new_bytes = new_text.encode("utf-8", errors="surrogateescape")
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(doc_path), prefix=".doc-control.")
with os.fdopen(fd, "wb") as f:
    f.write(new_bytes)
os.replace(tmp, doc_path)
print(f"PASS: {action} {doc}-doc-control (maturity: {fields['maturity']} · position: {fields['position']})")
sys.exit(0)
PYEOF
exit $?
