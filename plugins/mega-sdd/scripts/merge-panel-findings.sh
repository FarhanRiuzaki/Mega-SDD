#!/usr/bin/env bash
# merge-panel-findings.sh — the SOLE writer of <vault>/bolts/U-XXX/findings.json
# (spec 2026-08-29 Fase 1).
#
# Why this exists. The severity->status mapping in review-panel.md §Attempt
# rounds was PROSE, applied by whatever model was driving the controller. Field
# measurement (HOST-AS400 U-001, panel complete, spec_verdict pass): 2 critical
# + 7 important + 4 minor, and ALL THIRTEEN were stamped `status: open`. The
# contract says Critical and the findings behind a spec-fail enter as `open`;
# Important/Minor enter as `advisory` — recorded, surfaced, NEVER gating. So 11
# of 13 findings (85%) held the fix round hostage: the implementer's fix scope
# and the resolution-verifier's workload both scaled by 6.5x over a naming nit.
# Prose that says "never gating" enforces nothing (gates > rules > hooks).
#
# What it does, deterministically:
#   1. Parse each lens's FINDINGS: block (rows `severity | file:line | title | detail`).
#   2. Evidence-or-drop — a row with no resolvable file:line is DISCARDED and counted.
#   3. Dedup — same (file, +/-3 lines, same title stem) across lenses -> ONE entry at
#      MAX severity, `lenses[]` records every reporter.
#   4. Consensus — reported by >=2 lenses -> confidence: high.
#   5. Status mapping — critical UNION spec-fail-linked -> open; important/minor ->
#      advisory. This is the whole point; it is not a judgment call.
#   6. Stable IDs across rounds — an existing finding keeps its id and its
#      resolution history; a re-reported issue never gets a duplicate new id.
#
# Verifier rounds (--verifier=<file>) consume RESOLUTIONS: + NEW-FINDINGS: and
# apply the same mapping to the new rows; `resolved` REQUIRES new-head evidence
# (a resolution row with no file:line stays open — evidence-gated resolution).
#
# Usage:
#   merge-panel-findings.sh --vault=<dir> --unit=U-XXX --head=<sha> [--round=N]
#       [--spec-verdict=pass|fail] --lens=<name>:<file> [--lens=... ...]
#   merge-panel-findings.sh --vault=<dir> --unit=U-XXX --head=<sha> --round=N
#       --verifier=<file>
#
# Exit: 0 = ledger written (stdout = one-line JSON summary incl. gate verdict)
#       2 = usage error. Never exits non-zero on findings — the GATE reads
#           `open_count` from the summary/ledger; this script records, it does
#           not decide to halt.
set -u

VAULT=""; UNIT=""; HEAD_SHA=""; ROUND=1; SPEC_VERDICT=""; VERIFIER=""
LENSES=""
while [ $# -gt 0 ]; do case "$1" in
  --vault=*) VAULT="${1#*=}"; shift;;
  --unit=*) UNIT="${1#*=}"; shift;;
  --head=*) HEAD_SHA="${1#*=}"; shift;;
  --round=*) ROUND="${1#*=}"; shift;;
  --spec-verdict=*) SPEC_VERDICT="${1#*=}"; shift;;
  --verifier=*) VERIFIER="${1#*=}"; shift;;
  --lens=*) LENSES="${LENSES}${1#*=}"$'\n'; shift;;
  *) echo "usage: merge-panel-findings.sh --vault=<dir> --unit=U-XXX --head=<sha> [--round=N] [--spec-verdict=pass|fail] (--lens=<name>:<file> ... | --verifier=<file>)" >&2; exit 2;;
esac; done
[ -n "$VAULT" ] && [ -d "$VAULT" ] || { echo "ERROR: --vault must be an existing directory" >&2; exit 2; }
case "$UNIT" in U-*) ;; *) echo "ERROR: --unit must look like U-XXX" >&2; exit 2;; esac
[ -n "$HEAD_SHA" ] || { echo "ERROR: --head required (the commit the findings were formed against)" >&2; exit 2; }
[ -n "$LENSES" ] || [ -n "$VERIFIER" ] || { echo "ERROR: pass at least one --lens= or --verifier=" >&2; exit 2; }
case "$SPEC_VERDICT" in ""|pass|fail) ;; *) echo "ERROR: --spec-verdict must be pass|fail" >&2; exit 2;; esac

export MEGA_SDD_LIB_DIR="$(cd "$(dirname "$0")" && pwd)/_lib"
V_VAULT="$VAULT" V_UNIT="$UNIT" V_HEAD="$HEAD_SHA" V_ROUND="$ROUND" \
V_SPEC="$SPEC_VERDICT" V_VERIFIER="$VERIFIER" V_LENSES="$LENSES" python3 <<'PYEOF'
import json, os, re, sys

vault = os.environ["V_VAULT"]; unit = os.environ["V_UNIT"]
head = os.environ["V_HEAD"]; spec_verdict = os.environ["V_SPEC"] or None
verifier_file = os.environ["V_VERIFIER"]
try:
    rnd = int(os.environ["V_ROUND"])
