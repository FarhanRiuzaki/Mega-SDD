"""unit_binding.py — the body of write-unit-binding.sh, the SOLE writer of
<vault>/bolts/U-XXX/binding.json (v8 P1, spec 2026-09-10 Appendix F3), schema
`unit-binding/2` since the state anchor (spec 2026-09-25-state-anchor-design.md
§3, §9). The file is hook-guarded evidence: Write/Edit/Bash writes are denied,
only this module produces or amends it — so a verdict can never be typed in.

Verdicts (fail-closed, never CONFIRMED-by-absence):
  fs_must_exist      path exists (and the line range fits) → CONFIRMED · else CONFLICT
                     stale range (overshoots EOF): R1-shift / R2-clamp repair against the
                     anchor's authoring snapshot, content-identical only (v8 P3 #4)
                     in-range `## Anchors` (the §9 content ladder, D22):
                       1 block identical to the reference          → CONFIRMED
                       2 reference block found verbatim elsewhere  → R1-shift CONFIRMED (repair)
                       3 changed only by this unit's own commits   → CONFIRMED IMPLEMENTED_BY_UNIT
                       4 changed, label token still in range       → CONFIRMED + anchor_changed
                       5 otherwise                                 → CONFLICT anchor_content_drift
  fs_must_not_exist  path absent → CONFIRMED/NEW (absent_at = HEAD) · present → CONFIRMED
                     IMPLEMENTED_BY_UNIT when only this unit's own commits created it since
                     absent_at (inductive, §9) · else CONFLICT (already exists)
  symbol             symbol-index lookup (CONFIRMED / CONFLICT collision / OQ)
  text               OQ until `--verdicts` supplies the E3 ladder verdict

The honest stamp (§3): `based_on_sha` = the OLDEST SHA among the evidence behind
the verdicts, or null with a `null_cause` (evidence_off_line, index_stale,
dirty_index, writer_capture_moved, capture_unavailable, no_git). A git error
while a `.git` exists makes the writer REFUSE (exit 3, nothing written).
Exit 0 written · 2 usage/input · 3 refused.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone

LIB = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, LIB)
import bolt_attrib  # noqa: E402
import freshness as fr  # noqa: E402
import unit_claims  # noqa: E402
import vault_layouts  # noqa: E402
import vault_scope as vs  # noqa: E402

ENUM = ("CONFIRMED", "CONFLICT", "OQ")
E = os.environ
cwd = os.path.abspath(E["V_CWD"])
vault = E["V_VAULT"]
unit = E["V_UNIT"]
try:
    from plugin_meta import plugin_version as _pv
    GEN = "write-unit-binding.sh@%s" % _pv()
except Exception:
    GEN = "write-unit-binding.sh"
out_dir = os.path.join(vault, "bolts", unit)
out = os.path.join(out_dir, "binding.json")
NOW = datetime.now(timezone.utc).isoformat(timespec="seconds")


def refuse(msg):
    print("REFUSE: %s" % msg, file=sys.stderr)
    sys.exit(3)


def write(doc):
    os.makedirs(out_dir, exist_ok=True)
    tmp = out + ".tmp.%d" % os.getpid()
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=1, ensure_ascii=False)
    os.replace(tmp, out)


def drop_view_cache(g):
    """The view is derived from bindings: a new binding invalidates it (the Stop
    bootstrap / next GROUND recomputes). Correctness never depends on this — the
    SessionStart reader already treats a binding newer than the cache as a miss."""
    if not g:
        return
    for suf in ("", ".scope", ".overlay"):
        try:
            os.remove(os.path.join(g["gitdir"], fr.CACHE_NAME + suf))
        except OSError:
            pass


def load_prior():
    if not os.path.isfile(out):
        return None
    try:
        d = json.load(open(out, encoding="utf-8"))
        return d if isinstance(d, dict) else None
    except (OSError, ValueError):
        return None


prior = load_prior()
g = fr.find_git(cwd)

# ── resolve mode (resolve-oq --binding write-back) ──────────────────────────────
if E.get("V_RESOLVE"):
    # DEFER = binding-mode [D] on the lite lane (doc-audit v8 finding #11): the CONFLICT is
    # downgraded to an OQ the unit carries; a resolved claim no longer counts as open at the
    # gate (validate-handoff-binding-units: open = CONFLICT without `resolution`).
    # A resolution records a human decision only: based_on_sha and dirty stay unchanged.
    m = re.match(r"^(C-[\w-]+)=(KEEP_VAULT|KEEP_CODE|SPLIT|DEFER)$", E["V_RESOLVE"])
    if not m:
        refuse("--resolve must be C-id=KEEP_VAULT|KEEP_CODE|SPLIT|DEFER")
    if not E.get("V_BY"):
        refuse("--by=<who> required for a resolution")
    if prior is None:
        refuse("no binding.json for %s yet" % unit)
    hit = [c for c in prior.get("claims", []) if c.get("id") == m.group(1)]
    if not hit:
        refuse("claim %s not in %s" % (m.group(1), out))
    if hit[0].get("verdict") != "CONFLICT":
        refuse("claim %s is %s, not CONFLICT — nothing to resolve" % (m.group(1), hit[0].get("verdict")))
    hit[0]["resolution"] = {"action": m.group(2), "by": E["V_BY"], "at": NOW}
    prior["updated_at"] = NOW
    write(prior)
    drop_view_cache(g)
    print(json.dumps({"unit": unit, "resolved": m.group(1), "action": m.group(2), "out": os.path.relpath(out, cwd)}))
    sys.exit(0)

# ── verdict mode ────────────────────────────────────────────────────────────────
claims_path = E["V_CLAIMS"]
claims_raw = open(claims_path, "rb").read()
wave = json.loads(claims_raw.decode("utf-8"))
claims_sha = hashlib.sha256(claims_raw).hexdigest()
mine = [c for c in wave.get("claims", []) if c.get("unit") == unit]
supplied = json.load(open(E["V_VERDICTS"], encoding="utf-8")) if E.get("V_VERDICTS") else {}

# an E3 (--verdicts) pass must read the capture its first pass recorded (§3): a
# sibling's re-bind rewrote the shared wave file in between → refuse by name
if supplied and prior and prior.get("claims_sha256") and prior.get("claims_sha256") != claims_sha:
    refuse("--verdicts pass reads %s, but %s was bound from %s (sha differs) — pass --claims=%s"
           % (claims_path, unit, prior.get("claims_path"), prior.get("claims_path")))

uf = unit_claims.unit_file(vault, unit)
if not uf:
    refuse("unit file for %s not found under %s/units" % (unit, vault))
unit_rel = os.path.relpath(uf, cwd).replace(os.sep, "/")

# claim-set integrity (§9): the claims the capture minted must still be the claims the
# unit file states — same parser (unit_claims), ids/kinds/paths compared; an expect that
# a recorded repair moved (R1/R2 from→to) is the same claim
prior_repairs = {(r.get("from"), r.get("to")) for r in ((prior or {}).get("repairs") or [])}
now_claims = unit_claims.derive_claims(unit, open(uf, encoding="utf-8", errors="replace").read(), os.path.relpath(uf, cwd))


def _claim_key(c):
    return (c.get("id"), c.get("kind"))


if not mine and now_claims:
    refuse("%s is not in the capture %s (a sibling's re-bind may have rewritten a shared wave file) — re-run derive-unit-claims for %s"
           % (unit, claims_path, unit))
if mine:
    a = {_claim_key(c): c.get("expect") for c in mine}
    b = {_claim_key(c): c.get("expect") for c in now_claims}
    drift = []
    if set(a) != set(b):
        drift.append("claim ids/kinds differ: %s" % ", ".join("%s/%s" % k for k in sorted(set(a) ^ set(b))[:4]))
    else:
        for k, ea in a.items():
            eb = b[k]
            if ea != eb and (ea, eb) not in prior_repairs and (eb, ea) not in prior_repairs:
                drift.append("%s: %s → %s" % (k[0], ea, eb))
    if drift:
        refuse("claim set drifted since the capture (%s) — re-run the bind for %s" % ("; ".join(drift[:3]), unit))


def _git(*args, ok=(0,)):
    """Checked git for the writer: a failure while a .git exists REFUSES the bind."""
    try:
        return fr.git(g["top"], list(args), ok=ok)
    except fr.GitError as e:
        refuse("git failed while binding %s (%s) — nothing written" % (unit, e))


if g:
    H, _ = fr.read_head(g)
    if not H:
        refuse("HEAD does not resolve — nothing written")
else:
    H = None

# ── index ───────────────────────────────────────────────────────────────────────
idx_path = os.path.join(cwd, ".mega-sdd", "codebase", "symbol-index.json")
index, index_head, index_doc = None, None, {}
if os.path.isfile(idx_path):
    try:
        index_doc = json.load(open(idx_path, encoding="utf-8")) or {}
        index, index_head = index_doc.get("symbols", []), index_doc.get("head_commit")
    except Exception:
        index, index_doc = None, {}
# the SAME probe as build-symbol-index.sh (`command -v ast-grep`): on Linux `sg` is
# shadow-utils, never ast-grep — a false "present" would null every stamp forever
HAVE_ASTGREP = bool(shutil.which("ast-grep"))
if index is not None and H and index_head != H and not HAVE_ASTGREP:
    # no ast-grep to rebuild it: an index from another HEAD is treated as absent (§3)
    index, index_head = None, None


def _read_lines(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read().splitlines()
    except OSError:
        return None


def _sha(lines):
    return hashlib.sha256("\n".join(lines).encode("utf-8", "replace")).hexdigest()[:12]


def _full_sha(lines):
    return hashlib.sha256("\n".join(lines).encode("utf-8", "replace")).hexdigest()


def _git_quiet(*args):
    if not g:
        return None
    try:
        rc, out_ = fr.git(g["top"], list(args), ok=(0, 1, 128))
        return out_ if rc == 0 else None
    except fr.GitError:
        return None


def anchor_snapshot(token):
    """The commit that INTRODUCED `token` into the unit file — the anchor's authoring
    snapshot: walk the unit's commits newest→oldest while the token is present; the
    oldest of that run introduced it. None = the token exists only in the working tree
    (authored against the CURRENT files, so the current file IS the snapshot)."""
    if not g:
        return None
    log = _git("log", "--format=%H", "--", unit_rel)[1]  # a failed log REFUSES (never "authored against the tree")
    intro = None
    for sha in log.split():
        content = _git_quiet("show", "%s:%s" % (sha, unit_rel))
        if content is None or token not in content:
            break
        intro = sha
    return intro


def _lines_at(sha, rel):
    if sha is None:
        return _read_lines(os.path.join(cwd, rel))
    txt = _git_quiet("show", "%s:%s" % (sha, rel))
    return txt.splitlines() if txt is not None else None


# own-commit attribution for this unit (§5 b), shared with the view and the gate
UNIT_REC = {"uid": unit, "targets": set(), "bolt_dir": os.path.relpath(os.path.join(vault, "bolts", unit), cwd).replace(os.sep, "/")}
for c in now_claims:
    if c["source"].endswith(":target_files"):
        UNIT_REC["targets"].add(vs.norm(cwd, c["expect"]) or c["expect"])
BOUND = bolt_attrib.bound_vault_roots(cwd)


def only_own_since(base, rel):
    """(touched, all_own) for project-relative `rel` over base..HEAD."""
    if not (g and base and H):
        return False, False
    q = fr.to_top(g, vs.norm(cwd, rel) or rel)
    if not q:
        return False, False
    try:
        commits = fr.log_range(g, base, H, [q])
    except fr.GitError:
        return False, False
    att = fr.Attributor(cwd, g, BOUND, commits)
    return att.only_own(q, UNIT_REC)


def is_ancestor(a, b):
    """rc 0 → True, rc 1 → False; an unknown object is not an ancestor; any other git
    failure while a .git exists REFUSES the bind (§3: never a verdict from an error)."""
    if not (g and a and b):
        return False
    rc = _git("merge-base", "--is-ancestor", a, b, ok=(0, 1, 128))[0]
    if rc == 128:
        if _git_quiet("cat-file", "-e", a + "^{commit}") is None:
            return False  # the object is gone: simply not an ancestor
        refuse("git merge-base failed for %s..%s — nothing written" % (a[:8], b[:8]))
    return rc == 0


def label_token(expect):
    """The first backticked identifier on the unit's `## Anchors` line for `expect`."""
    sec = re.search(r"(?ims)^##[ \t]+Anchors\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)", open(uf, encoding="utf-8", errors="replace").read())
    if not sec:
        return None
    for ln in sec.group(1).splitlines():
        if expect in ln:
            for tok in re.findall(r"`([^`]+)`", ln):
                if re.fullmatch(r"[A-Za-z_]\w*", tok):
                    return tok
    return None


