#!/usr/bin/env bash
# write-verify-state.sh — deterministic writer for the claim-verify lane state
# (7.25.0, spec 2026-09-05-kb-verify-lane-design.md Fase 3).
#
# Parses the claim-verifier agent's machine-parsed VERIFY REPORT block (stdin
# or --report-file) and writes <kb-dir>/.verify/<domain>.json. The controller
# never hand-writes this JSON — one writer, one schema, parse errors are loud.
# validate-extract-census.sh reads the file at the completeness gate and
# RECOMPUTES locked coverage from the PRD artifact (B1-recompute pattern) —
# the state carries the verifier's verdict, never the coverage ground truth.
#
# Usage: write-verify-state.sh --kb-dir=<dir> [--report-file=<path>] [--quiet]
# Exit: 0 written (status PASS|FAIL inside the state) · 2 unparseable/usage.

set -u
KB_DIR=""; REPORT_FILE=""; QUIET=0
for arg in "$@"; do
  case "$arg" in
    --kb-dir=*)      KB_DIR="${arg#--kb-dir=}" ;;
    --report-file=*) REPORT_FILE="${arg#--report-file=}" ;;
    --quiet)         QUIET=1 ;;
    *) echo "usage: write-verify-state.sh --kb-dir=<dir> [--report-file=<path>] [--quiet]" >&2; exit 2 ;;
  esac
done
[ -n "$KB_DIR" ] && [ -d "$KB_DIR" ] || { echo "write-verify-state.sh: --kb-dir missing or not a directory: '$KB_DIR'" >&2; exit 2; }
if [ -n "$REPORT_FILE" ]; then
  [ -f "$REPORT_FILE" ] || { echo "write-verify-state.sh: report file not found: $REPORT_FILE" >&2; exit 2; }
  INPUT=$(cat "$REPORT_FILE")
else
  INPUT=$(cat)
fi

KB_DIR="$KB_DIR" QUIET="$QUIET" INPUT="$INPUT" python3 <<'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone

kb_dir = os.environ["KB_DIR"]
quiet = os.environ["QUIET"] == "1"
text = os.environ["INPUT"]

m = re.search(r"^VERIFY REPORT\s*$", text, re.MULTILINE)
if not m:
    print("write-verify-state.sh: no 'VERIFY REPORT' block found in input", file=sys.stderr)
    sys.exit(2)
block = text[m.end():]

def grab(key, pattern=r"(\S+)"):
    mm = re.search(r"^-\s*%s:\s*%s" % (re.escape(key), pattern), block, re.MULTILINE)
    return mm.group(1) if mm else None

domain = grab("module")
if not domain or not re.match(r"^[A-Za-z0-9_.-]+$", domain):
    print("write-verify-state.sh: missing/invalid '- module:' line", file=sys.stderr)
    sys.exit(2)

ints = {}
for key in ("locked_total", "locked_checked", "money_checked", "sampled",
            "exact", "imprecise", "wrong", "wrong_load_bearing"):
    v = grab(key, r"(\d+)")
    if v is None:
        print("write-verify-state.sh: missing integer field '- %s:'" % key, file=sys.stderr)
        sys.exit(2)
    ints[key] = int(v)

findings = []
fm = re.search(r"^-\s*findings:\s*(.*)$", block, re.MULTILINE)
if fm:
    inline = fm.group(1).strip()
    if inline and inline.lower() != "none":
        findings.append(inline)
    for line in block[fm.end():].splitlines():
        lm = re.match(r"^\s+-\s+(.+?)\s*$", line)
        if lm:
            findings.append(lm.group(1))
        elif line.strip() and not line.startswith((" ", "\t")):
            break

# Internal consistency: a report claiming zero wrong but listing WRONG findings
# (or vice versa) is unparseable-by-contract — refuse rather than guess.
wrong_findings = sum(1 for f in findings if re.search(r"\|\s*WRONG\s*\|", f))
if ints["wrong"] == 0 and wrong_findings > 0:
    print("write-verify-state.sh: wrong=0 but %d WRONG finding line(s) listed" % wrong_findings, file=sys.stderr)
    sys.exit(2)
if ints["wrong"] > 0 and wrong_findings == 0:
    print("write-verify-state.sh: wrong=%d but no WRONG finding lines listed" % ints["wrong"], file=sys.stderr)
    sys.exit(2)
if ints["wrong_load_bearing"] > ints["wrong"]:
    print("write-verify-state.sh: wrong_load_bearing > wrong", file=sys.stderr)
    sys.exit(2)
if ints["locked_checked"] < ints["locked_total"]:
    status = "FAIL"   # incomplete LOCKED coverage is a failing verify, recorded honestly
elif ints["wrong_load_bearing"] > 0:
    status = "FAIL"
else:
    status = "PASS"

out_dir = os.path.join(kb_dir, ".verify")
os.makedirs(out_dir, exist_ok=True)
state_path = os.path.join(out_dir, domain + ".json")
doc = {"domain": domain, "status": status,
       "generated_by": "mega-sdd:write-verify-state",
       "checked_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
       **ints, "findings": findings}
tmp = state_path + ".tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(doc, fh, indent=1, ensure_ascii=False)
    fh.write("\n")
os.replace(tmp, state_path)
if not quiet:
    print("verify-state: %s — %s (wrong=%d, wrong_load_bearing=%d, locked %d/%d, sampled %d)"
          % (domain, status, ints["wrong"], ints["wrong_load_bearing"],
             ints["locked_checked"], ints["locked_total"], ints["sampled"]))
PYEOF
