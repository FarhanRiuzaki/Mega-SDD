#!/usr/bin/env bash
# write-unit-binding.sh — SOLE writer of <vault>/bolts/U-XXX/binding.json (v8 P1,
# spec 2026-09-10 Appendix F3). The file is hook-guarded evidence (evidence-deny
# regex, like postflight/acceptance/findings): Write/Edit/Bash writes are denied,
# only this script produces or amends it — so a verdict can never be typed in.
#
#   write-unit-binding.sh --cwd=<root> --vault=<vault> --unit=U-XXX --claims=<wave claims.json> [--verdicts=<json>]
#   write-unit-binding.sh --cwd=<root> --vault=<vault> --unit=U-XXX --resolve=C-U005-01=KEEP_VAULT|KEEP_CODE|SPLIT --by=<who>
#
# Verdicts (fail-closed, never CONFIRMED-by-absence):
#   fs_must_exist      path exists (and line range fits when `:N[-M]`) → CONFIRMED/IMPLEMENTED · else CONFLICT
#                      stale line-range (v8 P3, owner amendment #4 — research/2026-09-15-v8-p3-report.md §5): a range that
#                      no longer fits is REPAIRED only against the anchor's authoring snapshot (the commit that
#                      introduced that anchor token into the unit file) and only when the content is byte-identical:
#                        R1-shift  the authored lines are found verbatim (uniquely) at another offset → range moved
#                        R2-clamp  the file is unchanged since authoring AND the range overshoots EOF by exactly one
#                                  line (the trailing-newline miscount; the live P2 class) → range clamped to EOF
#                      anything else (content changed, no unique match, overshoot > 1, no snapshot) stays CONFLICT.
#                      A repair is recorded on the claim (`repair: {from,to,rule,reference,content_sha256}`) AND the
#                      unit's `## Anchors` line is rewritten to the repaired token (idempotent: the next bind sees it fit).
#   fs_must_not_exist  path absent → CONFIRMED/NEW · else CONFLICT (already exists)
#   symbol             symbol-index lookup: in the expected file → CONFIRMED/IMPLEMENTED (anchor file:line);
#                      only elsewhere → CONFLICT (collision; anchors listed); nowhere → OQ; index absent → OQ (reason)
#   text               OQ until `--verdicts` supplies the model ladder's verdict (express-bind.md §E3);
#                      a supplied CONFIRMED MUST carry an anchor, else the writer REFUSES (exit 3)
# Exit 0 written · 2 usage/input · 3 refused (illegal verdict, CONFIRMED without anchor, resolve on non-CONFLICT).
set -u
CWD="."; VAULT=""; UNIT=""; CLAIMS=""; VERDICTS=""; RESOLVE=""; BY=""
for arg in "$@"; do case "$arg" in
  --cwd=*) CWD="${arg#*=}" ;; --vault=*) VAULT="${arg#*=}" ;; --unit=*) UNIT="${arg#*=}" ;;
  --claims=*) CLAIMS="${arg#*=}" ;; --verdicts=*) VERDICTS="${arg#*=}" ;; --resolve=*) RESOLVE="${arg#*=}" ;; --by=*) BY="${arg#*=}" ;;
  *) echo "usage: write-unit-binding.sh --cwd --vault --unit=U-XXX (--claims=<json> [--verdicts=<json>] | --resolve=C-id=ACTION --by=<who>)" >&2; exit 2 ;;
esac; done
[ -n "$VAULT" ] && [ -d "$VAULT" ] && [ -n "$UNIT" ] || { echo "usage: --vault=<dir> --unit=U-XXX required" >&2; exit 2; }
if [ -z "$RESOLVE" ]; then [ -n "$CLAIMS" ] && [ -f "$CLAIMS" ] || { echo "usage: --claims=<wave claims.json> required (or --resolve)" >&2; exit 2; }; fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HEAD8="$(git -C "$CWD" rev-parse --short=8 HEAD 2>/dev/null || echo nogit)"
V_CWD="$CWD" V_VAULT="$VAULT" V_UNIT="$UNIT" V_CLAIMS="$CLAIMS" V_VERDICTS="$VERDICTS" V_RESOLVE="$RESOLVE" V_BY="$BY" V_HEAD="$HEAD8" V_LIB="$SCRIPT_DIR/_lib" python3 <<'PYEOF'
import hashlib, json, os, re, subprocess, sys
from datetime import datetime, timezone
E = os.environ; cwd = os.path.abspath(E["V_CWD"]); vault = E["V_VAULT"]; unit = E["V_UNIT"]
sys.path.insert(0, E["V_LIB"])
try:
    from plugin_meta import plugin_version as _pv
    GEN = "write-unit-binding.sh@%s" % _pv()