def fs_exists(expect, source, prior_claim):
    """(ok, why, repair, state, extra) — repair set ONLY for R1/R2 range repairs."""
    m = re.match(r"^(.+?):(\d+)(?:-(\d+))?$", expect)
    path = os.path.join(cwd, m.group(1) if m else expect)
    if not os.path.exists(path):
        return False, "absent", None, None, {}
    if not (m and os.path.isfile(path)):
        return True, "present", None, None, {}
    rel, lo, hi = m.group(1), int(m.group(2)), int(m.group(3) or m.group(2))
    cur = _read_lines(path) or []
    n = len(cur)
    in_anchors = (source or "").endswith("## Anchors")
    if hi <= n:
        if not in_anchors:
            return True, "present", None, None, {}
        return ladder(expect, rel, lo, hi, cur, prior_claim)
    # ── stale line-range: repair only against the authoring snapshot, content-identical ──
    if not in_anchors:
        return False, "line %d beyond EOF (%d lines)" % (hi, n), None, None, {}
    snap = anchor_snapshot(expect)
    ref = _lines_at(snap, rel)
    if ref is None:
        return False, "line %d beyond EOF (%d lines); no authoring snapshot of %s — not repairable" % (hi, n, rel), None, None, {}
    ref_sha = (snap or "worktree")[:8]
    if hi <= len(ref):
        block = ref[lo - 1:hi]
        L = len(block)
        hits = [i for i in range(0, max(0, n - L + 1)) if cur[i:i + L] == block]
        if len(hits) == 1:
            s = hits[0] + 1
            to = "%s:%d%s" % (rel, s, ("-%d" % (s + L - 1)) if m.group(3) else "")
            return True, "repaired: authored lines %d-%d found verbatim at %d-%d (content sha %s, snapshot %s)" % (lo, hi, s, s + L - 1, _sha(block), ref_sha), \
                {"from": expect, "to": to, "rule": "R1-shift", "reference": ref_sha, "content_sha256": _sha(block)}, None, {}
        return False, "line %d beyond EOF (%d lines); authored content not found verbatim (%d match(es)) — not repairable" % (hi, n, len(hits)), None, None, {}
    if cur == ref and lo <= n and (hi == n + 1 or lo == 1):
        # R2 — clamp (8.0.1): file byte-identical to the snapshot AND an overshoot of exactly
        # one line (the trailing-newline miscount) OR a WHOLE-FILE anchor (lo == 1).
        to = ("%s:%d-%d" % (rel, lo, n)) if m.group(3) else ("%s:%d" % (rel, n))
        why = "range overshot EOF by 1" if hi == n + 1 else "whole-file range overshot EOF by %d" % (hi - n)
        return True, "repaired: file unchanged since authoring (content sha %s, snapshot %s), %s — clamped to %s" % (_sha(cur), ref_sha, why, to.split(":")[1]), \
            {"from": expect, "to": to, "rule": "R2-clamp", "reference": ref_sha, "content_sha256": _sha(cur)}, None, {}
    return False, "line %d beyond EOF (%d lines); content differs from the authoring snapshot, or a partial range overshoots by > 1 — not repairable" % (hi, n), None, None, {}


