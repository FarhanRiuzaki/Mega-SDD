#!/usr/bin/env python3
"""p3-ship-verdict.py — mechanical 8.0.0 ship-criteria reader (runbook §3 + owner §3-lanjutan).

  python3 benchmarks/scripts/p3-ship-verdict.py --xs <results-dir> --clinic <results-dir> \
      [--classic-xs "5/5 0/7/20"] [--classic-clinic "21/21 5/46/91"] [--json out.json]

Reads, per arm: run.meta (clean-run proof: zero resume_* / outage_* keys), done-endpoints.txt
(DONE = max(DONE_gate, B2)), parallelism.txt (mean implementers in flight + share of bolt-stage
time with 0 implementers running), quality.json (acceptance, postflight, panel Critical /
Important / Minor, quarantine, retries), stream.jsonl (cost = Σ total_cost_usd over `result`
events, every process of the session). Criteria (owner-revised, 2026-09-15):
  (a) xs DONE ≤ 60 m                                            — xs only
  (b) clinic mean in-flight ≥ 2.5 (cap 4) AND idle-without-implementer < 20 %,
      with acceptance all pass and panel Critical 0              — clinic only (never read from xs)
  (ii) acceptance rate + P1 findings (Critical + Important) ≤ classic arm
  clean: run.meta carries no resume_*/outage_* keys (0 outage, 0 resume in the measured phase)
Verdict: --lite DEFAULT only if (a) AND (b) hold on CLEAN runs; otherwise opt-in — with the
reason "measurement environment unfit" when the failing arm is not clean, "criterion failed"
when it is. Nothing here is an estimate; a missing file makes the criterion UNREADABLE (never
PASS by absence).
"""
import json, os, re, sys


def hms_to_min(s):
    m = re.match(r"(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$", s.strip())
    if not m:
        return None
    h, mi, se = (int(x) if x else 0 for x in m.groups())
    return h * 60 + mi + se / 60.0


def read_meta(d):
    meta = {}
    p = os.path.join(d, "run.meta")
    if not os.path.isfile(p):
        return None
    for ln in open(p, encoding="utf-8", errors="replace"):
        if "=" in ln:
            k, v = ln.rstrip("\n").split("=", 1)
            meta[k] = v
    return meta


def read_done(d):
    p = os.path.join(d, "done-endpoints.txt")
    if not os.path.isfile(p):
        return None
    out = {}
    for ln in open(p, encoding="utf-8", errors="replace"):
        m = re.match(r"\s*(DONE_code|DONE_p5|DONE_gate|B2 suite|EXCLUDED)\s+(\d+h\d+m\d+s|\d+m\d+s|—|-)\s", ln)
        if m:
            out[m.group(1).replace(" suite", "")] = hms_to_min(m.group(2)) if m.group(2)[0].isdigit() else None
    if "DONE_gate" not in out:
        return None
    cands = [v for v in (out.get("DONE_gate"), out.get("B2")) if v is not None]
    out["DONE"] = max(cands) if cands else None
    return out


def read_par(d):
    p = os.path.join(d, "parallelism.txt")
    if not os.path.isfile(p):
        return None
    out = {}
    txt = open(p, encoding="utf-8", errors="replace").read()
    m = re.search(r"mean implementers in flight = ([\d.]+); implementer-minutes = ([\d.]+)", txt)
    if m:
        out["mean_inflight"] = float(m.group(1)); out["impl_minutes"] = float(m.group(2))
    m = re.search(r"implementers running\s*:\s*0:\s*([\d.]+) m \((\d+) %\)", txt)
    if m:
        out["idle0_min"] = float(m.group(1)); out["idle0_pct"] = int(m.group(2))
    m = re.search(r"time-weighted over ([\d.]+) net min", txt)
    if m:
        out["window_min"] = float(m.group(1))
    m = re.search(r"bolt-stage: first dispatch (\S+) · last code commit (\S+) \(([\d.]+) m gross\)", txt)
    if m:
        out["bolt_stage_to_last_code_min"] = float(m.group(3))
    return out if "mean_inflight" in out else None


