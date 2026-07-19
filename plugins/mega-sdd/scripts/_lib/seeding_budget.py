#!/usr/bin/env python3
"""seeding_budget.py — the P7 measurement + enforcement instrument (thin).

One job: given a *seed* (the set of files, or a blob of text, that a consumer —
a subagent dispatch, a skill's opening load — is handed), report how big it is
in bytes and in approximate tokens, and optionally verdict it against a budget.

This is the ruler for the whole slice-first phase: every bind-slice /
advisor-bundle / kb-claims cut is justified by a before/after from THIS tool, so
"boros token" is answered in numbers, not assertion. Keep it a counter, never a
framework — no tokenizer dependency, no network, deterministic.

Token estimate: ceil(bytes / TOKENS_DIVISOR). ~4 bytes/token is the standard
rule-of-thumb for English + code. This is for RANKING and BUDGET verdicts only —
it is NOT a billing figure and never claims to be.

Cost weighting (`--weight`): raw bytes are the WRONG unit for ranking token
work, because a fresh subagent seed is paid at full rate while a resident main-
context load is cached at ~0.1x after turn 1 (research §2: cache_read is 91.9%
of raw at 0.1x; subagent seeding is the largest real-dollar bucket). `--weight
fresh` (=1.0) / `--weight resident` (=0.1) / `--weight <float>` multiplies
approx-tokens into cost-units so the ranking reflects real dollars, not bytes —
a whole-map paste into an advisor (fresh) outranks a bigger resident load.

CLI:
  seeding_budget.py [paths...] [--stdin] [--label NAME] [--budget N]
                    [--enforce] [--weight fresh|resident|FLOAT] [--json]

  paths       files (dirs expand to their files, non-recursive by default;
              --recursive to walk) — each counted once (dedup by realpath)
  --stdin     also count text piped on stdin (labeled "<stdin>")
  --budget N  verdict the total (cost-units if --weight, else approx-tokens)
              against N (advisory by default)
  --enforce   make --budget blocking: exit 1 when OVER (else always exit 0)
  --weight W  fresh (1.0) | resident (0.1) | a float — emit cost_units
  --json      emit the machine record instead of the table

Exit: 0 = measured (or UNDER/no-budget); 1 = OVER and --enforce; 3 = usage.
"""
import json
import math
import os
import sys

TOKENS_DIVISOR = 4  # bytes-per-token rule-of-thumb; ranking/budget only
CACHE_WEIGHTS = {"fresh": 1.0, "resident": 0.1}  # subagent-seed vs resident-cached


def approx_tokens(nbytes):
    return math.ceil(nbytes / TOKENS_DIVISOR) if nbytes else 0


def _iter_paths(paths, recursive):
    """Yield (realpath, display) for each existing file, deduped, dirs expanded.

    A missing path is yielded with nbytes=None so the caller can surface it —
    silently dropping a seed component would understate the seed (the exact
    failure the moat forbids: a measurement that lies by omission)."""
    seen = set()
    for p in paths:
        if not os.path.exists(p):
            yield (p, p, None)
            continue
        if os.path.isdir(p):
            if recursive:
                for root, _dirs, files in os.walk(p):
                    for f in sorted(files):
                        fp = os.path.join(root, f)
                        rp = os.path.realpath(fp)
                        if rp not in seen:
                            seen.add(rp)
                            yield (rp, fp, os.path.getsize(fp))
            else:
                for f in sorted(os.listdir(p)):
                    fp = os.path.join(p, f)
                    if os.path.isfile(fp):
                        rp = os.path.realpath(fp)
                        if rp not in seen:
                            seen.add(rp)
                            yield (rp, fp, os.path.getsize(fp))
        else:
            rp = os.path.realpath(p)
            if rp not in seen:
                seen.add(rp)
                yield (rp, p, os.path.getsize(p))