def ladder(expect, rel, lo, hi, cur, prior_claim):
    """The §9 in-range content ladder. → (ok, why, repair, state, extra)."""
    block = cur[lo - 1:hi]
    cur_sha = _full_sha(block)
    ref_sha = None
    if prior_claim:
        ref_sha = ((prior_claim.get("anchor_changed") or {}).get("reference")
                   or (prior_claim.get("content_sha") if isinstance(prior_claim.get("content_sha"), str) else None))
    if ref_sha and ref_sha == cur_sha:
        return True, "present (content identical to the bound reference)", None, None, {"content_sha": cur_sha}
    # rung 2a — the prior BOUND block (its content_sha: §9's primary reference, 0 git) moved
    # verbatim, uniquely. Holds without any git snapshot (an uncommitted vault, a token a
    # previous R1 repair wrote into the working tree). Only for the SAME anchor.
    if ref_sha and prior_claim and expect in (prior_claim.get("expect"), prior_claim.get("anchor")):
        L = hi - lo + 1
        hits = [i for i in range(0, max(0, len(cur) - L + 1)) if _full_sha(cur[i:i + L]) == ref_sha]
        if len(hits) == 1 and hits[0] + 1 != lo:
            s = hits[0] + 1
            to = "%s:%d%s" % (rel, s, ("-%d" % (s + L - 1)) if hi != lo or "-" in expect.split(":")[-1] else "")
            return True, "repaired: bound block (content sha %s) found verbatim at %d-%d (R1-shift)" % (ref_sha[:12], s, s + L - 1), \
                {"from": expect, "to": to, "rule": "R1-shift", "reference": "prior", "content_sha256": ref_sha[:12]}, \
                None, {"content_sha": ref_sha}
    snap = anchor_snapshot(expect)
    if snap is None:
        # authored against the working tree: the current block IS the reference
        if not ref_sha:
            return True, "present (anchor authored against the current tree)", None, None, {"content_sha": cur_sha}
        ref_block = None
    else:
        snap_lines = _lines_at(snap, rel)
        ref_block = snap_lines[lo - 1:hi] if snap_lines is not None and hi <= len(snap_lines) else None
        if ref_block is not None and not ref_sha:
            ref_sha = _full_sha(ref_block)
    if ref_block is not None and ref_block == block:
        return True, "present (block identical to the authoring snapshot)", None, None, {"content_sha": cur_sha}
    # rung 2 — the reference block moved verbatim, uniquely
    if ref_block:
        L = len(ref_block)
        hits = [i for i in range(0, max(0, len(cur) - L + 1)) if cur[i:i + L] == ref_block]
        if len(hits) == 1 and hits[0] + 1 != lo:
            s = hits[0] + 1
            to = "%s:%d%s" % (rel, s, ("-%d" % (s + L - 1)) if hi != lo or "-" in expect.split(":")[-1] else "")
            return True, "repaired: bound block found verbatim at %d-%d (R1-shift)" % (s, s + L - 1), \
                {"from": expect, "to": to, "rule": "R1-shift", "reference": (snap or "prior")[:8], "content_sha256": _sha(ref_block)}, \
                None, {"content_sha": _full_sha(ref_block)}
    # rung 3 — changed only through this unit's own commits since the reference point
    # the reference point (§9): a prior bind that VETTED this block (a clean CONFIRMED, no
    # anchor_changed mark, a full-hex stamp that is an ancestor of HEAD) is the base, so
    # commits it already judged never count again; otherwise the authoring snapshot
    _pv = (prior or {}).get("based_on_sha") if (prior or {}).get("schema") == "unit-binding/2" else None
    _vetted = bool(prior_claim and prior_claim.get("verdict") == "CONFIRMED" and not prior_claim.get("anchor_changed")
                   and isinstance(prior_claim.get("content_sha"), str)
                   and (prior_claim.get("anchor") or prior_claim.get("expect")) == expect
                   and _pv and fr.HEX_FULL.match(str(_pv)) and is_ancestor(_pv, H))
    base = _pv if _vetted else (snap or _pv)
    touched, all_own = only_own_since(base, rel) if base else (False, False)
    if touched and all_own:
        return True, "present (block changed only by %s's own commits)" % unit, None, "IMPLEMENTED_BY_UNIT", {"content_sha": cur_sha}
    # rung 4 — changed, but the anchor's label is still in range
    lab = label_token(expect)
    if lab and any(re.search(r"\b%s\b" % re.escape(lab), ln) for ln in block):
        return True, "present (content changed since binding; label `%s` still in range)" % lab, None, None, \
            {"content_sha": ref_sha or cur_sha, "anchor_changed": {"reference": ref_sha, "seen": cur_sha}}
    # rung 5
    return False, "anchor_content_drift: the anchored block changed since it was bound (no own-commit trail, label not found)", \
        None, None, {"content_sha": ref_sha}


