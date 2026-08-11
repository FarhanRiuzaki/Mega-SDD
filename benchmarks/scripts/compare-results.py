#!/usr/bin/env python3
"""Merge both arms' results into results.json + printable comparison tables.

Usage: compare-results.py
Reads benchmarks/results/{baseline,optimized}/*.json; writes
benchmarks/results/comparison/results.json and prints markdown tables
(REPORT.md embeds them with narrative + evidence classification).
"""
import json, os, sys

BENCH = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def load(arm, name):
    p = os.path.join(BENCH, "results", arm, f"{name}.json")
    return json.load(open(p)) if os.path.isfile(p) else None

def delta(b, o):
    if b in (None, 0) or o is None:
        return {"abs": None, "pct": None}
    return {"abs": o - b, "pct": round(100 * (o - b) / b, 1)}

out = {"config": json.load(open(os.path.join(BENCH, "config", "benchmark.config.json"))),
       "arms": {}, "comparison": {}}

for arm in ("baseline", "optimized"):
    out["arms"][arm] = {k: load(arm, k) for k in ("static", "duplication", "context", "quality")}

b, o = out["arms"]["baseline"], out["arms"]["optimized"]

# static
cmp_static = {}
if b["static"] and o["static"]:
    for plane in ("instruction_plane", "skill_md_only", "skill_references_only", "executed_plane"):
        pb, po = b["static"][plane], o["static"][plane]
        cmp_static[plane] = {m: {"baseline": pb[m], "optimized": po[m], **delta(pb[m], po[m])}
                             for m in ("files", "bytes", "chars", "est_tokens")}
out["comparison"]["static"] = cmp_static

# duplication
if b["duplication"] and o["duplication"]:
    out["comparison"]["duplication"] = {
        m: {"baseline": b["duplication"][m], "optimized": o["duplication"][m],
            **delta(b["duplication"][m], o["duplication"][m])}
        for m in ("duplicate_line_variants", "duplicate_chars", "duplicate_est_tokens",
                  "duplicate_pct_of_plane")}

# context per task
cmp_ctx = {}
if b["context"] and o["context"]:
    for tid in sorted(set(b["context"]["tasks"]) | set(o["context"]["tasks"])):
        tb = b["context"]["tasks"].get(tid, {})
        to = o["context"]["tasks"].get(tid, {})
        if "est_tokens" in tb and "est_tokens" in to:
            cmp_ctx[tid] = {"baseline_est_tokens": tb["est_tokens"],
                            "optimized_est_tokens": to["est_tokens"],
                            "baseline_files": tb["files_loaded"], "optimized_files": to["files_loaded"],
                            **delta(tb["est_tokens"], to["est_tokens"])}
        else:
            cmp_ctx[tid] = {"status": "INCOMPLETE_TRACE"}
    out["comparison"]["context_per_task"] = cmp_ctx
    out["comparison"]["context_summary"] = {
        "baseline": b["context"]["summary"], "optimized": o["context"]["summary"]}

# quality
if b["quality"] and o["quality"]:
    out["comparison"]["quality"] = {"baseline": b["quality"], "optimized": o["quality"],
        "no_regression": b["quality"]["quality_pass"] == "PASS" and o["quality"]["quality_pass"] == "PASS"}

dst = os.path.join(BENCH, "results", "comparison", "results.json")
json.dump(out, open(dst, "w"), indent=1)
print(f"wrote {dst}\n")

def row(name, m):
    d = m.get("abs"); p = m.get("pct")
    return f"| {name} | {m['baseline']:,} | {m['optimized']:,} | {d:+,} | {p:+.1f}% |" if d is not None else f"| {name} | - | - | - | - |"

if cmp_static:
    print("### Static footprint (instruction plane)\n")
    print("| Metric | Baseline | Optimized | Δ | % |\n|---|---:|---:|---:|---:|")
    for plane in cmp_static:
        for m in ("files", "bytes", "est_tokens"):
            print(row(f"{plane}.{m}", cmp_static[plane][m]))
    print()
if cmp_ctx:
    print("### Commanded context per task (static trace, est tokens)\n")
    print("| Task | Baseline | Optimized | Δ | % |\n|---|---:|---:|---:|---:|")
    for tid, c in cmp_ctx.items():
        if "abs" in c and c["abs"] is not None:
            print(f"| {tid} | {c['baseline_est_tokens']:,} | {c['optimized_est_tokens']:,} | {c['abs']:+,} | {c['pct']:+.1f}% |")
        else:
            print(f"| {tid} | INCOMPLETE | INCOMPLETE | - | - |")
