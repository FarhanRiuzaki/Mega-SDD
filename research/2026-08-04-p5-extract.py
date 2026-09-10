#!/usr/bin/env python3
"""P5 (A7) measurement extraction — one script, both arms.

Usage:
  python3 2026-08-04-p5-extract.py <transcript.jsonl> <first-unit-commit-iso> [last-unit-commit-iso] [--json <out.json>]

Channels (deterministic, never self-reported): transcript record timestamps,
transcript `usage` fields (main lane), git commit timestamps passed in by the
operator from `git log --format="%h %cI %s"`.

Conventions (pinned in research/2026-08-04-p5-measurement-runbook.md):
- clock start = first record timestamp of the session
- human-wait  = AskUserQuestion open->result gap, plus any >30s gap preceding
  a human text input; reported separately, subtracted for the net number
- idle rule (amended 2026-08-10, applied to BOTH arms identically): ANY
  inter-record gap > 10 min counts as idle regardless of the next record's
  type — the machine cannot work without appending records, so a long silent
  gap is wait even when the next record is a resume/meta record rather than
  typed human input (the first cut missed a ~21h overnight gap this way)
- cost weights = report-token-cost.sh Opus ratios (input x1, cache_creation
  x1.25 @5m / x2.0 @1h, cache_read x0.1, output x5)

v8 P0 additions (2026-09-10, owner mandate "baseline terdekomposisi"): after
the P5 table the script prints (a) a PHASE decomposition (PRE-CODE vs BOLT-1),
(b) a BOLT-1 breakdown — implementer dispatches × duration, review-panel
lenses, verifier / fix rounds, gate-script calls, confirmations — from
tool_use→tool_result spans on the main lane, (c) interaction points (ASK +
mid-run USER waits) and the idle ratio (wait / gross). `--json` writes all of
it to a file (benchmarks/results/ is the intended home). P5 output is
byte-identical to before; the additions only append.
"""
import json
import re
import sys
from datetime import datetime


def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def cw_of(u):
    cc = u.get("cache_creation") or {}
    e5 = cc.get("ephemeral_5m_input_tokens", 0) or 0
    e1 = cc.get("ephemeral_1h_input_tokens", 0) or 0
    raw_cc = u.get("cache_creation_input_tokens", 0) or 0
    unk = max(0, raw_cc - e5 - e1)
    return ((u.get("input_tokens", 0) or 0) * 1.0 + e5 * 1.25 + (e1 + unk) * 2.0
            + (u.get("cache_read_input_tokens", 0) or 0) * 0.10
            + (u.get("output_tokens", 0) or 0) * 5.0)


def raw_of(u):
    return sum((u.get(k, 0) or 0) for k in (
        "input_tokens", "cache_creation_input_tokens",
        "cache_read_input_tokens", "output_tokens"))


def is_human_input(r):
    if r.get("type") != "user" or r.get("isSidechain"):
        return False
    c = (r.get("message") or {}).get("content")
    return isinstance(c, str) and bool(c.strip())