def content_sha_of(expect):
    """content_sha per anchor shape (§3): lines → sha256 of the range; a whole file →
    sha256 of its bytes; a directory → None; `+`-joined → list; none → None."""
    if not expect:
        return None
    parts = [p.strip() for p in re.split(r"\s*\+\s*", str(expect)) if p.strip()]
    vals = []
    for p in parts:
        m = re.match(r"^(.+?):(\d+)(?:-(\d+))?$", p)
        path = os.path.join(cwd, m.group(1) if m else p)
        if os.path.isdir(path):
            vals.append(None)
        elif m and os.path.isfile(path):
            lines = _read_lines(path) or []
            lo, hi = int(m.group(2)), int(m.group(3) or m.group(2))
            vals.append(_full_sha(lines[lo - 1:hi]) if hi <= len(lines) else None)
        elif os.path.isfile(path):
            with open(path, "rb") as f:
                vals.append(hashlib.sha256(f.read()).hexdigest())
        else:
            vals.append(None)
    return vals[0] if len(vals) == 1 else vals


def norm(p):
    return p.replace("\\", "/").lstrip("./")


prior_by_id = {c.get("id"): c for c in ((prior or {}).get("claims") or []) if isinstance(c, dict)}
done = False
_br = os.path.join(out_dir, "bolt-report.md")
if os.path.isfile(_br):
    _st = re.search(r"(?m)^status:\s*(\w+)", open(_br, encoding="utf-8", errors="replace").read())
    done = bool(_st and _st.group(1) in ("success", "forced_pass")) and unit not in set(vault_layouts.inflight_units(cwd))
