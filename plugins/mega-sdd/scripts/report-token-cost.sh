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
#   cache_creation @ 5-min TTL  x1.25
#   cache_creation @ 1-hour TTL x2.00   <- Claude Code writes 1h TTL on the main lane
#   cache_read_input_tokens     x0.10
#   output_tokens               x5.00
# Cost-weighted total is in "cost-equivalent input tokens" — a price-faithful unit,
# NOT a raw count. raw/cost ratio > 1 means the raw number overstates the bill.
#
# CACHE-CREATION TTL (v5.13.0 — was a flat x1.25, i.e. the 5-minute rate applied to
# everything, understating the main lane by 60% on its single largest line item):
# cache_creation has TWO prices and the transcript states which one applied, per
# message, in `usage.cache_creation.ephemeral_{5m,1h}_input_tokens`. The Stop /
# SubagentStop hooks now carry that split into telemetry, so this report prices
# cache creation EXACTLY rather than assuming a TTL.
#   - split present  -> measured: 5m x1.25 + 1h x2.00.
#   - split absent   -> assumed lane default (telemetry written before v5.13.0):
#                       main lane x2.00 (measured 1h), subagent lane x1.25 (5m).
# The report and the state JSON both label how much of cache_creation was measured
# vs assumed — an assumed baseline must never be read as a measured one.
#
# REPORT-ONLY: reads <cwd>/.mega-sdd/memory/telemetry.jsonl, writes
# <cwd>/.mega-sdd/TOKEN-COST-REPORT.md + <cwd>/.mega-sdd/.token-cost-state.json.
# Touches no gate and no moat state. Exit 0 always (a report can never block a chain).
#
# Usage: report-token-cost.sh --cwd=<project-root> [--quiet] [--json]
#                              [--price-table=<yaml>] [--vault=<vault-dir>]
#   --quiet  suppress the one-line stdout summary (still writes the files)
#   --json   print the state JSON to stdout instead of the human summary
#   --price-table=<yaml>  gateway price list (per-MTok, any currency) -> adds a
#            BILLED-cost section priced from the per-model raw token types. Only
#            token types with a price key are billed; everything else is counted
#            UNPRICED and said so — an absent price is never invented (v7.1
#            routing gate: the flip decision needs gateway-price-weighted cost).
#            YAML shape (2-level, no deps):  currency: USD
#                                            <model-id>: {input:, output:,
#                                              cache_read:, cache_creation:,
#                                              cache_creation_5m:, cache_creation_1h:}
#   --vault=<dir>  read <vault>/bolts/U-*/bolt-report.md and render a per-bolt
#            model_used table (the v7.1 routing audit trail: model_used is copied
#            verbatim from the implementer's own system prompt; escalated_from
#            records a cascade hop).
#
# CI-safe: bash + python3 only.
set -uo pipefail

CWD=""
QUIET=0
EMIT_JSON=0
PRICE_TABLE=""
VAULT=""
for arg in "$@"; do
  case "$arg" in
    --cwd=*)  CWD="${arg#--cwd=}" ;;
    --quiet)  QUIET=1 ;;
    --json)   EMIT_JSON=1 ;;
    --price-table=*) PRICE_TABLE="${arg#--price-table=}" ;;
    --vault=*) VAULT="${arg#--vault=}" ;;
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

CWD="$CWD" TELEMETRY="$TELEMETRY" QUIET="$QUIET" EMIT_JSON="$EMIT_JSON" \
PRICE_TABLE="$PRICE_TABLE" VAULT="$VAULT" python3 <<'PY'
import glob, json, os, re

cwd = os.environ["CWD"]
telemetry = os.environ["TELEMETRY"]
quiet = os.environ["QUIET"] == "1"
emit_json = os.environ["EMIT_JSON"] == "1"
price_table_path = os.environ.get("PRICE_TABLE") or ""
vault_dir = os.environ.get("VAULT") or ""

