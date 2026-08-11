#!/usr/bin/env bash
# Per-task commanded-context footprint for one arm.
# Usage: measure-context.sh <arm-root> <arm-name> <out-json>
# Reads benchmarks/tasks/T*/files.<arm-name>.txt (one repo-relative path per line;
# optional trailing " [SECTION:...]" marker = whole file counted as UPPER BOUND).
# Evidence class: file sizes = MEASURED; the file LISTS are a STATIC TRACE of the
# loading contract (PROXY for runtime context — derivation cited in each task's
# TRACE.md); token figures = ESTIMATED (chars/4).
set -u
ROOT="${1:?arm-root}"; ARM="${2:?arm-name}"; OUT="${3:?out-json}"
BENCH="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$ROOT" "$ARM" "$OUT" "$BENCH" <<'EOF'
import glob, json, os, statistics, sys
root, arm, out, bench = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
tasks = {}
for d in sorted(glob.glob(os.path.join(bench, "tasks", "T*"))):
    tid = os.path.basename(d)
    lst = os.path.join(d, f"files.{arm}.txt")
    if not os.path.isfile(lst):
        tasks[tid] = {"status": "NO_TRACE_FILE"}
        continue
    rows, missing = [], []
    for raw in open(lst):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        section = "[SECTION:" in line
        path = line.split(" [SECTION:")[0].strip()
        full = os.path.join(root, path)
        if not os.path.isfile(full):
            missing.append(path)
            continue
        c = len(open(full, encoding="utf-8", errors="replace").read())
        rows.append({"path": path, "chars": c, "bytes": os.path.getsize(full),
                     "section_upper_bound": section})
    chars = sum(r["chars"] for r in rows)
    tasks[tid] = {"files_loaded": len(rows), "bytes_loaded": sum(r["bytes"] for r in rows),
                  "chars_loaded": chars, "est_tokens": round(chars / 4),
                  "section_upper_bound_files": sum(1 for r in rows if r["section_upper_bound"]),
                  "missing_paths": missing, "files": rows}
ok = [t for t in tasks.values() if "est_tokens" in t]
summary = {}
if ok:
    vals = [t["est_tokens"] for t in ok]
    summary = {"tasks_measured": len(ok), "avg_est_tokens": round(statistics.mean(vals)),
               "median_est_tokens": round(statistics.median(vals)),
               "peak_est_tokens": max(vals),
               "peak_task": max((t for t in tasks.items() if "est_tokens" in t[1]),
                                key=lambda kv: kv[1]["est_tokens"])[0]}
json.dump({"arm": arm, "summary": summary, "tasks": tasks}, open(out, "w"), indent=1)
print(f"{arm}: {len(ok)} tasks traced; " + (f"median {summary['median_est_tokens']} est tok" if ok else "no traces"))
EOF