symbol_from_index = False

verdicts = []
repairs = []
for c in mine:
    v = {"id": c["id"], "kind": c["kind"], "expect": c["expect"], "source": c["source"],
         "verdict": None, "state": None, "anchor": None, "confidence": None, "evidence": None}
    if c.get("text"):
        v["text"] = c["text"]
    pc = prior_by_id.get(c["id"])
    k = c["kind"]
    if done and pc and pc.get("verdict") and k in ("fs_must_not_exist",) or (done and pc and (c.get("source") or "").endswith("## Anchors")):
        # a DONE unit's pre-implementation claims are carried forward, never re-verdicted (§5)
        for key in ("verdict", "state", "anchor", "confidence", "evidence", "content_sha", "absent_at", "anchor_changed", "resolution"):
            if key in pc:
                v[key] = pc[key]
        v["carried_forward"] = "done unit"
        verdicts.append(v)
        continue
    if k == "fs_must_exist":
        ok, why, rep, state, extra = fs_exists(c["expect"], c.get("source", ""), pc)
        v.update(verdict="CONFIRMED" if ok else "CONFLICT", state=(state or "IMPLEMENTED") if ok else "MISSING",
                 anchor=(rep["to"] if rep else c["expect"]) if ok else None, confidence="high", evidence="fs: %s" % why)
        v.update(extra)
        if "content_sha" not in v:
            v["content_sha"] = content_sha_of(v["anchor"] or c["expect"])
        if rep:
            v["repair"] = rep
            repairs.append((c.get("source", ""), rep))
    elif k == "fs_must_not_exist":
        if "*" in c["expect"] or "?" in c["expect"]:
            # a glob-declared create target (B3 accepts them): present = any file it covers
            import glob as _glob
            _covered = sorted(os.path.relpath(x, cwd).replace(os.sep, "/")
                              for x in _glob.glob(os.path.join(cwd, c["expect"]), recursive=True) if os.path.isfile(x))
        else:
            _covered = [c["expect"]] if os.path.exists(os.path.join(cwd, c["expect"])) else []
        present = bool(_covered)
        if not present:
            v.update(verdict="CONFIRMED", state="NEW", confidence="high", evidence="fs: absent")
            if H:
                v["absent_at"] = H
        else:
            # §9 inductive create rule: the target appeared only through this unit's own commits
            A = (pc or {}).get("absent_at")
            if g and H and (not A or not is_ancestor(A, H)):
                # §9 (a): no absent_at (a pre-Slice-2 binding) or not an ancestor any more
                # (a pull --rebase) → merge-base of it / the prior stamp with HEAD; a
                # unit-binding/1 prior's stamp is its short-8 `head`
                ph = str((prior or {}).get("head") or "").lower()
                legacy = (prior or {}).get("schema") != "unit-binding/2"
                base = A or (prior or {}).get("based_on_sha") or (ph if legacy and fr.HEX_SHORT.match(ph) else None)
                mb = _git_quiet("merge-base", base, H) if base else None
                A = mb.strip() if mb else None
            implemented = False
            if g and H and A:
                implemented = True
                for cp in _covered:
                    qtop = fr.to_top(g, vs.norm(cwd, cp) or cp)
                    absent_then = qtop and _git_quiet("cat-file", "-e", "%s:%s" % (A, qtop)) is None
                    tracked_now = qtop and _git_quiet("cat-file", "-e", "%s:%s" % (H, qtop)) is not None
                    touched, all_own = only_own_since(A, cp) if (absent_then and tracked_now) else (False, False)
                    try:
                        clean = bool(qtop) and qtop not in fr.dirty_map(g, {qtop})
                    except fr.GitError:
                        refuse("git failed while checking %s — nothing written" % cp)
                    if not (absent_then and tracked_now and touched and all_own and clean):
                        implemented = False
                        break
            if implemented:
                v.update(verdict="CONFIRMED", state="IMPLEMENTED_BY_UNIT", anchor=c["expect"], confidence="high",
                         evidence="fs: created only by %s's own commits since %s" % (unit, A[:8]), absent_at=A)
            else:
                v.update(verdict="CONFLICT", state="ALREADY_EXISTS", anchor=c["expect"], confidence="high",
                         evidence="fs: present")
    elif k == "symbol":
        f, sym = c["expect"].rsplit(":", 1)
        if index is None:
            v.update(verdict="OQ", state="UNKNOWN", confidence="low", evidence="symbol-index.json absent — run scripts/build-symbol-index.sh")
        else:
            symbol_from_index = True
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
    else:  # text — model ladder result, or OQ, or a carried-forward E3 verdict
        s = supplied.get(c["id"])
        if s:
            if s.get("verdict") not in ENUM:
                refuse("claim %s: verdict %r not in %s" % (c["id"], s.get("verdict"), ENUM))
            if s["verdict"] == "CONFIRMED" and not s.get("anchor"):
                refuse("claim %s: CONFIRMED without an anchor is CONFIRMED-by-absence" % c["id"])
            v.update(verdict=s["verdict"], state=s.get("state") or ("IMPLEMENTED" if s["verdict"] == "CONFIRMED" else "UNKNOWN"),
                     anchor=s.get("anchor"), confidence=s.get("confidence") or "medium", evidence=s.get("evidence") or "model ladder (express-bind §E3)")
            v["e3"] = True
        else:
            v.update(verdict="OQ", state="UNKNOWN", confidence="low", evidence="text claim: awaiting ladder E3 verdict (--verdicts)")
    verdicts.append(v)