def read_quality(d):
    p = os.path.join(d, "quality.json")
    if not os.path.isfile(p):
        return None
    q = json.load(open(p, encoding="utf-8"))
    pf = q.get("panel_findings") or {}
    return {"acceptance_units": q.get("acceptance_units"), "postflight_units": q.get("postflight_units"),
            "critical": int(pf.get("Critical", 0) or 0), "important": int(pf.get("Important", 0) or 0),
            "minor": int(pf.get("Minor", 0) or 0), "quarantined": q.get("quarantined"),
            "retries": q.get("fix_rounds_total(retries)"), "done": q.get("done"), "units_total": q.get("units_total"),
            "jit": q.get("jit_totals") or q.get("jit")}


def read_cost(d):
    p = os.path.join(d, "stream.jsonl")
    if not os.path.isfile(p):
        return None
    # P2 rule (clinic 7.37.1 lesson): a resumed `claude -p --resume` process re-reports the
    # session's cumulative figure (identical value on consecutive `result` events), so a
    # straight Σ double-counts — consecutive identical values are counted ONCE, zeros ignored.
    tot = 0.0; n = 0; prev = None; distinct = []
    for line in open(p, encoding="utf-8", errors="replace"):
        if '"type":"result"' not in line and '"type": "result"' not in line:
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if ev.get("type") == "result" and ev.get("total_cost_usd") is not None:
            n += 1
            v = round(float(ev["total_cost_usd"]), 6)
            if v > 0 and v != prev:
                tot += v; distinct.append(v)
            prev = v
    return {"usd": round(tot, 2), "result_events": n, "distinct_values": distinct}


def frac_ok(s):  # "21/21" → True
    m = re.match(r"(\d+)/(\d+)$", s or "")
    return bool(m) and m.group(1) == m.group(2) and int(m.group(2)) > 0


def parse_classic(s):  # "21/21 5/46/91"
    if not s:
        return None
    acc, pan = s.split()
    c, i, mi = (int(x) for x in pan.split("/"))
    return {"acceptance_units": acc, "critical": c, "important": i, "minor": mi}


def arm_report(name, d, classic):
    r = {"arm": name, "dir": d}
    meta = read_meta(d)
    r["meta_present"] = meta is not None
    dirty = sorted(k for k in (meta or {}) if re.match(r"(resume_\d+|outage_\d+)", k))
    r["clean"] = (meta is not None) and not dirty
    r["dirty_keys"] = dirty
    r["ended"] = (meta or {}).get("ended_at")
    r["done"] = read_done(d)
    r["par"] = read_par(d)
    r["quality"] = read_quality(d)
    r["cost"] = read_cost(d)
    q = r["quality"]
    if q and classic:
        # (ii) "acceptance pass rate + P1 findings ≤ arm classic" — two readings reported side by
        # side, never collapsed: STRICT = the P2 precedent (Critical AND Important each ≤ classic,
        # research/2026-09-11-v8-p2-report.md §5 verdict 1); CRITICAL = Critical only (the owner's
        # (b) quality bar names "Critical 0"). The verdict line prints both; the report says which.
        r["ii"] = {"acceptance_ok": frac_ok(q["acceptance_units"]),
                   "critical_ok": q["critical"] <= classic["critical"],
                   "important_ok": q["important"] <= classic["important"],
                   "classic": classic}
        r["ii"]["pass_strict"] = r["ii"]["acceptance_ok"] and r["ii"]["critical_ok"] and r["ii"]["important_ok"]
        r["ii"]["pass_critical_only"] = r["ii"]["acceptance_ok"] and r["ii"]["critical_ok"]
        r["ii"]["pass"] = r["ii"]["pass_strict"]
    else:
        r["ii"] = None
    return r