except ValueError:
    print("ERROR: --round must be an integer", file=sys.stderr); sys.exit(2)

bolt_dir = os.path.join(vault, "bolts", unit)
os.makedirs(bolt_dir, exist_ok=True)
ledger_path = os.path.join(bolt_dir, "findings.json")

SEV_RANK = {"minor": 1, "important": 2, "critical": 3}
SEV_CANON = {"minor": "Minor", "important": "Important", "critical": "Critical"}
# The mapping this script exists to enforce. Critical gates; everything else is
# recorded and surfaced but never holds a round open (review-panel.md §Attempt
# rounds, "Important/Minor findings enter as advisory ... never gating").
GATING = {"critical"}


def read(p):
    try:
        return open(p, encoding="utf-8", errors="replace").read()
    except OSError as e:
        print("ERROR: cannot read %s: %s" % (p, e), file=sys.stderr); sys.exit(2)


def parse_rows(text, section):
    """Rows under `SECTION:` up to the next ALL-CAPS section label or EOF.
    Row shape: `severity | file:line | title | detail`. A leading list marker
    is tolerated; a header/separator row is not a finding."""
    m = re.search(r"(?ms)^\s*%s\s*:?\s*$\n(.*?)(?=^\s*[A-Z][A-Z -]{2,}\s*:|\Z)"
                  % re.escape(section), text)
    if not m:
        return []
    out = []
    for raw in m.group(1).splitlines():
        line = raw.strip().lstrip("-*").strip()
        if not line or "|" not in line:
            continue
        if set(line) <= set("|-: "):
            continue                                   # markdown separator row
        parts = [p.strip() for p in line.split("|")]
        if len(parts) < 3:
            continue
        if parts[0].lower() in ("severity", "status"):
            continue                                   # header row
        out.append(parts)
    return out


def split_anchor(tok):
    """`path:line` -> (path, int|None). No line, or an unparseable one, is a
    MISS: evidence-or-drop treats it as no anchor at all."""
    m = re.match(r"^(.*?):(\d+)(?::\d+)?$", tok.strip())
    if not m:
        return (tok.strip(), None)
    return (m.group(1).strip(), int(m.group(2)))


def stem(title):
    """Issue-class key for dedup: lowercase alphanumerics, first 6 words."""
    words = re.findall(r"[a-z0-9]+", title.lower())
    return " ".join(words[:6])


# ── existing ledger (id stability across rounds) ─────────────────────────────
prior = {"schema": 1, "unit": unit, "attempt": 0, "findings": []}
if os.path.exists(ledger_path):
    try:
        loaded = json.load(open(ledger_path, encoding="utf-8"))
        if isinstance(loaded, dict) and isinstance(loaded.get("findings"), list):
            prior = loaded
    except (ValueError, OSError):
        pass   # unreadable prior ledger: rebuild rather than fail the round
prior_findings = list(prior.get("findings", []))
by_key = {}
max_id = 0
for f in prior_findings:
    m = re.match(r"^F-(\d+)$", str(f.get("id", "")))
    if m:
        max_id = max(max_id, int(m.group(1)))
    by_key[(f.get("file"), stem(f.get("title", "")))] = f


def next_id():
    global max_id
    max_id += 1
    return "F-%d" % max_id


dropped = 0
incoming = []     # merged NEW observations this round


def add_row(lens, parts, force_status=None):
    global dropped
    sev_raw = parts[0].strip().lower().rstrip(".")
    sev = sev_raw if sev_raw in SEV_RANK else None
    path, line = split_anchor(parts[1])
    title = parts[2].strip()
    detail = parts[3].strip() if len(parts) > 3 else ""
    # Evidence-or-drop: no file:line anchor -> discarded, mirrors the
    # no-fabrication invariant. An unknown severity is also unusable: it cannot
    # be mapped to a status, and guessing one would be the exact judgment call
    # this script removes.
    if not path or line is None or sev is None or not title:
        dropped += 1
        return
    incoming.append({"lens": lens, "severity": sev, "file": path, "line": line,
                     "title": title, "detail": detail,
                     "force_status": force_status})


for spec in [l for l in os.environ["V_LENSES"].splitlines() if l.strip()]:
    name, _, path = spec.partition(":")
    if not path:
        print("ERROR: --lens expects <name>:<file>, got %r" % spec, file=sys.stderr)
        sys.exit(2)
    text = read(path)
    for parts in parse_rows(text, "FINDINGS"):
        add_row(name.strip(), parts)

resolutions = []
if verifier_file:
    vtext = read(verifier_file)
    for parts in parse_rows(vtext, "NEW-FINDINGS"):
        add_row("verifier", parts)
    # RESOLUTIONS rows: `finding-id | file:line | resolved|unresolved|regressed | note`
    for parts in parse_rows(vtext, "RESOLUTIONS"):
        fid = parts[0].strip()
        path, line = split_anchor(parts[1])
        verdict = parts[2].strip().lower() if len(parts) > 2 else ""
        note = parts[3].strip() if len(parts) > 3 else ""
        resolutions.append({"id": fid, "file": path, "line": line,
                            "verdict": verdict, "note": note})

