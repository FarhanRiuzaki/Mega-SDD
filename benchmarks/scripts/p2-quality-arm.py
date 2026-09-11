#!/usr/bin/env python3
"""p2-quality-arm.py — deterministic QUALITY extraction of one measurement arm
(v8 P2, 2026-09-11). Companion of p0-extract-arm.sh (which measures WALL). Reads
ONLY the evidence files the pipeline wrote under the arm's vault — never the
model's prose — so the same arm always yields the same numbers:

  units/U-*.md                        unit universe
  bolts/U-*/bolt-report.md            status / retries (frontmatter)
  bolts/U-*/acceptance.json           executed entries: pass / fail / pending_manual
  bolts/U-*/postflight.json           hard-rule post-flight verdict
  bolts/U-*/findings.json             panel findings by severity + open/advisory/resolved
  bolts/U-*/quarantine.json           W1 quarantine (halt_type)
  bolts/U-*/binding.json              JIT bind at dispatch: CONFIRMED / CONFLICT / OQ per unit
  vault.json open_questions           OQ by priority × status
  <results-dir>/stream.jsonl (opt)    total_cost_usd / num_turns of the run's own session

conflict-at-dispatch = units whose JIT binding.json carries ≥1 CONFLICT claim
/ units that have a binding.json (the P0 baseline definition: 3/21 = 14.3 %).

usage: p2-quality-arm.py <arm-dir> [--results <results-dir>] [--json <out.json>]
Validated 2026-09-11 against the P0 clinic baseline arm (TRAINING/p0-clinic-arm2):
acceptance 21/21, Critical 5 / Important 46 / Minor 91, conflict-at-dispatch 3/21.
"""
import argparse, glob, json, os, re, sys

def frontmatter(path):
    try: txt = open(path, encoding="utf-8").read()
    except OSError: return {}
    m = re.match(r"^---\n(.*?)\n---", txt, re.S)
    fm = {}
    if m:
        for line in m.group(1).splitlines():
            mm = re.match(r"^([A-Za-z_]+):\s*(.*)$", line)
            if mm: fm[mm.group(1)] = mm.group(2).strip()
    return fm

