#!/usr/bin/env bash
# report-token-cost.sh — cost-weighted token reporting for a mega-sdd run.
#
# WHY: raw token counts overstate real cost ~5x because cache_read bills at ~0.1x
# the input rate. A full-pipeline field audit measured 176M RAW tokens that were 91.9%
# cache_read -> ~37M COST-EQUIVALENT. Reporting raw
# counts makes a run look far more wasteful than it actually costs, and hides WHERE
# the real cost is. This rolls up the telemetry turn_end_marker usage into a
# cost-weighted view + per-skill attribution, so "berasa boros" becomes a real number.
#
# COST WEIGHTS (Opus price ratios, expressed relative to 1 uncached input token):
#   input_tokens                x1.00
#   cache_creation_input_tokens x1.25
#   cache_read_input_tokens     x0.10
#   output_tokens               x5.00
# Cost-weighted total is in "cost-equivalent input tokens" — a price-faithful unit,
# NOT a raw count. raw/cost ratio > 1 means the raw number overstates the bill.
#
# REPORT-ONLY: reads <cwd>/.mega-sdd/memory/telemetry.jsonl, writes
# <cwd>/.mega-sdd/TOKEN-COST-REPORT.md + <cwd>/.mega-sdd/.token-cost-state.json.
# Touches no gate and no moat state. Exit 0 always (a report can never block a chain).
#
# Usage: report-token-cost.sh --cwd=<project-root> [--quiet] [--json]
#   --quiet  suppress the one-line stdout summary (still writes the files)
#   --json   print the state JSON to stdout instead of the human summary
#
# CI-safe: bash + python3 only.
set -uo pipefail

CWD=""
QUIET=0
EMIT_JSON=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*)  CWD="${arg#--cwd=}" ;;
    --quiet)  QUIET=1 ;;
    --json)   EMIT_JSON=1 ;;
    *) ;;
  esac
done

if [ -z "$CWD" ]; then
  echo "ERROR: --cwd=<project-root> is required" >&2
  exit 0   # report-only: never fail a caller
fi
if [ ! -d "${CWD}/.mega-sdd" ]; then
  [ "$QUIET" -eq 1 ] || echo "report-token-cost: no .mega-sdd/ in ${CWD} — nothing to report" >&2
  exit 0
fi

TELEMETRY="${CWD}/.mega-sdd/memory/telemetry.jsonl"

CWD="$CWD" TELEMETRY="$TELEMETRY" QUIET="$QUIET" EMIT_JSON="$EMIT_JSON" python3 <<'PY'
import json, os

cwd = os.environ["CWD"]
telemetry = os.environ["TELEMETRY"]
quiet = os.environ["QUIET"] == "1"
emit_json = os.environ["EMIT_JSON"] == "1"

# Opus price ratios relative to 1 uncached input token.
W = {
    "input_tokens": 1.00,
    "cache_creation_input_tokens": 1.25,
    "cache_read_input_tokens": 0.10,
    "output_tokens": 5.00,
}
TOKKEYS = tuple(W.keys())

def skill_name_of(rec, payload):
    for src in (rec, payload):
        if not isinstance(src, dict):
            continue
        for k in ("skill_name", "skill"):
            v = src.get(k)
            if isinstance(v, str) and v:
                return v
    return None

raw_total = 0
cost_total = 0.0
type_totals = {k: 0 for k in TOKKEYS}
turns = 0
subagent_turns = 0        # subagent_end_marker events with usage — fork cost lives here
per_skill = {}            # skill -> {turns, raw, cost, **type_totals}
current_skill = None
have_telemetry = os.path.isfile(telemetry)

def add_skill(skill):
    if skill not in per_skill:
        per_skill[skill] = {"turns": 0, "raw": 0, "cost_weighted": 0.0,
                            **{k: 0 for k in TOKKEYS}}
    return per_skill[skill]

if have_telemetry:
    with open(telemetry) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            etype = rec.get("event_type")
            payload = rec.get("payload") if isinstance(rec.get("payload"), dict) else {}
            if etype == "skill_invoked":
                # The INVOKED skill is payload.skill_full_name (real telemetry);
                # the top-level "skill" is the emitter context, not the invokee.
                sk = payload.get("skill_full_name") or skill_name_of(rec, payload)
                if isinstance(sk, str) and sk:
                    current_skill = sk
                continue
            if etype not in ("turn_end_marker", "subagent_end_marker"):
                continue
            usage = payload.get("usage") if isinstance(payload.get("usage"), dict) else {}
            if not usage:
                continue
            if etype == "subagent_end_marker":
                # SubagentStop emits the subagent's OWN identity — attribute to it.
                sk = (payload.get("skill_name") or payload.get("agent_type")
                      or rec.get("agent_type") or current_skill or "(subagent)")
                subagent_turns += 1
            else:
                # turn_end_marker's top-level "skill" is the HARDCODED emitter
                # ("orchestrate-flow"), NOT the active phase. Attribute via the
                # skill_invoked bracket so cost lands on the real phase.
                sk = current_skill or "(main-thread)"
            bucket = add_skill(sk)
            turns += 1
            bucket["turns"] += 1
            for k in TOKKEYS:
                v = usage.get(k, 0)
                if not isinstance(v, (int, float)):
                    continue
                v = int(v)
                raw_total += v
                type_totals[k] += v
                bucket[k] += v
                w = v * W[k]
                cost_total += w
                bucket["cost_weighted"] += w
                bucket["raw"] += v

