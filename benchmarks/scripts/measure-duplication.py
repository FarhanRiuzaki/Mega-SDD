#!/usr/bin/env python3
"""Duplicate-instruction scan for one arm (lower bound, exact-line method).

Usage: measure-duplication.py <arm-root> <arm-name> <out-json>

Method: whitespace-trimmed lines of >= 60 chars appearing in > 1 distinct file
across the instruction plane. Exact match only — fuzzy matching is deliberately
NOT used so legitimate repetition is not misclassified. Duplicate chars =
sum((occurrences - 1) * len(line)). Evidence class: MEASURED (for this metric
definition); it is a LOWER BOUND on semantic duplication.
Parity-pinned deliberate copies (v6.4.0 §S5) are reported, not hidden — the
top-20 list lets a reviewer separate deliberate pins from drift.
"""
import glob, json, os, sys
from collections import defaultdict

root, arm, out = sys.argv[1], sys.argv[2], os.path.abspath(sys.argv[3])
os.chdir(root)
MIN = 60
GLOBS = ["plugins/mega-sdd/skills/**/*.md", "plugins/mega-sdd/commands/**/*.md",
         "plugins/mega-sdd/agents/**/*.md", "plugins/mega-sdd/references/**/*.md"]

files = sorted({p for g in GLOBS for p in glob.glob(g, recursive=True) if os.path.isfile(p)})
where = defaultdict(set)
count = defaultdict(int)
for p in files:
    for line in open(p, encoding="utf-8", errors="replace"):
        t = line.strip()
        if len(t) >= MIN:
            where[t].add(p)
            count[t] += 1

dups = {t: c for t, c in count.items() if len(where[t]) > 1}
dup_chars = sum((c - 1) * len(t) for t, c in dups.items())
total_chars = sum(len(open(p, encoding="utf-8", errors="replace").read()) for p in files)
top = sorted(dups.items(), key=lambda kv: (kv[1] - 1) * len(kv[0]), reverse=True)[:20]

json.dump({"arm": arm, "min_line_chars": MIN,
           "duplicate_line_variants": len(dups),
           "duplicate_chars": dup_chars,
           "duplicate_est_tokens": round(dup_chars / 4),
           "instruction_plane_chars": total_chars,
           "duplicate_pct_of_plane": round(100 * dup_chars / total_chars, 2),
           "top20": [{"occurrences": c, "files": sorted(where[t]), "line": t[:160]}
                     for t, c in top]},
          open(out, "w"), indent=1)
print(f"{arm}: {len(dups)} duplicated line variants, {dup_chars} duplicate chars "
      f"({round(100 * dup_chars / total_chars, 2)}% of plane)")
