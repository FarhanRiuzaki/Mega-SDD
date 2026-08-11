#!/usr/bin/env bash
# Static instruction-plane footprint for one arm.
# Usage: measure-static.sh <arm-root> <arm-name> <out-json>
# Evidence class: files/bytes/chars = MEASURED; token figures = ESTIMATED (chars/4).
set -u
ROOT="${1:?arm-root}"; ARM="${2:?arm-name}"; OUT="${3:?out-json}"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
cd "$ROOT" || exit 2

python3 - "$ARM" "$OUT" <<'EOF'
import glob, json, os, statistics, sys
arm, out = sys.argv[1], sys.argv[2]

INSTR = ["plugins/mega-sdd/skills/**/*.md", "plugins/mega-sdd/commands/**/*.md",
         "plugins/mega-sdd/agents/**/*.md", "plugins/mega-sdd/references/**/*.md"]
EXEC  = ["plugins/mega-sdd/scripts/**", "plugins/mega-sdd/hooks/**"]

def collect(globs):
    fs = set()
    for g in globs:
        for p in glob.glob(g, recursive=True):
            if os.path.isfile(p):
                fs.add(p)
    return sorted(fs)

def stat_set(files):
    rows = []
    for p in files:
        b = os.path.getsize(p)
        try:
            c = len(open(p, encoding="utf-8", errors="replace").read())
        except Exception:
            c = b
        rows.append({"path": p, "bytes": b, "chars": c, "est_tokens": round(c / 4)})
    return rows

instr = stat_set(collect(INSTR))
execu = stat_set(collect(EXEC))
skills = [r for r in instr if r["path"].endswith("/SKILL.md")]
refs   = [r for r in instr if "/references/" in r["path"] and r["path"].startswith("plugins/mega-sdd/skills/")]

def agg(rows):
    if not rows:
        return {"files": 0, "bytes": 0, "chars": 0, "est_tokens": 0}
    sizes = [r["chars"] for r in rows]
    big = max(rows, key=lambda r: r["chars"]); small = min(rows, key=lambda r: r["chars"])
    return {"files": len(rows), "bytes": sum(r["bytes"] for r in rows),
            "chars": sum(sizes), "est_tokens": round(sum(sizes) / 4),
            "avg_chars": round(statistics.mean(sizes)), "median_chars": round(statistics.median(sizes)),
            "largest": {"path": big["path"], "chars": big["chars"]},
            "smallest": {"path": small["path"], "chars": small["chars"]}}

json.dump({"arm": arm,
           "instruction_plane": agg(instr),
           "skill_md_only": agg(skills),
           "skill_references_only": agg(refs),
           "executed_plane": agg(execu),
           "per_file": instr}, open(out, "w"), indent=1)
print(f"{arm}: instruction plane {agg(instr)['files']} files, {agg(instr)['bytes']} bytes")
EOF