# ── the scope + the D25a re-check + the dirty snapshot ─────────────────────────
sc = vs.unit_scope(cwd, vault, unit)
scope = sorted(sc["paths"] | sc["globs"])
for v in verdicts:  # anchors the verdicts produced are scope too (a collision, a repair)
    for piece in re.split(r"\s*\+\s*", str(v.get("anchor") or "")):
        piece = re.sub(r":\d+(-\d+)?$", "", piece.strip())
        p = vs.norm(cwd, piece) if piece and ("/" in piece or "." in piece) else None
        if p and p not in scope:
            scope.append(p)
scope = sorted(set(scope))
scope_top = {fr.to_top(g, p) for p in scope} - {None} if g else set()
null_cause = None
dirty_now = {}
if not g:
    null_cause = "no_git"
else:
    try:
        dirty_now = {fr.to_proj(g, q): h for q, h in fr.dirty_map(g, scope_top).items()}
    except fr.GitError as e:
        refuse("git failed while taking the dirty map (%s) — nothing written" % e)
    cap_dirty = wave.get("dirty")
    if cap_dirty is None:
        null_cause = "capture_unavailable"
    else:
        # compare only where the capture LOOKED: verdict anchors added after it (an E3
        # anchor, a collision) were never captured, so they cannot have "moved"
        cap_scope = wave.get("scope")
        cmp_top = scope_top if not isinstance(cap_scope, list) else \
            {q for q in scope_top if any(fr.matches(q, fr.to_top(g, s) or s) for s in cap_scope)}
        in_cmp = lambda p: any(fr.matches(fr.to_top(g, p) or "", sp) for sp in cmp_top)
        cap_sub = {p: h for p, h in cap_dirty.items() if in_cmp(p)}
        now_sub = {p: h for p, h in dirty_now.items() if in_cmp(p)}
        if cap_sub != now_sub:
            null_cause = "writer_capture_moved"