except Exception:
    GEN = "write-unit-binding.sh"
ENUM = ("CONFIRMED", "CONFLICT", "OQ")
out_dir = os.path.join(vault, "bolts", unit); out = os.path.join(out_dir, "binding.json")

def refuse(msg):
    print("REFUSE: %s" % msg, file=sys.stderr); sys.exit(3)

def write(doc):
    os.makedirs(out_dir, exist_ok=True)
    tmp = out + ".tmp.%d" % os.getpid()
    with open(tmp, "w", encoding="utf-8") as f: json.dump(doc, f, indent=1, ensure_ascii=False)
    os.replace(tmp, out)

# ── resolve mode (resolve-oq --binding write-back) ────────────────────────────
if E["V_RESOLVE"]:
    m = re.match(r"^(C-[\w-]+)=(KEEP_VAULT|KEEP_CODE|SPLIT)$", E["V_RESOLVE"])
    if not m: refuse("--resolve must be C-id=KEEP_VAULT|KEEP_CODE|SPLIT")
    if not E["V_BY"]: refuse("--by=<who> required for a resolution")
    if not os.path.isfile(out): refuse("no binding.json for %s yet" % unit)
    doc = json.load(open(out, encoding="utf-8"))
    hit = [c for c in doc["claims"] if c["id"] == m.group(1)]
    if not hit: refuse("claim %s not in %s" % (m.group(1), out))
    if hit[0]["verdict"] != "CONFLICT": refuse("claim %s is %s, not CONFLICT — nothing to resolve" % (m.group(1), hit[0]["verdict"]))
    hit[0]["resolution"] = {"action": m.group(2), "by": E["V_BY"], "at": datetime.now(timezone.utc).isoformat(timespec="seconds")}
    doc["updated_at"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    write(doc)
    print(json.dumps({"unit": unit, "resolved": m.group(1), "action": m.group(2), "out": os.path.relpath(out, cwd)})); sys.exit(0)

# ── verdict mode ──────────────────────────────────────────────────────────────
wave = json.load(open(E["V_CLAIMS"], encoding="utf-8"))
mine = [c for c in wave.get("claims", []) if c.get("unit") == unit]
supplied = json.load(open(E["V_VERDICTS"], encoding="utf-8")) if E["V_VERDICTS"] else {}
idx_path = os.path.join(cwd, ".mega-sdd", "codebase", "symbol-index.json")
index = None
if os.path.isfile(idx_path):
    try: index = json.load(open(idx_path, encoding="utf-8")).get("symbols", [])
    except Exception: index = None

def _git(*args):
    try:
        r = subprocess.run(["git", "-C", cwd] + list(args), capture_output=True, text=True, timeout=30)
        return r.stdout if r.returncode == 0 else None
    except Exception:
        return None

def _read_lines(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f: return f.read().splitlines()
    except OSError:
        return None

def _sha(lines):
    return hashlib.sha256("\n".join(lines).encode("utf-8", "replace")).hexdigest()[:12]

def anchor_snapshot(unit_rel, token):
    """The commit that INTRODUCED `token` into the unit file — the anchor's authoring snapshot:
    walk the unit's commits newest→oldest while the token is present; the oldest of that run
    introduced it. None = the token exists only in the working tree (authored against the
    CURRENT files, so the current file IS the snapshot)."""
    log = _git("log", "--format=%H", "--", unit_rel)
    if log is None: return None
    intro = None
    for sha in log.split():
        content = _git("show", "%s:%s" % (sha, unit_rel))
        if content is None or token not in content: break
        intro = sha
    return intro

def _lines_at(sha, rel):
    if sha is None: return _read_lines(os.path.join(cwd, rel))
    txt = _git("show", "%s:%s" % (sha, rel))
    return txt.splitlines() if txt is not None else None

def fs_exists(expect, source=""):
    """(ok, why, repair) — repair is set ONLY when a stale range was moved to content-identical
    lines (v8 P3 amendment #4: sha match or nothing; changed content stays CONFLICT)."""
    m = re.match(r"^(.+?):(\d+)(?:-(\d+))?$", expect)
    path = os.path.join(cwd, m.group(1) if m else expect)
    if not os.path.exists(path): return False, "absent", None
    if not (m and os.path.isfile(path)): return True, "present", None
    rel, lo, hi = m.group(1), int(m.group(2)), int(m.group(3) or m.group(2))
    cur = _read_lines(path) or []; n = len(cur)
    if hi <= n: return True, "present", None
    # ── stale line-range: repair only against the authoring snapshot, content-identical ──
    unit_rel = (source or "").split(":")[0]
    if not (source or "").endswith("## Anchors") or not unit_rel or not os.path.isfile(os.path.join(cwd, unit_rel)):
        return False, "line %d beyond EOF (%d lines)" % (hi, n), None
    snap = anchor_snapshot(unit_rel, expect)
    ref = _lines_at(snap, rel)
    if ref is None:
        return False, "line %d beyond EOF (%d lines); no authoring snapshot of %s — not repairable" % (hi, n, rel), None
    ref_sha = (snap or "worktree")[:8]
    if hi <= len(ref):
        # R1 — shift: the authored block exists verbatim, uniquely, at another offset
        block = ref[lo - 1:hi]; L = len(block)
        hits = [i for i in range(0, max(0, n - L + 1)) if cur[i:i + L] == block]
        if len(hits) == 1:
            s = hits[0] + 1
            to = "%s:%d%s" % (rel, s, ("-%d" % (s + L - 1)) if m.group(3) else "")
            return True, "repaired: authored lines %d-%d found verbatim at %d-%d (content sha %s, snapshot %s)" % (lo, hi, s, s + L - 1, _sha(block), ref_sha), \
                   {"from": expect, "to": to, "rule": "R1-shift", "reference": ref_sha, "content_sha256": _sha(block)}
        return False, "line %d beyond EOF (%d lines); authored content not found verbatim (%d match(es)) — not repairable" % (hi, n, len(hits)), None
    if cur == ref and lo <= n and (hi == n + 1 or lo == 1):
        # R2 — clamp: file byte-identical to the snapshot AND either an overshoot of exactly one
        # line (the trailing-newline miscount, P2 class) OR a WHOLE-FILE anchor (lo == 1): lines
        # past EOF never existed, so lines 1..n ARE the content the author read — hash-identical
        # by construction (8.0.1, xs lite 8.0.0 run: 4/5 units hit `login/page.tsx:1-25` on an
        # unchanged 22-line file → 4 false CONFLICTs, all KEEP_CODE with zero code change).
        # A partial range overshooting by >1 (e.g. 30-45 on 40 lines) stays CONFLICT: the
        # intended block is ambiguous.
        to = ("%s:%d-%d" % (rel, lo, n)) if m.group(3) else ("%s:%d" % (rel, n))
        why = "range overshot EOF by 1" if hi == n + 1 else "whole-file range overshot EOF by %d" % (hi - n)
        return True, "repaired: file unchanged since authoring (content sha %s, snapshot %s), %s — clamped to %s" % (_sha(cur), ref_sha, why, to.split(":")[1]), \
               {"from": expect, "to": to, "rule": "R2-clamp", "reference": ref_sha, "content_sha256": _sha(cur)}
    return False, "line %d beyond EOF (%d lines); content differs from the authoring snapshot, or a partial range overshoots by > 1 — not repairable" % (hi, n), None

def norm(p): return p.replace("\\", "/").lstrip("./")

verdicts = []; repairs = []
for c in mine:
    v = {"id": c["id"], "kind": c["kind"], "expect": c["expect"], "source": c["source"],
         "verdict": None, "state": None, "anchor": None, "confidence": None, "evidence": None}
    if c.get("text"): v["text"] = c["text"]
    k = c["kind"]
    if k == "fs_must_exist":
        ok, why, rep = fs_exists(c["expect"], c.get("source", ""))
        v.update(verdict="CONFIRMED" if ok else "CONFLICT", state="IMPLEMENTED" if ok else "MISSING",
                 anchor=(rep["to"] if rep else c["expect"]) if ok else None, confidence="high", evidence="fs: %s" % why)
        if rep:
            v["repair"] = rep; repairs.append((c.get("source", ""), rep))
    elif k == "fs_must_not_exist":
        ok, why, _ = fs_exists(c["expect"])
        v.update(verdict="CONFLICT" if ok else "CONFIRMED", state="ALREADY_EXISTS" if ok else "NEW",
                 anchor=c["expect"] if ok else None, confidence="high", evidence="fs: %s" % why)
    elif k == "symbol":
        f, sym = c["expect"].rsplit(":", 1)
        if index is None:
            v.update(verdict="OQ", state="UNKNOWN", confidence="low", evidence="symbol-index.json absent — run scripts/build-symbol-index.sh")
        else:
            hits = [s for s in index if s.get("name") == sym]
            here = [s for s in hits if norm(s.get("file", "")).endswith(norm(f))]
            if here:
                v.update(verdict="CONFIRMED", state="IMPLEMENTED", anchor="%s:%s" % (here[0]["file"], here[0].get("line", "?")),
                         confidence="high", evidence="index: %d hit(s) in expected file" % len(here))
            elif hits:
                v.update(verdict="CONFLICT", state="COLLISION", anchor=" + ".join("%s:%s" % (s["file"], s.get("line", "?")) for s in hits[:5]),
                         confidence="high", evidence="index: symbol lives elsewhere (%d hit(s)), not in %s" % (len(hits), f))
            else:
                v.update(verdict="OQ", state="UNKNOWN", confidence="medium", evidence="index: symbol not found anywhere")
    else:  # text — model ladder result, or OQ
        s = supplied.get(c["id"])
        if s:
            if s.get("verdict") not in ENUM: refuse("claim %s: verdict %r not in %s" % (c["id"], s.get("verdict"), ENUM))
            if s["verdict"] == "CONFIRMED" and not s.get("anchor"): refuse("claim %s: CONFIRMED without an anchor is CONFIRMED-by-absence" % c["id"])
            v.update(verdict=s["verdict"], state=s.get("state") or ("IMPLEMENTED" if s["verdict"] == "CONFIRMED" else "UNKNOWN"),
                     anchor=s.get("anchor"), confidence=s.get("confidence") or "medium", evidence=s.get("evidence") or "model ladder (express-bind §E3)")
        else:
            v.update(verdict="OQ", state="UNKNOWN", confidence="low", evidence="text claim: awaiting ladder E3 verdict (--verdicts)")
    verdicts.append(v)

doc = {"schema": "unit-binding/1", "generated_by": GEN, "head": E["V_HEAD"], "unit": unit,
       "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
       "summary": {k: sum(1 for x in verdicts if x["verdict"] == k) for k in ENUM}, "claims": verdicts}
if repairs:
    doc["repairs"] = [dict(r, source=src) for src, r in repairs]
    # rewrite the repaired token in the unit's `## Anchors` section ONLY (first exact occurrence;
    # a following digit or dash is not part of the token), atomically — the next bind sees it fit.
    by_unit = {}
    for src, r in repairs: by_unit.setdefault(src.split(":")[0], []).append(r)
    for unit_rel, reps in by_unit.items():
        up = os.path.join(cwd, unit_rel)
        try: txt = open(up, encoding="utf-8").read()
        except OSError: continue
        sec = re.search(r"(?ims)^##[ \t]+Anchors\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)", txt)
        if not sec: continue
        body = sec.group(1); new_body = body
        for r in reps:
            new_body = re.sub(re.escape(r["from"]) + r"(?![\w-])", r["to"].replace("\\", "\\\\"), new_body, count=1)
        if new_body != body:
            tmpu = up + ".tmp.%d" % os.getpid()
            with open(tmpu, "w", encoding="utf-8") as f: f.write(txt[:sec.start(1)] + new_body + txt[sec.end(1):])
            os.replace(tmpu, up)
write(doc)
print(json.dumps({"unit": unit, "claims": len(verdicts), **doc["summary"], "repaired": len(repairs),
                  "repairs": [{"from": r["from"], "to": r["to"], "rule": r["rule"]} for _, r in repairs],
                  "out": os.path.relpath(out, cwd)}))
PYEOF
