#!/usr/bin/env python3
"""P5 (A7) measurement extraction — one script, both arms.

Usage:
  python3 2026-08-04-p5-extract.py <transcript.jsonl> <first-unit-commit-iso> [last-unit-commit-iso]

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
"""
import json
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


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    path = sys.argv[1]
    ep1 = ts(sys.argv[2])
    ep2 = ts(sys.argv[3]) if len(sys.argv) > 3 else None

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
    print("\nwait events:")
    for t, kind, g in wait_events:
        print("  %s %-5s %6.1f min" % (t.isoformat(), kind, g / 60))


if __name__ == "__main__":
    main()