# ── the honest stamp: the OLDEST evidence SHA, or null (§3) ─────────────────────
based_on = None
if not null_cause:
    evidence = {H}
    cap_head = wave.get("head")
    if any(v.get("e3") for v in verdicts) and cap_head and fr.HEX_FULL.match(str(cap_head)):
        evidence.add(cap_head)
    if symbol_from_index:
        if index_head != H:
            null_cause = "index_stale"
        elif fr.index_mismatch(g, index_doc, dirty_now, scope_top):
            if HAVE_ASTGREP:
                null_cause = "dirty_index"  # 3.9b rebuilds the index first (rebind-units, same rule)
            else:
                # nothing could ever rebuild it: degrade the symbol verdicts instead of a
                # null no remedy clears (§3 "a missing index never nulls the stamp")
                for v in verdicts:
                    if v["kind"] == "symbol" and not v.get("carried_forward"):
                        v.update(verdict="OQ", state="UNKNOWN", anchor=None, confidence="low",
                                 evidence="symbol-index.json read different working-tree bytes and ast-grep is absent to rebuild it")
    if not null_cause:
        ev = sorted(evidence)
        if len(ev) == 1:
            based_on = ev[0]
        else:
            oldest = None
            for a in ev:
                if all(a == b or is_ancestor(a, b) for b in ev):
                    oldest = a
            if not oldest or not is_ancestor(oldest, H):
                null_cause = "evidence_off_line"
            else:
                newest = [b for b in ev if b != oldest][0]
                rc = _git("diff", "--quiet", "--no-relative", oldest, newest, "--", *(fr.pathspecs(scope_top) or ["."]), ok=(0, 1))[0]
                if rc != 0:
                    null_cause = "evidence_off_line"
                else:
                    based_on = oldest