def dur(a, b):
    s = int((b - a).total_seconds())
    return "%dh%02dm%02ds" % (s // 3600, (s % 3600) // 60, s % 60)


def dur_s(seconds):
    s = int(seconds)
    return "%dh%02dm%02ds" % (s // 3600, (s % 3600) // 60, s % 60)


def main():
    args = [a for a in sys.argv[1:]]
    json_out = None
    if "--json" in args:
        i = args.index("--json")
        json_out = args[i + 1]
        del args[i:i + 2]
    if len(args) < 2:
        sys.exit(__doc__)
    path = args[0]
    ep1 = ts(args[1])
    ep2 = ts(args[2]) if len(args) > 2 else None

    recs = []
    for line in open(path, encoding="utf-8", errors="replace"):
        try:
            r = json.loads(line)
        except Exception:
            continue
        if r.get("timestamp"):
            recs.append(r)
    if not recs:
        sys.exit("no timestamped records")

    start = ts(recs[0]["timestamp"])
    models = {}
    tok = {ep1: [0, 0.0]}
    if ep2:
        tok[ep2] = [0, 0.0]

    wait_events = []  # (datetime, kind, seconds)
    prev = None
    ask_open = None
    for r in recs:
        if r.get("isSidechain"):
            continue
        t = ts(r["timestamp"])
        m = r.get("message") or {}
        u = m.get("usage")
        if u:
            models[m.get("model", "?")] = models.get(m.get("model", "?"), 0) + 1
            for ep, acc in tok.items():
                if t <= ep:
                    acc[0] += raw_of(u)
                    acc[1] += cw_of(u)
        # gap check FIRST, against the ask-state at record START — while an
        # AskUserQuestion is open its ASK event carries the whole interval;
        # counting USER/IDLE gaps too would double-bill the wait
        if prev is not None and ask_open is None:
            gap = (t - prev).total_seconds()
            if is_human_input(r) and gap > 30:
                wait_events.append((t, "USER", gap))
            elif gap > 600:
                wait_events.append((t, "IDLE", gap))
        c = m.get("content")
        if isinstance(c, list):
            for item in c:
                if not isinstance(item, dict):
                    continue
                if item.get("type") == "tool_use" and item.get("name") == "AskUserQuestion":
                    ask_open = t
                elif item.get("type") == "tool_result" and ask_open is not None:
                    gap = (t - ask_open).total_seconds()
                    if gap > 5:
                        wait_events.append((t, "ASK", gap))
                    ask_open = None
        prev = t

    print("session_start=%s  records=%d  models=%s" % (start.isoformat(), len(recs), models))
    report = {"session_start": start.isoformat(), "records": len(recs), "models": models,
              "endpoints": {}, "wait_events": [(t.isoformat(), k, g) for (t, k, g) in wait_events]}
    for ep in tok:
        wait = sum(g for (t, _, g) in wait_events if t <= ep)
        gross = (ep - start).total_seconds()
        print("\nendpoint %s" % ep.isoformat())
        print("  gross wall-clock : %s" % dur(start, ep))
        print("  human-wait       : %.1f min (%d events)" %
              (wait / 60, sum(1 for (t, _, g) in wait_events if t <= ep)))
        print("  net machine time : %s" % dur(start, start.__class__.fromtimestamp(
            start.timestamp() + gross - wait, tz=start.tzinfo)))
        print("  raw tokens       : {:,}".format(tok[ep][0]))
        print("  cost-weighted    : {:,.0f}".format(tok[ep][1]))
        report["endpoints"][ep.isoformat()] = {
            "gross_s": gross, "wait_s": wait, "net_s": gross - wait,
            "raw_tokens": tok[ep][0], "cw_tokens": tok[ep][1],
            "idle_ratio": (wait / gross) if gross else None,
            "interaction_points": sum(1 for (t, k, g) in wait_events if t <= ep and k in ("ASK", "USER")),
        }
    print("\nwait events:")
    for t, kind, g in wait_events:
        print("  %s %-5s %6.1f min" % (t.isoformat(), kind, g / 60))

    spans = collect_tool_spans(recs)
    report["phases"] = report_phases(recs, start, ep1, wait_events)
    report["bolt1_breakdown"] = report_bolt1_breakdown(spans, start, ep1, wait_events, report["phases"])
    report["interaction"] = report_interaction(wait_events, ep1, ep2)
    if json_out:
        with open(json_out, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=1, ensure_ascii=False, default=str)
        print("\njson written: %s" % json_out)


# ── Phase decomposition (v8 P0, 2026-09-10) ──────────────────────────────────
# The P5 numbers above are end-to-end. The v8 gate needs the SAME clock split
# into PRE-CODE (session start → first execute-bolts dispatch) and BOLT-1 (that
# dispatch → the first acceptance-backed unit commit), because the fusion
# design only attacks the first band. Boundaries come from deterministic
# transcript records, never from narration:
#   - a main-lane `Skill` tool_use whose input.skill starts with `mega-sdd:`
#   - a main-lane `Agent` tool_use whose subagent_type names bolt-implementer
#     (hand dispatch — gated as execute-bolts since 7.9.0)
#   - a main-lane `Bash` tool_use running ground.sh / derive-state.sh (GROUND)
# Each mark opens a segment that ends at the next mark (the last one ends at
# ep1). Wait events are attributed to the segment they fall in, tokens likewise
# (record timestamp in [seg_start, seg_end)), so the segment nets sum to the
# ep1 net above — a mismatch is a bug in this function, not a finding.
PRE_CODE_END_LABELS = ("mega-sdd:execute-bolts", "bolt-implementer")


def phase_marks(recs):
    marks = []
    for r in recs:
        if r.get("isSidechain") or r.get("type") != "assistant":
            continue
        c = (r.get("message") or {}).get("content")
        if not isinstance(c, list):
            continue
        t = ts(r["timestamp"])
        for item in c:
            if not isinstance(item, dict) or item.get("type") != "tool_use":
                continue
            name = item.get("name")
            inp = item.get("input") or {}
            label = None
            if name == "Skill":
                sk = str(inp.get("skill") or "")
                if sk.startswith("mega-sdd:"):
                    label = sk
            elif name == "Agent":
                st = str(inp.get("subagent_type") or "")
                if "bolt-implementer" in st:
                    label = "bolt-implementer"
            elif name == "Bash":
                cmd = str(inp.get("command") or "")
                if "ground.sh" in cmd or "derive-state.sh" in cmd:
                    label = "GROUND(script)"
            if label:
                marks.append((t, label))
    marks.sort(key=lambda m: m[0])
    return marks


def _seg_stats(recs, wait_events, a, b):
    gross = (b - a).total_seconds()
    wait = sum(g for (t, _, g) in wait_events if a < t <= b)
    raw = cw = 0.0
    for r in recs:
        if r.get("isSidechain"):
            continue
        t = ts(r["timestamp"])
        if not (a <= t < b):
            continue
        u = (r.get("message") or {}).get("usage")
        if u:
            raw += raw_of(u)
            cw += cw_of(u)
    return gross, wait, max(0.0, gross - wait), raw, cw


def report_phases(recs, start, ep1, wait_events):
    marks = [m for m in phase_marks(recs) if m[0] <= ep1]
    out = {"segments": [], "pre_code": None, "bolt1": None, "pre_code_share": None}
    print("\nphase decomposition (v8 P0) — endpoint %s" % ep1.isoformat())
    if not marks:
        print("  no mega-sdd Skill / bolt-implementer / GROUND dispatch found before the endpoint — "
              "cannot decompose (was the run driven through the pipeline?)")
        return out
    # Consecutive marks with the same label collapse into ONE segment ("×N") —
    # a 40-unit run otherwise prints 40 bolt-implementer rows and every
    # derive-state.sh status view its own GROUND row; the per-mark detail is
    # what the BOLT-1 breakdown below is for.
    bounds = [(start, marks[0][0], "front-door / routing")]
    i = 0
    while i < len(marks):
        t, label = marks[i]
        j = i
        while j + 1 < len(marks) and marks[j + 1][1] == label:
            j += 1
        end = marks[j + 1][0] if j + 1 < len(marks) else ep1
        n = j - i + 1
        bounds.append((t, end, label if n == 1 else "%s ×%d" % (label, n)))
        i = j + 1
    pre_code_end = next((t for t, label in marks
                         if any(label.startswith(p) for p in PRE_CODE_END_LABELS)), None)
    print("  %-34s %10s %9s %10s %12s %12s" % ("segment", "gross", "wait", "net", "raw tok", "cw tok"))
    tot_net = 0.0
    for a, b, label in bounds:
        if b <= a:
            continue
        gross, wait, net, raw, cw = _seg_stats(recs, wait_events, a, b)
        tot_net += net
        out["segments"].append({"label": label, "start": a.isoformat(), "end": b.isoformat(),
                                "gross_s": gross, "wait_s": wait, "net_s": net, "raw_tokens": raw, "cw_tokens": cw})
        print("  %-34s %10s %7.1fm %10s %12s %12s" % (
            label[:34], dur(a, b), wait / 60, dur_s(net), "{:,}".format(int(raw)), "{:,.0f}".format(cw)))
    print("  %-34s %10s %9s %10s" % ("(sum of segment nets)", "", "", dur_s(tot_net)))
    if pre_code_end is None:
        print("  PRE-CODE / BOLT-1 split: no execute-bolts or bolt-implementer dispatch before the endpoint")
        return out
    g1, w1, n1, r1, c1 = _seg_stats(recs, wait_events, start, pre_code_end)
    g2, w2, n2, r2, c2 = _seg_stats(recs, wait_events, pre_code_end, ep1)
    total_net = n1 + n2
    share = (100.0 * n1 / total_net) if total_net else 0.0
    out["pre_code"] = {"end": pre_code_end.isoformat(), "gross_s": g1, "wait_s": w1, "net_s": n1, "cw_tokens": c1}
    out["bolt1"] = {"start": pre_code_end.isoformat(), "gross_s": g2, "wait_s": w2, "net_s": n2, "cw_tokens": c2}
    out["pre_code_share"] = share
    print("  PRE-CODE  (start → first bolts dispatch %s): net %s, cw %s" % (
        pre_code_end.isoformat(), dur_s(n1), "{:,.0f}".format(c1)))
    print("  BOLT-1    (dispatch → first unit commit):         net %s, cw %s" % (
        dur_s(n2), "{:,.0f}".format(c2)))
    print("  pre-code share of net time-to-first-code: %.1f%%  (v8 P0 kill-criterion: < 25%% ⇒ stop at P1)" % share)
    return out


# ── BOLT-1 breakdown (owner mandate 2026-09-10: "implementer turns × durasi,
# panel, fix rounds, gate scripts, konfirmasi vs idle") ──────────────────────
# A tool span = main-lane tool_use (assistant record timestamp) → the
# tool_result carrying the same tool_use_id (its record timestamp). Spans are
# classified by the tool + input shape; durations are per span, summed (SUM)
# and merged (UNION — parallel panel lenses overlap in wall time).
REVIEW_LENSES = ("spec-reviewer", "code-quality-reviewer", "security-reviewer",
                 "standards-reviewer", "design-reviewer")
GATE_SCRIPT_RE = re.compile(
    r"scripts/(run-preflight-scan|run-postflight-scan|run-acceptance-tests|run-full-suite|"
    r"run-code-gates|merge-panel-findings|resolve-review-tier|build-dispatch-prompt|"
    r"check-anchor-freshness|build-symbol-index|validate-[a-z0-9-]+|derive-[a-z0-9-]+|ground)\.sh")
UNIT_RE = re.compile(r"\bU-\d{3}\b")


def collect_tool_spans(recs):
    open_uses = {}   # tool_use_id -> dict
    spans = []
    for r in recs:
        if r.get("isSidechain"):
            continue
        c = (r.get("message") or {}).get("content")
        if not isinstance(c, list):
            continue
        t = ts(r["timestamp"])
        for item in c:
            if not isinstance(item, dict):
                continue
            if item.get("type") == "tool_use" and item.get("id"):
                inp = item.get("input") or {}
                kind = "other"
                unit = None
                name = item.get("name")
                if name == "Agent":
                    st = str(inp.get("subagent_type") or "")
                    blob = st + " " + str(inp.get("description") or "") + " " + str(inp.get("prompt") or "")[:400]
                    if "bolt-implementer" in st:
                        kind = "implementer"
                    elif any(l in st for l in REVIEW_LENSES):
                        kind = "panel"
                    elif "resolution-verifier" in st:
                        kind = "verifier"
                    else:
                        kind = "agent-other"
                    um = UNIT_RE.search(blob)
                    unit = um.group(0) if um else None
                elif name == "Bash":
                    cmd = str(inp.get("command") or "")
                    if GATE_SCRIPT_RE.search(cmd):
                        kind = "gate-script"
                    else:
                        kind = "bash-other"
                    um = UNIT_RE.search(cmd)
                    unit = um.group(0) if um else None
                elif name == "AskUserQuestion":
                    kind = "ask"
                elif name == "Skill":
                    kind = "skill"
                open_uses[item["id"]] = {"kind": kind, "name": name, "unit": unit, "start": t, "end": None}
            elif item.get("type") == "tool_result" and item.get("tool_use_id") in open_uses:
                sp = open_uses.pop(item["tool_use_id"])
                sp["end"] = t
                spans.append(sp)
    # unmatched tool_uses (transcript cut / compaction) are dropped, counted
    return spans


def _union_seconds(intervals):
    ivs = sorted((a, b) for a, b in intervals if b > a)
    total = 0.0
    cur_a = cur_b = None
    for a, b in ivs:
        if cur_b is None or a > cur_b:
            if cur_b is not None:
                total += (cur_b - cur_a).total_seconds()
            cur_a, cur_b = a, b
        elif b > cur_b:
            cur_b = b
    if cur_b is not None:
        total += (cur_b - cur_a).total_seconds()
    return total


def report_bolt1_breakdown(spans, start, ep1, wait_events, phases):
    b1 = phases.get("bolt1")
    print("\nBOLT-1 breakdown (v8 P0)")
    if not b1:
        print("  (no BOLT-1 window — see phase decomposition)")
        return None
    a = ts(b1["start"])
    b = ep1
    win = [s for s in spans if a <= s["start"] < b]
    out = {"window_start": a.isoformat(), "window_end": b.isoformat(),
           "gross_s": b1["gross_s"], "wait_s": b1["wait_s"], "net_s": b1["net_s"]}
    rows = []
    for kind, label in (("implementer", "implementer dispatches"), ("panel", "review-panel lenses"),
                        ("verifier", "resolution-verifier (fix rounds)"), ("gate-script", "gate/validator scripts"),
                        ("agent-other", "other Agent dispatches"), ("bash-other", "other Bash calls"),
                        ("skill", "Skill dispatches"), ("ask", "AskUserQuestion")):
        ks = [s for s in win if s["kind"] == kind]
        n = len(ks)
        ssum = sum((s["end"] - s["start"]).total_seconds() for s in ks)
        sunion = _union_seconds([(s["start"], s["end"]) for s in ks])
        units = sorted({s["unit"] for s in ks if s["unit"]})
        out[kind] = {"count": n, "sum_s": ssum, "union_s": sunion, "units": units}
        rows.append((label, n, ssum, sunion, units))
    impl = [s for s in win if s["kind"] == "implementer"]
    per_unit = {}
    for s in impl:
        per_unit[s["unit"] or "?"] = per_unit.get(s["unit"] or "?", 0) + 1
    fix_rounds = sum(max(0, n - 1) for n in per_unit.values())
    out["fix_rounds_from_redispatch"] = fix_rounds
    out["implementer_per_unit"] = per_unit
    active_union = _union_seconds([(s["start"], s["end"]) for s in win if s["kind"] != "ask"])
    out["tool_active_union_s"] = active_union
    print("  window %s → %s  gross %s · wait %.1fm · net %s" % (
        a.isoformat(), b.isoformat(), dur_s(b1["gross_s"]), b1["wait_s"] / 60, dur_s(b1["net_s"])))
    print("  %-34s %6s %10s %10s  %s" % ("class", "count", "sum", "union", "units"))
    for label, n, ssum, sunion, units in rows:
        print("  %-34s %6d %10s %10s  %s" % (label, n, dur_s(ssum), dur_s(sunion), ",".join(units)[:40]))
    print("  fix rounds (implementer re-dispatch per unit − 1): %d   per-unit dispatches: %s" % (
        fix_rounds, per_unit))
    print("  tool-active union (all non-ask spans): %s  = %.0f%% of BOLT-1 net; the remainder is "
          "controller reasoning/reading between tool calls" % (
              dur_s(active_union), (100.0 * active_union / b1["net_s"]) if b1["net_s"] else 0.0))
    print("  CAVEAT: Agent spans measure MAIN-LANE blocking time only. A background dispatch "
          "(execute-bolts waves, parallel panel lenses) returns its tool_result at once and does its "
          "work on the sidechain, so implementer/panel 'sum' here is a LOWER BOUND of their runtime; "
          "the COUNTS and the per-unit re-dispatch (fix rounds) are exact. Gate scripts and other Bash "
          "calls are foreground and exact.")
    out["caveat"] = "agent spans = main-lane blocking only; background dispatch runtime lives on the sidechain (counts exact, durations lower bound)"
    return out


def report_interaction(wait_events, ep1, ep2):
    out = {}
    for ep in (ep1, ep2):
        if ep is None:
            continue
        asks = [(t, g) for (t, k, g) in wait_events if k == "ASK" and t <= ep]
        users = [(t, g) for (t, k, g) in wait_events if k == "USER" and t <= ep]
        idle = [(t, g) for (t, k, g) in wait_events if k == "IDLE" and t <= ep]
        out[ep.isoformat()] = {"ask_points": len(asks), "user_wait_points": len(users), "idle_events": len(idle),
                               "interaction_points": len(asks) + len(users)}
    print("\ninteraction points (v8 W1 budget: 3-screen ≤2, clinic ≤3)")
    for ep, d in out.items():
        print("  to %s: ASK %d + mid-run USER waits %d = %d interaction point(s); %d idle event(s) >10min" % (
            ep, d["ask_points"], d["user_wait_points"], d["interaction_points"], d["idle_events"]))
    return out


if __name__ == "__main__":
    main()