cost_total_i = int(round(cost_total))
ratio = round(raw_total / cost_total, 2) if cost_total > 0 else 0.0

# Per-skill, sorted by cost-weighted desc, rounded.
skills_sorted = sorted(per_skill.items(), key=lambda kv: kv[1]["cost_weighted"], reverse=True)
skills_out = []
for sk, b in skills_sorted:
    skills_out.append({
        "skill": sk, "turns": b["turns"], "raw": b["raw"],
        "cost_weighted": int(round(b["cost_weighted"])),
        "pct_cost": round(100 * b["cost_weighted"] / cost_total, 1) if cost_total > 0 else 0.0,
    })

state = {
    "status": "PASS",   # report-only; always PASS so the analyze aggregate never trips
    "have_telemetry": have_telemetry,
    "turns": turns,
    "subagent_turns": subagent_turns,   # 0 ⇒ no SubagentStop telemetry captured (fork cost invisible)
    "raw_total": raw_total,
    "cost_weighted_total": cost_total_i,
    "overstatement_ratio": ratio,
    "by_token_type": type_totals,
    "weights": W,
    "by_skill": skills_out,
}

def human(n):
    n = float(n)
    for unit, div in (("M", 1_000_000), ("K", 1_000)):
        if abs(n) >= div:
            return f"{n/div:.1f}{unit}"
    return str(int(n))

# Write state JSON.
with open(os.path.join(cwd, ".mega-sdd", ".token-cost-state.json"), "w") as f:
    json.dump(state, f, indent=2)

# Write the human report.
lines = []
lines.append("# Token cost report (cost-weighted)")
lines.append("")
if not have_telemetry:
    lines.append("_No telemetry.jsonl found — run a chain with telemetry enabled first._")
elif turns == 0:
    lines.append("_telemetry.jsonl present but no turn_end_marker / subagent_end_marker events with usage yet._")
else:
    lines.append(f"- **Raw tokens:** {human(raw_total)} ({raw_total:,})")
    lines.append(f"- **Cost-weighted:** {human(cost_total_i)} ({cost_total_i:,}) cost-equivalent input tokens")
    lines.append(f"- **Overstatement:** raw is **{ratio}x** the real cost "
                 f"(cache_read bills 0.1x; output 5x). Judge spend by the cost-weighted number.")
    lines.append("")
    lines.append("| Token type | weight | raw | cost-weighted |")
    lines.append("|---|---:|---:|---:|")
    for k in TOKKEYS:
        v = type_totals[k]
        lines.append(f"| {k} | x{W[k]:.2f} | {v:,} | {int(round(v*W[k])):,} |")
    lines.append("")
    lines.append("## By skill (cost-weighted, descending)")
    lines.append("")
    lines.append("| Skill | turns | raw | cost-weighted | % of cost |")
    lines.append("|---|---:|---:|---:|---:|")
    for s in skills_out:
        lines.append(f"| {s['skill']} | {s['turns']} | {s['raw']:,} | "
                     f"{s['cost_weighted']:,} | {s['pct_cost']}% |")
    lines.append("")
    lines.append("> Cost weights are Opus price ratios relative to 1 uncached input token "
                 "(input x1, cache_creation x1.25, cache_read x0.1, output x5). The cost-weighted "
                 "total is a price-faithful unit, not a raw count.")
with open(os.path.join(cwd, ".mega-sdd", "TOKEN-COST-REPORT.md"), "w") as f:
    f.write("\n".join(lines) + "\n")

if emit_json:
    print(json.dumps(state))
elif not quiet:
    if not have_telemetry:
        print("report-token-cost: no telemetry yet — wrote empty TOKEN-COST-REPORT.md")
    elif turns == 0:
        print("report-token-cost: telemetry present, 0 usage events — wrote TOKEN-COST-REPORT.md")
    else:
        print(f"report-token-cost: {human(raw_total)} raw -> {human(cost_total_i)} cost-equiv "
              f"({ratio}x overstatement) across {turns} turns -> TOKEN-COST-REPORT.md")
PY
exit 0