def main():
    a = sys.argv[1:]
    def opt(k, default=None):
        return a[a.index(k) + 1] if k in a else default
    xs_d, cl_d = opt("--xs"), opt("--clinic")
    out = opt("--json")
    cx = parse_classic(opt("--classic-xs", "5/5 0/7/20"))
    cc = parse_classic(opt("--classic-clinic", "21/21 5/46/91"))
    rep = {"criteria": {}}
    xs = arm_report("xs", xs_d, cx) if xs_d else None
    cl = arm_report("clinic", cl_d, cc) if cl_d else None
    rep["xs"], rep["clinic"] = xs, cl
    # (a)
    if xs and xs["done"] and xs["done"]["DONE"] is not None:
        rep["criteria"]["a"] = {"value_min": round(xs["done"]["DONE"], 2), "threshold_min": 60,
                                "pass": xs["done"]["DONE"] <= 60, "clean": xs["clean"], "readable": True}
    else:
        rep["criteria"]["a"] = {"readable": False, "pass": None, "clean": xs["clean"] if xs else None}
    # (b) — clinic only
    if cl and cl["par"] and cl["quality"]:
        p, q = cl["par"], cl["quality"]
        b = {"mean_inflight": p["mean_inflight"], "idle0_pct": p.get("idle0_pct"),
             "acceptance_units": q["acceptance_units"], "critical": q["critical"], "clean": cl["clean"], "readable": True}
        b["pass"] = (p["mean_inflight"] >= 2.5 and p.get("idle0_pct") is not None and p["idle0_pct"] < 20
                     and frac_ok(q["acceptance_units"]) and q["critical"] == 0)
        rep["criteria"]["b"] = b
    else:
        rep["criteria"]["b"] = {"readable": False, "pass": None, "clean": cl["clean"] if cl else None}
    # (ii)
    rep["criteria"]["ii"] = {"xs": xs["ii"] if xs else None, "clinic": cl["ii"] if cl else None}
    A, B = rep["criteria"]["a"], rep["criteria"]["b"]
    both_pass = bool(A.get("pass")) and bool(B.get("pass"))
    both_clean = bool(A.get("clean")) and bool(B.get("clean"))
    if both_pass and both_clean:
        verdict = "--lite DEFAULT (a AND b PASS on clean runs)"
    elif not A.get("readable") or not B.get("readable"):
        verdict = "UNREADABLE — a criterion has no data yet (never pass by absence)"
    else:
        why = []
        if not A.get("pass"):
            why.append("(a) xs DONE %.1f m > 60 m" % A["value_min"] if A.get("value_min") is not None else "(a) unreadable")
        if not B.get("pass"):
            why.append("(b) clinic in-flight %.2f / idle %s %% / acceptance %s / Critical %s" %
                       (B["mean_inflight"], B.get("idle0_pct"), B["acceptance_units"], B["critical"]))
        if not both_clean:
            why.append("dirty run(s): xs=%s clinic=%s → 'measurement environment unfit', NOT 'feature failed'" %
                       (xs["dirty_keys"] if xs else "n/a", cl["dirty_keys"] if cl else "n/a"))
        verdict = "--lite OPT-IN — " + "; ".join(why)
    rep["verdict"] = verdict
    # text
    for r in (xs, cl):
        if not r:
            continue
        print("%-7s dir=%s clean=%s%s ended=%s" % (r["arm"], r["dir"], r["clean"],
              (" dirty=" + ",".join(r["dirty_keys"])) if r["dirty_keys"] else "", r["ended"]))
        if r["done"]:
            print("        DONE=max(gate %.1f m, B2 %s) = %.1f m · DONE_code %s m" %
                  (r["done"]["DONE_gate"] or -1, ("%.1f m" % r["done"]["B2"]) if r["done"].get("B2") is not None else "—",
                   r["done"]["DONE"], ("%.1f" % r["done"]["DONE_code"]) if r["done"].get("DONE_code") is not None else "—"))
        if r["par"]:
            print("        in-flight mean %.2f · idle(0 impl) %s %% of %s m · bolt-stage→last code %s m" %
                  (r["par"]["mean_inflight"], r["par"].get("idle0_pct"), r["par"].get("window_min"), r["par"].get("bolt_stage_to_last_code_min")))
        if r["quality"]:
            q = r["quality"]
            print("        acceptance %s · postflight %s · panel C/I/M %d/%d/%d · retries %s · quarantined %s" %
                  (q["acceptance_units"], q["postflight_units"], q["critical"], q["important"], q["minor"], q["retries"], q["quarantined"]))
        if r["cost"]:
            print("        cost $%.2f over %d result event(s)" % (r["cost"]["usd"], r["cost"]["result_events"]))
        if r["ii"]:
            print("        (ii) vs classic %s %d/%d/%d → STRICT (Critical AND Important ≤) %s · CRITICAL-only %s" % (
                  r["ii"]["classic"]["acceptance_units"], r["ii"]["classic"]["critical"], r["ii"]["classic"]["important"],
                  r["ii"]["classic"]["minor"], "PASS" if r["ii"]["pass_strict"] else "FAIL", "PASS" if r["ii"]["pass_critical_only"] else "FAIL"))
    print("(a) %s" % A); print("(b) %s" % B); print("VERDICT: %s" % verdict)
    if out:
        json.dump(rep, open(out, "w"), indent=1)


if __name__ == "__main__":
    main()
