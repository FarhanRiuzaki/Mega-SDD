#!/usr/bin/env bash
# compute-unit-staleness.sh — deterministic unit staleness for the living-vault
# sync lane (spec 2026-06-10-living-vault-continuous-sync-design.md, slice S6).
#
# For every unit with a committed bolt (bolt-report.md carrying target_hashes:),
# compare each recorded sha256 to the current working tree:
#   - any hash differs OR file missing  → stale
#   - all hashes match                  → implemented
#   - bolt-report absent or no target_hashes field → unknown (legacy; never guessed)
# `superseded` is NOT computed here — that requires binding/vault knowledge and is
# assigned by generate-units --reconcile when a claim vanishes.
#
# Usage:
#   compute-unit-staleness.sh --vault=<vault-dir> [--project=<repo-root>]
# Output: JSON on stdout. Exit 0 always (staleness is data); exit 2 on bad invocation.

set -u

VAULT=""; PROJECT=""
for arg in "$@"; do
  case "$arg" in
    --vault=*) VAULT="${arg#*=}" ;;
    --project=*) PROJECT="${arg#*=}" ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done
[ -n "$VAULT" ] && [ -d "$VAULT" ] || { echo "--vault=<dir> required (must exist)" >&2; exit 2; }
[ -n "$PROJECT" ] || PROJECT="$(pwd)"

python3 - "$VAULT" "$PROJECT" <<'PYEOF'
import glob, hashlib, json, os, re, sys

vault, project = sys.argv[1], sys.argv[2]

def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def parse_target_hashes(report_path):
    """Extract the target_hashes: mapping from bolt-report.md YAML frontmatter.
    Tolerant line parser (frontmatter only) — no YAML lib dependency."""
    try:
        text = open(report_path, encoding="utf-8", errors="replace").read()
    except OSError:
        return None
    m = re.match(r"\A---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None
    hashes, in_block = {}, False
    for line in m.group(1).split("\n"):
        if re.match(r"^target_hashes:\s*(#.*)?$", line):
            in_block = True
            continue
        if in_block:
            mm = re.match(r"^\s+([^\s:][^:]*):\s*([0-9a-f]{64})\s*(#.*)?$", line)
            if mm:
                hashes[mm.group(1).strip()] = mm.group(2)
            elif line.strip() and not line.startswith((" ", "\t")):
                in_block = False
    return hashes or None

units = []
# W1 (v8 P1.e, spec App. F6c): a quarantine.json written by write-unit-quarantine.sh
# outranks every other status — the unit was set aside by a DEFER-class halt and
# its question waits in the final report. Quarantined units with no bolt-report
# (halted before any commit) are listed too, so execute-bolts + the report see them.
_quar = {}
for qf in sorted(glob.glob(os.path.join(vault, "bolts", "U-*", "quarantine.json"))):
    try:
        q = json.load(open(qf, encoding="utf-8"))
        _quar[os.path.basename(os.path.dirname(qf))] = q
    except Exception:
        _quar[os.path.basename(os.path.dirname(qf))] = {"halt_type": "unparseable_quarantine"}
for uid, q in _quar.items():
    if not os.path.isfile(os.path.join(vault, "bolts", uid, "bolt-report.md")):
        units.append({"unit": uid, "status": "quarantined", "halt_type": q.get("halt_type"), "reason": q.get("reason"),
                      "dependents_skipped": q.get("dependents_skipped", [])})
for report in sorted(glob.glob(os.path.join(vault, "bolts", "U-*", "bolt-report.md"))):
    unit_id = os.path.basename(os.path.dirname(report))
    if unit_id in _quar:
        q = _quar[unit_id]
        units.append({"unit": unit_id, "status": "quarantined", "halt_type": q.get("halt_type"), "reason": q.get("reason"),
                      "dependents_skipped": q.get("dependents_skipped", [])})
        continue
    hashes = parse_target_hashes(report)
    if hashes is None:
        units.append({"unit": unit_id, "status": "unknown", "reason": "no target_hashes in bolt-report (legacy)"})
        continue
    changed, missing = [], []
    for rel, recorded in hashes.items():
        p = os.path.join(project, rel)
        try:
            _exists = os.path.isfile(p)
        except OSError:
            _exists = False  # unreadable path (perm/NFS/too-long) counts as missing, not a crash
        if not _exists:
            missing.append(rel)
        elif sha256_file(p) != recorded:
            changed.append(rel)
    if changed or missing:
        units.append({"unit": unit_id, "status": "stale", "changed_files": changed, "missing_files": missing})
    else:
        units.append({"unit": unit_id, "status": "implemented"})

counts = {}
for u in units:
    counts[u["status"]] = counts.get(u["status"], 0) + 1

print(json.dumps({"vault": vault, "project": project, "units": units, "counts": counts}, indent=2))
PYEOF