# Opus price ratios relative to 1 uncached input token.
# NOTE: W["cache_creation_input_tokens"] is the FALLBACK weight only — it is used
# for pre-v5.13.0 telemetry that carries no TTL split, and it is lane-dependent
# (see CC_LANE_FALLBACK). Where the split IS present, cache creation is priced by
# CC_5M / CC_1H instead. Both paths are accounted separately and labelled.
CC_5M = 1.25          # cache_creation at the 5-minute TTL
CC_1H = 2.00          # cache_creation at the 1-hour TTL
CC_LANE_FALLBACK = {  # measured harness behaviour, per lane, when no split is present
    "turn_end_marker": CC_1H,       # main lane writes 1h
    "subagent_end_marker": CC_5M,   # subagent lane writes 5m
}
W = {
    "input_tokens": 1.00,
    "cache_creation_input_tokens": CC_1H,
    "cache_read_input_tokens": 0.10,
    "output_tokens": 5.00,
}
TOKKEYS = tuple(W.keys())
# Split keys ride inside payload.usage but are NOT summed into raw/by_token_type —
# they are a breakdown OF cache_creation_input_tokens, not an additional lane.
SPLIT_5M = "cache_creation_5m_input_tokens"
SPLIT_1H = "cache_creation_1h_input_tokens"

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
per_model = {}            # model -> {turns, cost} — settles "which tier did this run at"
current_skill = None
have_telemetry = os.path.isfile(telemetry)
# cache_creation provenance: exactly-priced (TTL known) vs lane-assumed.
cc_measured_5m = 0
cc_measured_1h = 0
cc_assumed = 0

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
            event_cost = 0.0
            event_types = {k: 0 for k in TOKKEYS}   # per-event, for by-model billing
            event_cc = {"m5": 0, "m1": 0, "unknown": 0}
            for k in TOKKEYS:
                v = usage.get(k, 0)
                if not isinstance(v, (int, float)):
                    continue
                v = int(v)
                raw_total += v
                type_totals[k] += v
                bucket[k] += v
                event_types[k] += v
                if k == "cache_creation_input_tokens":
                    # Price by the TTL the harness actually used, when it told us.
                    s5 = usage.get(SPLIT_5M, 0)
                    s1 = usage.get(SPLIT_1H, 0)
                    s5 = int(s5) if isinstance(s5, (int, float)) else 0
                    s1 = int(s1) if isinstance(s1, (int, float)) else 0
                    split = s5 + s1
                    if split > 0:
                        # Any residual beyond the stated split falls back to the lane
                        # default rather than being silently dropped or over-credited.
                        residual = max(0, v - split)
                        cc_measured_5m += s5
                        cc_measured_1h += s1
                        cc_assumed += residual
                        event_cc["m5"] += s5
                        event_cc["m1"] += s1
                        event_cc["unknown"] += residual
                        w = s5 * CC_5M + s1 * CC_1H + residual * CC_LANE_FALLBACK.get(etype, CC_1H)
                    else:
                        cc_assumed += v
                        event_cc["unknown"] += v
                        w = v * CC_LANE_FALLBACK.get(etype, CC_1H)
                else:
                    w = v * W[k]
                cost_total += w
                event_cost += w
                bucket["cost_weighted"] += w
                bucket["raw"] += v
            mdl = payload.get("model")
            # Billing needs EVERY event attributed — an event with no model field
            # lands under "(model unknown)" and is always unpriced, never guessed.
            mkey = mdl if isinstance(mdl, str) and mdl else "(model unknown)"
            mb = per_model.setdefault(mkey, {"turns": 0, "cost_weighted": 0.0,
                                             **{k: 0 for k in TOKKEYS},
                                             "cc_5m": 0, "cc_1h": 0, "cc_unknown": 0})
            mb["turns"] += 1
            mb["cost_weighted"] += event_cost
            for k in TOKKEYS:
                mb[k] += event_types[k]
            mb["cc_5m"] += event_cc["m5"]
            mb["cc_1h"] += event_cc["m1"]
            mb["cc_unknown"] += event_cc["unknown"]

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

cc_total = cc_measured_5m + cc_measured_1h + cc_assumed
cc_pct_measured = round(100 * (cc_measured_5m + cc_measured_1h) / cc_total, 1) if cc_total > 0 else 0.0

# "(model unknown)" rows exist for billing honesty; surface them in by_model only
# when they sit NEXT TO real models (mixed telemetry) or a price table is in play —
# pure pre-v5.13.0 telemetry keeps its historical empty by_model.
have_real_model = any(m != "(model unknown)" for m in per_model)
models_out = [
    {"model": m, "turns": b["turns"], "cost_weighted": int(round(b["cost_weighted"])),
     "pct_cost": round(100 * b["cost_weighted"] / cost_total, 1) if cost_total > 0 else 0.0}
    for m, b in sorted(per_model.items(), key=lambda kv: kv[1]["cost_weighted"], reverse=True)
    if m != "(model unknown)" or have_real_model or price_table_path
]