# ── merge incoming into the ledger ───────────────────────────────────────────
merged = {f["id"]: f for f in prior_findings if f.get("id")}
order = [f["id"] for f in prior_findings if f.get("id")]
round_seen = {}

for obs in incoming:
    key = None
    for (pf_file, pf_stem), pf in by_key.items():
        if pf_file != obs["file"]:
            continue
        if pf_stem != stem(obs["title"]):
            continue
        key = pf["id"]
        break
    if key is None:
        # dedup WITHIN this round: same file, +/-3 lines, same issue class
        for fid, seen in round_seen.items():
            if seen["file"] == obs["file"] and abs(seen["line"] - obs["line"]) <= 3 \
               and stem(seen["title"]) == stem(obs["title"]):
                key = fid
                break
    if key is None:
        key = next_id()
        merged[key] = {"id": key, "lens": obs["lens"], "lenses": [],
                       "severity": SEV_CANON[obs["severity"]],
                       "file": obs["file"], "line": obs["line"],
                       "title": obs["title"], "detail": obs["detail"],
                       "status": None, "resolution": None,
                       "first_seen_round": rnd}
        order.append(key)
    cur = merged[key]
    cur.setdefault("lenses", [])
    if obs["lens"] not in cur["lenses"]:
        cur["lenses"].append(obs["lens"])
    # keep the MAX severity across reporting lenses
    if SEV_RANK[obs["severity"]] > SEV_RANK.get(str(cur.get("severity", "")).lower(), 0):
        cur["severity"] = SEV_CANON[obs["severity"]]
        cur["detail"] = obs["detail"] or cur.get("detail", "")
    # a re-report at the new head reopens nothing on its own; status is mapped below
    cur["last_seen_round"] = rnd
    round_seen[key] = cur

# consensus
for f in merged.values():
    f["confidence"] = "high" if len(f.get("lenses", [])) >= 2 else "normal"

# ── THE mapping ──────────────────────────────────────────────────────────────
# Applied to every finding on every round, so a hand-edited or model-written
# status cannot survive a merge.
spec_fail = (spec_verdict == "fail")
for f in merged.values():
    sev = str(f.get("severity", "")).lower()
    gating = sev in GATING or (spec_fail and f.get("lens") == "spec")
    if f.get("status") == "resolved":
        continue                      # a verified resolution is never re-opened here
    f["status"] = "open" if gating else "advisory"

# ── verifier resolutions (evidence-gated) ────────────────────────────────────
for r in resolutions:
    f = merged.get(r["id"])
    if not f:
        continue
    if r["verdict"] == "resolved" and r["line"] is not None and r["file"]:
        f["status"] = "resolved"
        f["resolution"] = {"verified_by": "resolution-verifier round %d" % rnd,
                           "evidence": "%s:%d" % (r["file"], r["line"]),
                           "head": head, "note": r["note"]}
    elif r["verdict"] in ("unresolved", "regressed"):
        sev = str(f.get("severity", "")).lower()
        f["status"] = "open" if sev in GATING else "advisory"
        f["resolution"] = None
    else:
        # `resolved` with no file:line evidence is NOT a resolution — the claim
        # is recorded, the finding stays as mapped.
        f["resolution"] = {"claimed": r["verdict"], "evidence": None,
                           "note": "resolution claim carried no file:line evidence"}

findings = [merged[i] for i in order if i in merged]
open_count = len([f for f in findings if f.get("status") == "open"])
advisory_count = len([f for f in findings if f.get("status") == "advisory"])
resolved_count = len([f for f in findings if f.get("status") == "resolved"])

ledger = {"schema": 1, "unit": unit, "attempt": rnd, "head": head,
          "spec_verdict": spec_verdict, "findings": findings,
          "dropped_no_evidence": dropped,
          # F-07/F-26: the writer stamp IS the evidence key the panel-evidence
          # gate reads — a hand-written ledger (3/3 on the field run) never
          # carries it, so "sole writer" is a mechanism, not a sentence.
          "written_by": "merge-panel-findings.sh"}
sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import plugin_meta
ledger.update(plugin_meta.stamp(os.environ["MEGA_SDD_LIB_DIR"]))

tmp = ledger_path + ".tmp.%d" % os.getpid()
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(ledger, fh, indent=1, ensure_ascii=False)
    fh.write("\n")
os.replace(tmp, ledger_path)

print(json.dumps({"unit": unit, "attempt": rnd, "ledger": ledger_path,
                  "open": open_count, "advisory": advisory_count,
                  "resolved": resolved_count,
                  "dropped_no_evidence": dropped,
                  "spec_verdict": spec_verdict,
                  # the gate condition, computed here so no caller re-derives it
                  "gate": "re-dispatch" if (open_count or spec_fail) else "clear"},
                 separators=(",", ":")))
PYEOF