def measure(paths, stdin_bytes=0, recursive=False, weight=None):
    """Return a record: total bytes/tokens + per-component breakdown + missing.

    When `weight` is a float, add cost_units = round(approx_tokens * weight) —
    the cache-weighted unit the ranking should actually use."""
    components = []
    total = 0
    missing = []
    for _rp, display, nbytes in _iter_paths(paths, recursive):
        if nbytes is None:
            missing.append(display)
            continue
        components.append({"path": display, "bytes": nbytes,
                           "approx_tokens": approx_tokens(nbytes)})
        total += nbytes
    if stdin_bytes:
        components.append({"path": "<stdin>", "bytes": stdin_bytes,
                           "approx_tokens": approx_tokens(stdin_bytes)})
        total += stdin_bytes
    rec = {
        "bytes": total,
        "approx_tokens": approx_tokens(total),
        "components": components,
        "missing": missing,
    }
    if weight is not None:
        rec["weight"] = weight
        rec["cost_units"] = round(approx_tokens(total) * weight)
    return rec


def main(argv):
    paths, use_stdin, label, budget, enforce, as_json, recursive, weight_arg = \
        [], False, None, None, False, False, False, None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--stdin":
            use_stdin = True
        elif a == "--json":
            as_json = True
        elif a == "--enforce":
            enforce = True
        elif a == "--recursive":
            recursive = True
        elif a == "--label":
            i += 1
            label = argv[i] if i < len(argv) else None
        elif a.startswith("--label="):
            label = a.split("=", 1)[1]
        elif a == "--budget":
            i += 1
            budget = argv[i] if i < len(argv) else None
        elif a.startswith("--budget="):
            budget = a.split("=", 1)[1]
        elif a == "--weight":
            i += 1
            weight_arg = argv[i] if i < len(argv) else None
        elif a.startswith("--weight="):
            weight_arg = a.split("=", 1)[1]
        elif a.startswith("--"):
            print(f"usage: seeding_budget.py [paths...] [--stdin] [--label N] "
                  f"[--budget N] [--enforce] [--json]  (unknown flag: {a})",
                  file=sys.stderr)
            return 3
        else:
            paths.append(a)
        i += 1

    stdin_bytes = 0
    if use_stdin:
        stdin_bytes = len(sys.stdin.buffer.read())
    if not paths and not use_stdin:
        print("usage: seeding_budget.py [paths...] [--stdin] [--budget N] "
              "[--enforce] [--json]", file=sys.stderr)
        return 3

    weight = None
    if weight_arg is not None:
        if weight_arg in CACHE_WEIGHTS:
            weight = CACHE_WEIGHTS[weight_arg]
        else:
            try:
                weight = float(weight_arg)
            except ValueError:
                print(f"FAIL: --weight must be fresh|resident|<float> (got {weight_arg})",
                      file=sys.stderr)
                return 3

    rec = measure(paths, stdin_bytes=stdin_bytes, recursive=recursive, weight=weight)
    if label:
        rec["label"] = label

    # The metric the budget verdicts against: cost-units when weighted, else tokens.
    metric = rec["cost_units"] if weight is not None else rec["approx_tokens"]

    verdict = None
    if budget is not None:
        try:
            b = int(budget)
        except ValueError:
            print(f"FAIL: --budget must be an integer count (got {budget})",
                  file=sys.stderr)
            return 3
        verdict = "OVER" if metric > b else "UNDER"
        rec["budget"] = b
        rec["verdict"] = verdict

    if as_json:
        print(json.dumps(rec, ensure_ascii=False))
    else:
        name = label or "seed"
        cu = f"  ={rec['cost_units']} cost-units @{weight}x" if weight is not None else ""
        print(f"{name}: {rec['bytes']} bytes  ~{rec['approx_tokens']} tokens{cu}"
              f"  ({len(rec['components'])} components)")
        for c in rec["components"]:
            print(f"  {c['bytes']:>9} B  ~{c['approx_tokens']:>7} tok  {c['path']}")
        if rec["missing"]:
            print(f"  MISSING (counted as 0): {', '.join(rec['missing'])}")
        if verdict is not None:
            unit = "cost-units" if weight is not None else "tok"
            print(f"  BUDGET {rec['budget']} {unit} -> {verdict}")

    if verdict == "OVER" and enforce:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