# ── human-resolution carry-forward (Fase-0 moat-8) ──────────────────────────────
prior_v2 = bool(prior) and prior.get("schema") == "unit-binding/2" and fr.HEX_FULL.match(str(prior.get("based_on_sha") or ""))
for v in verdicts:
    pc = prior_by_id.get(v["id"])
    if not pc or v.get("carried_forward"):
        continue
    res = pc.get("resolution")
    if not res:
        continue
    keep = (prior_v2 and v["verdict"] == "CONFLICT" and pc.get("kind") == v["kind"] and pc.get("expect") == v["expect"]
            and is_ancestor(prior["based_on_sha"], H))
    if keep:
        paths = {fr.to_top(g, vs.norm(cwd, re.sub(r":\d+(-\d+)?$", "", x.strip())) or x) for x in
                 re.split(r"\s*\+\s*", "%s + %s" % (v.get("expect") or "", v.get("anchor") or "")) if x.strip()} - {None}
        if paths:
            rc = _git("diff", "--quiet", "--no-relative", prior["based_on_sha"], H, "--", *fr.pathspecs(paths), ok=(0, 1))[0]
            keep = rc == 0 and not any(q in {fr.to_top(g, p) for p in dirty_now} for q in paths)
    if keep:
        v["resolution"] = res
    else:
        v["prior_resolution"] = res

# ── R1 rewrite of the unit's `## Anchors` (the next bind sees the repaired token) ──
if repairs:
    by_unit = {}
    for src, r in repairs:
        by_unit.setdefault(src.split(":")[0], []).append(r)
    for urel, reps in by_unit.items():
        up = os.path.join(cwd, urel)
        try:
            txt = open(up, encoding="utf-8").read()
        except OSError:
            continue
        sec = re.search(r"(?ims)^##[ \t]+Anchors\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)", txt)
        if not sec:
            continue
        body = sec.group(1)
        new_body = body
        for r in reps:
            new_body = re.sub(re.escape(r["from"]) + r"(?![\w-])", r["to"].replace("\\", "\\\\"), new_body, count=1)
        if new_body != body:
            tmpu = up + ".tmp.%d" % os.getpid()
            with open(tmpu, "w", encoding="utf-8") as f:
                f.write(txt[:sec.start(1)] + new_body + txt[sec.end(1):])
            os.replace(tmpu, up)

with open(uf, "rb") as f:
    unit_sha256 = hashlib.sha256(f.read()).hexdigest()  # AFTER the R1 rewrite (§3)

for v in verdicts:
    v.pop("e3", None)
    if not v.get("carried_forward"):
        v.setdefault("content_sha", content_sha_of(v.get("anchor")) if v.get("anchor") else None)
doc = {"schema": "unit-binding/2", "generated_by": GEN, "unit": unit,
       "based_on_sha": based_on, "head": based_on[:8] if based_on else None,
       "scope": scope, "own_targets": sorted(UNIT_REC["targets"]), "unit_sha256": unit_sha256,
       "dirty": dirty_now, "index_head": index_head if symbol_from_index else None,
       "claims_path": os.path.relpath(claims_path, cwd).replace(os.sep, "/"), "claims_sha256": claims_sha,
       "generated_at": NOW,
       "summary": {k: sum(1 for x in verdicts if x["verdict"] == k) for k in ENUM}, "claims": verdicts}
if null_cause:
    doc["null_cause"] = null_cause
if E.get("V_REBIND") == "1" and H:
    doc["rebind_head"] = H
elif H and E.get("V_VERDICTS") and prior and prior.get("rebind_head") == H and prior.get("claims_sha256") == claims_sha:
    doc["rebind_head"] = H  # the E3 (--verdicts) pass completes the SAME 3.9b: the bound survives it
if repairs:
    doc["repairs"] = [dict(r, source=src) for src, r in repairs]
elif prior and prior.get("repairs"):
    doc["repairs"] = prior["repairs"]  # keep the from→to trail the claim-set check reads
write(doc)
drop_view_cache(g)
print(json.dumps({"unit": unit, "claims": len(verdicts), **doc["summary"], "repaired": len(repairs),
                  "repairs": [{"from": r["from"], "to": r["to"], "rule": r["rule"]} for _, r in repairs],
                  "based_on_sha": (based_on or "")[:12] or None, "null_cause": null_cause,
                  "out": os.path.relpath(out, cwd)}))