# ── Billed cost (price table) — v7.1: gateway-price-weighted, never invented ──
def parse_price_table(path):
    """Minimal 2-level YAML: top-level scalars (currency) + model blocks of
    numeric prices per MTok. Returns (currency, {model: {key: float}}, error)."""
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError as e:
        return "", {}, "unreadable: %s" % e
    currency, prices, current = "", {}, None
    for ln in lines:
        if not ln.strip() or ln.lstrip().startswith("#"):
            continue
        m = re.match(r"^(\s*)([^:#]+):\s*(.*?)\s*$", ln)
        if not m:
            continue
        indent, key, val = len(m.group(1)), m.group(2).strip().strip("\"'"), m.group(3).strip().strip("\"'")
        val = val.split("#", 1)[0].strip().strip("\"'")
        if indent == 0:
            if val == "":
                current = prices.setdefault(key, {})
            elif key == "currency":
                currency, current = val, None
            else:
                current = None   # unknown top-level scalar — ignored
        elif current is not None and val != "":
            try:
                current[key] = float(val)
            except ValueError:
                pass   # non-numeric price — ignored, stays unpriced
    return currency, prices, None

billed = None
if price_table_path:
    currency, prices, pt_err = parse_price_table(price_table_path)
    if pt_err:
        billed = {"status": "price_table_unreadable", "price_table": price_table_path,
                  "error": pt_err}
    else:
        by_model_billed, billed_total, unpriced_total = [], 0.0, 0
        for m, b in sorted(per_model.items(), key=lambda kv: kv[1]["cost_weighted"], reverse=True):
            p = prices.get(m, {})
            cost, unpriced = 0.0, 0
            # flat-priced types
            for tok_key, price_key in (("input_tokens", "input"),
                                       ("output_tokens", "output"),
                                       ("cache_read_input_tokens", "cache_read")):
                v = b[tok_key]
                if price_key in p:
                    cost += v * p[price_key] / 1e6
                else:
                    unpriced += v
            # cache_creation: TTL-split rates, falling back to a single
            # cache_creation price; a token with no applicable key stays unpriced.
            cc_base = p.get("cache_creation")
            for split_key, price_key in (("cc_5m", "cache_creation_5m"),
                                         ("cc_1h", "cache_creation_1h")):
                v = b[split_key]
                rate = p.get(price_key, cc_base)
                if rate is not None:
                    cost += v * rate / 1e6
                else:
                    unpriced += v
            if cc_base is not None:
                cost += b["cc_unknown"] * cc_base / 1e6
            else:
                unpriced += b["cc_unknown"]
            billed_total += cost
            unpriced_total += unpriced
            by_model_billed.append({"model": m, "priced": m in prices,
                                    "billed": round(cost, 4),
                                    "unpriced_tokens": unpriced})
        billed = {"status": "ok", "price_table": price_table_path,
                  "currency": currency or "(currency unlabelled)",
                  "total": round(billed_total, 4),
                  "unpriced_tokens_total": unpriced_total,
                  "by_model": by_model_billed}