def load(path):
    try: return json.load(open(path, encoding="utf-8"))
    except (OSError, ValueError): return None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("arm"); ap.add_argument("--results"); ap.add_argument("--json")
    a = ap.parse_args()
    vaults = sorted(glob.glob(os.path.join(a.arm, ".mega-sdd", "vaults", "*", "")))
    vaults = [v for v in vaults if os.path.isdir(os.path.join(v, "units"))]
    if not vaults: print("no vault with units/ under", a.arm, file=sys.stderr); sys.exit(2)
    V = vaults[0].rstrip("/")
    units = sorted(os.path.basename(p)[:-3] for p in glob.glob(os.path.join(V, "units", "U-*.md")))
    out = {"arm": a.arm, "vault": os.path.relpath(V, a.arm), "units_total": len(units), "units": {}}
    sev = {"Critical": 0, "Important": 0, "Minor": 0}; fstat = {}
    acc_units_pass = acc_units_present = 0; acc_entries = {"executed": 0, "passed": 0, "failed": 0, "pending_manual": 0}
    post_pass = post_present = 0; done = quarantined = 0; retries = 0; halts = {}
    jit_present = jit_conflict_units = 0; claims = {"CONFIRMED": 0, "CONFLICT": 0, "OQ": 0}
    for u in units:
        B = os.path.join(V, "bolts", u); row = {}
        fm = frontmatter(os.path.join(B, "bolt-report.md"))
        row["status"] = fm.get("status"); row["retries"] = int(fm.get("retries") or 0) if fm.get("retries", "0").isdigit() else fm.get("retries")
        if isinstance(row["retries"], int): retries += row["retries"]
        q = load(os.path.join(B, "quarantine.json"))
        if q: quarantined += 1; row["quarantine"] = q.get("halt_type"); halts[q.get("halt_type")] = halts.get(q.get("halt_type"), 0) + 1
        elif row["status"] == "success": done += 1
        acc = load(os.path.join(B, "acceptance.json"))
        if acc:
            acc_units_present += 1; row["acceptance"] = acc.get("status")
            if acc.get("status") == "pass": acc_units_pass += 1
            for e in acc.get("entries", []):
                if e.get("expects") == "pending_manual" or e.get("type") == "manual": acc_entries["pending_manual"] += 1; continue
                acc_entries["executed"] += 1
                if e.get("pass"): acc_entries["passed"] += 1
                else: acc_entries["failed"] += 1
        post = load(os.path.join(B, "postflight.json"))
        if post:
            post_present += 1; row["postflight"] = post.get("status")
            if post.get("status") == "pass": post_pass += 1
        f = load(os.path.join(B, "findings.json"))
        if f:
            row["findings"] = {}
            for fi in f.get("findings", []):
                s = fi.get("severity"); sev[s] = sev.get(s, 0) + 1; row["findings"][s] = row["findings"].get(s, 0) + 1
                st = fi.get("status"); fstat[st] = fstat.get(st, 0) + 1
            row["spec_verdict"] = f.get("spec_verdict"); row["panel_attempt"] = f.get("attempt")
        b = load(os.path.join(B, "binding.json"))
        if b:
            jit_present += 1; sm = b.get("summary") or {}
            if not sm:
                for c in b.get("claims", []): sm[c.get("verdict")] = sm.get(c.get("verdict"), 0) + 1
            row["jit"] = sm
            for k in claims: claims[k] += int(sm.get(k, 0))
            if int(sm.get("CONFLICT", 0)) > 0: jit_conflict_units += 1
        out["units"][u] = row
    oq = {}; vj = load(os.path.join(V, "vault.json")) or {}
    for q in vj.get("open_questions", []) or []:
        k = f'{q.get("priority")}/{q.get("status")}'; oq[k] = oq.get(k, 0) + 1
    out.update({
        "done": done, "quarantined": quarantined, "halts": halts, "fix_rounds_total(retries)": retries,
        "acceptance_units": f"{acc_units_pass}/{acc_units_present}", "acceptance_entries": acc_entries,
        "postflight_units": f"{post_pass}/{post_present}",
        "panel_findings": sev, "panel_findings_status": fstat,
        "jit_units": jit_present, "jit_conflict_units": jit_conflict_units,
        "conflict_at_dispatch": (round(100.0 * jit_conflict_units / jit_present, 1) if jit_present else None),
        "jit_claims": claims, "oq": oq, "oq_total": sum(oq.values()),
    })
    if a.results:
        meta = {}
        try:
            for line in open(os.path.join(a.results, "run.meta")):
                if "=" in line: k, v = line.rstrip("\n").split("=", 1); meta[k] = v
        except OSError: pass
        sid = meta.get("sid"); res = None
        try:
            for line in open(os.path.join(a.results, "stream.jsonl")):
                if '"type":"result"' not in line: continue
                try: e = json.loads(line)
                except ValueError: continue
                if e.get("type") == "result" and (not sid or e.get("session_id") == sid): res = e
        except OSError: pass
        out["run"] = {"sid": sid, "plugin": meta.get("plugin"), "flags": meta.get("flags"),
                      "total_cost_usd": res.get("total_cost_usd") if res else None,
                      "num_turns": res.get("num_turns") if res else None,
                      "result_subtype": res.get("subtype") if res else None,
                      "unit_commits": meta.get("unit_commits"), "first_unit_commit": meta.get("first_unit_commit_iso"), "last_unit_commit": meta.get("last_unit_commit_iso")}
    # text
    print(f"arm={a.arm}  vault={out['vault']}")
    print(f"units {out['units_total']}: done {done} · quarantined {quarantined} {halts if halts else ''} · fix rounds (retries) {retries}")
    print(f"acceptance units {out['acceptance_units']} · entries executed {acc_entries['executed']} (passed {acc_entries['passed']}, failed {acc_entries['failed']}) · pending_manual {acc_entries['pending_manual']}")
    print(f"postflight units {out['postflight_units']}")
    print(f"panel findings Critical {sev.get('Critical',0)} / Important {sev.get('Important',0)} / Minor {sev.get('Minor',0)} · by status {fstat}")
    print(f"JIT bind: {jit_present}/{len(units)} units · claims {claims} · conflict-at-dispatch {jit_conflict_units}/{jit_present} = {out['conflict_at_dispatch']} %")
    print(f"OQ {out['oq_total']}: {oq}")
    if a.results: print(f"run: {out['run']}")
    for u, r in out["units"].items():
        print(f"  {u}: status={r.get('status')} acc={r.get('acceptance')} post={r.get('postflight')} retries={r.get('retries')} findings={r.get('findings')} jit={r.get('jit')}" + (f" QUARANTINE={r['quarantine']}" if r.get('quarantine') else ""))
    if a.json:
        json.dump(out, open(a.json, "w"), indent=1, ensure_ascii=False); print("json written:", a.json)

if __name__ == "__main__": main()