# ── Per-bolt model_used (v7.1 routing audit trail) — read from bolt-reports ──
bolts_out = []
if vault_dir:
    for rp in sorted(glob.glob(os.path.join(vault_dir, "bolts", "U-*", "bolt-report.md"))):
        try:
            txt = open(rp, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        unit = os.path.basename(os.path.dirname(rp))
        entry = {"unit": unit, "status": "", "model_used": "", "escalated_from": ""}
        m = re.search(r"(?m)^unit:\s*[\"']?([\w.-]+)", txt)
        if m:
            entry["unit"] = m.group(1)
        m = re.search(r"(?m)^status:\s*[\"']?([\w-]+)", txt)
        if m:
            entry["status"] = m.group(1)
        m = re.search(r"(?m)^\s*model_used:\s*[\"']?(.*?)[\"']?\s*$", txt)
        if m:
            entry["model_used"] = m.group(1)
        m = re.search(r"(?m)^\s*escalated_from:\s*[\"']?(.*?)[\"']?\s*$", txt)
        if m:
            entry["escalated_from"] = m.group(1)
        bolts_out.append(entry)

state = {
    "status": "PASS",   # report-only; always PASS so the analyze aggregate never trips
    "have_telemetry": have_telemetry,
    "turns": turns,
    "subagent_turns": subagent_turns,   # 0 ⇒ no SubagentStop telemetry captured (fork cost invisible)
    "raw_total": raw_total,
    "cost_weighted_total": cost_total_i,
    "overstatement_ratio": ratio,
    "by_token_type": type_totals,
    # Provenance of the single largest line item. pct_measured < 100 ⇒ part of this
    # total is a lane ASSUMPTION (pre-v5.13.0 telemetry), not a measurement.
    "cache_creation_ttl": {
        "measured_5m": cc_measured_5m,
        "measured_1h": cc_measured_1h,
        "assumed": cc_assumed,
        "pct_measured": cc_pct_measured,
    },
    "weights": dict(W, cache_creation_5m=CC_5M, cache_creation_1h=CC_1H),
    "by_skill": skills_out,
    "by_model": models_out,   # empty for pre-v5.13.0 telemetry (no model field emitted)
}
if billed is not None:
    state["billed"] = billed
if vault_dir:
    state["by_bolt"] = bolts_out

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
        if k == "cache_creation_input_tokens":
            # Priced per TTL, so a single weight column would be a fiction here.
            cc_cost = cc_measured_5m * CC_5M + cc_measured_1h * CC_1H + cc_assumed * CC_1H
            lines.append(f"| {k} | per-TTL | {v:,} | {int(round(cc_cost)):,} |")
            lines.append(f"| &nbsp;&nbsp;↳ @5m TTL (measured) | x{CC_5M:.2f} | {cc_measured_5m:,} | "
                         f"{int(round(cc_measured_5m*CC_5M)):,} |")
            lines.append(f"| &nbsp;&nbsp;↳ @1h TTL (measured) | x{CC_1H:.2f} | {cc_measured_1h:,} | "
                         f"{int(round(cc_measured_1h*CC_1H)):,} |")
            lines.append(f"| &nbsp;&nbsp;↳ TTL unknown (lane default) | x{CC_1H:.2f}/x{CC_5M:.2f} | "
                         f"{cc_assumed:,} | {int(round(cc_assumed*CC_1H)):,} |")
            continue
        lines.append(f"| {k} | x{W[k]:.2f} | {v:,} | {int(round(v*W[k])):,} |")
    lines.append("")
    if cc_total > 0:
        if cc_pct_measured >= 99.95:
            lines.append("> **cache_creation TTL: 100% measured.** Every cache-creation token was "
                         "priced at the TTL the harness actually used.")
        elif cc_pct_measured <= 0.05:
            lines.append("> ⚠️ **cache_creation TTL: 0% measured — this total is an ESTIMATE.** "
                         "This telemetry predates the TTL split (v5.13.0), so cache creation is "
                         "priced by lane default (main x2.00, subagent x1.25). Treat it as an "
                         "assumed baseline, not a measurement.")
        else:
            lines.append(f"> ⚠️ **cache_creation TTL: {cc_pct_measured}% measured, "
                         f"{round(100-cc_pct_measured,1)}% lane-assumed.** Mixed telemetry — the "
                         "assumed share is an estimate, not a measurement.")
        lines.append("")
    if models_out:
        lines.append("## By model (cost-weighted, descending)")
        lines.append("")
        lines.append("| Model | turns | cost-weighted | % of cost |")
        lines.append("|---|---:|---:|---:|")
        for m in models_out:
            lines.append(f"| {m['model']} | {m['turns']} | {m['cost_weighted']:,} | {m['pct_cost']}% |")
        lines.append("")
    if billed is not None:
        lines.append("## Billed cost (gateway price table)")
        lines.append("")
        if billed["status"] != "ok":
            lines.append(f"> ⚠️ price table `{billed['price_table']}` unreadable — no billed "
                         f"figures ({billed['error']}). Nothing was estimated in its place.")
        else:
            lines.append(f"_Prices: `{billed['price_table']}` (per MTok, {billed['currency']})._")
            lines.append("")
            lines.append("| Model | in table | billed | unpriced tokens |")
            lines.append("|---|---|---:|---:|")
            for mb in billed["by_model"]:
                lines.append(f"| {mb['model']} | {'yes' if mb['priced'] else 'NO'} | "
                             f"{mb['billed']:,} | {mb['unpriced_tokens']:,} |")
            lines.append(f"| **TOTAL** | | **{billed['total']:,} {billed['currency']}** | "
                         f"{billed['unpriced_tokens_total']:,} |")
            if billed["unpriced_tokens_total"] > 0:
                lines.append("")
                lines.append("> ⚠️ **Unpriced tokens > 0 — the billed total is a LOWER BOUND.** "
                             "A token type (or model) missing from the price table contributes "
                             "0; add its price rather than reading this as the full bill.")
        lines.append("")
    if vault_dir:
        lines.append("## By bolt (model_used — v7.1 routing audit trail)")
        lines.append("")
        if not bolts_out:
            lines.append(f"_No `bolts/U-*/bolt-report.md` found under `{vault_dir}`._")
        else:
            lines.append("| Unit | status | model_used | escalated_from |")
            lines.append("|---|---|---|---|")
            for e in bolts_out:
                lines.append(f"| {e['unit']} | {e['status'] or '?'} | "
                             f"{e['model_used'] or '(not recorded)'} | {e['escalated_from'] or '—'} |")
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
                 "(input x1, cache_creation x1.25 @5m / x2.00 @1h, cache_read x0.1, output x5). "
                 "The cost-weighted total is a price-faithful unit, not a raw count.")
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
