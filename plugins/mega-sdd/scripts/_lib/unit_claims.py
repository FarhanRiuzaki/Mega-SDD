"""unit_claims.py — the ONE unit claim grammar (JIT bind step 1, spec
2026-09-10 Appendix F2; moved out of the derive-unit-claims.sh heredoc by the state
anchor, spec 2026-09-25-state-anchor-design.md §9 "Claim-set integrity").

derive-unit-claims.sh mints a wave's claim set with it; write-unit-binding.sh
re-derives ONE unit's claim set with it to refuse a bind whose claims drifted.
Both import this module (0 exec) — the grammar is never re-typed.

Per unit, claims are minted from (in this order, positional ids per unit):
  target_files          create        → fs_must_not_exist (the path must be absent)
                        modify|delete → fs_must_exist
  ## Anchors            `path:line[-line]`   → fs_must_exist (+ line range check)
  existing_interfaces   file + symbol → symbol (symbol index lookup, P1.b writer)
  ## Claims             `- C-U<NNN>-<NN> "<text>" — expect: <path>[:<sym>] | <path> — must-exist | <path> — must-not-exist`
                        → fs_* / symbol / text (text = ladder E3, express-bind.md — model)
"""
import glob
import os
import re

CLAIM_RE = re.compile(r'^-\s+(C-U[\w-]+)\s+"(.+?)"\s+—\s+expect:\s+(.+?)\s*$')
# v8 P2 D1 (2026-09-14, lite 7.36.1 arm): a Next.js route-group / dynamic / slot segment
# — `(group)`, `[id]`, `@slot` — is a legal path segment; the old `[\w.\-]` grammar cut
# `src/app/(blank-layout-pages)/register/page.tsx:1-22` down to `register/page.tsx:1-22`
# and minted a FALSE fs_must_exist CONFLICT on 3/7 units. Same literal as the TOKEN regex
# in check-anchor-freshness.sh / build-dispatch-prompt.sh (kept in step by hand).
ANCHOR_RE = re.compile(r'((?:(?:[\w.\-]+|\([\w.\-]+\)|\[[\w.\-]+\]|@[\w.\-]+)/)*[\w.\-]+\.[A-Za-z]\w{0,7}):(\d+)(?:-(\d+))?\b')


def unit_file(vault, uid):
    for pat in (os.path.join(vault, "units", uid + ".md"), os.path.join(vault, "units", uid, "unit.md")):
        g = sorted(glob.glob(pat))
        if g:
            return g[0]
    return None


def all_unit_ids(vault):
    """`--units=all`: every unit under <vault>/units, sorted, both unit layouts."""
    return sorted({os.path.basename(p)[:-3] for p in glob.glob(os.path.join(vault, "units", "U-*.md"))}
                  | {os.path.basename(os.path.dirname(p)) for p in glob.glob(os.path.join(vault, "units", "U-*", "unit.md"))})


def section(body, name):
    m = re.search(r"(?ms)^##\s+%s\b[^\n]*\n(.*?)(?=^##\s|\Z)" % re.escape(name), body)
    return m.group(1) if m else ""


def fm_block(text):
    m = re.match(r"^---\n(.*?)\n---\n?", text, re.S)
    return (m.group(1), text[m.end():]) if m else ("", text)


def parse_targets(fm):
    out = []
    m = re.search(r"(?ms)^target_files:\s*\n((?:[ \t]+.*\n?)*)", fm)
    if not m:
        return out
    cur = None
    for ln in m.group(1).splitlines():
        pm = re.match(r"\s*-\s*path:\s*(\S+)", ln)
        om = re.match(r"\s*operation:\s*(\w+)", ln)
        if pm:
            cur = {"path": pm.group(1).strip("'\""), "operation": "create"}
            out.append(cur)
        elif om and cur:
            cur["operation"] = om.group(1).lower()
    return out


def parse_interfaces(fm):
    out = []
    m = re.search(r"(?ms)^existing_interfaces:\s*\n((?:[ \t]+.*\n?)*)", fm)
    if not m:
        return out
    cur = None
    for ln in m.group(1).splitlines():
        fmx = re.match(r"\s*-\s*file:\s*(\S+)", ln)
        sm = re.match(r"\s*symbol:\s*(\S+)", ln)
        if fmx:
            cur = {"file": fmx.group(1).strip("'\""), "symbol": None}
            out.append(cur)
        elif sm and cur:
            cur["symbol"] = sm.group(1).strip("'\"")
    return out


def derive_claims(uid, text, rel):
    """The unit's claims, in mint order, with positional `C-U<NNN>-A<NN>` ids for
    the minted ones. `rel` = the unit file's project-relative path (the source key)."""
    claims = []

    def add(kind, expect, source, cid=None, ctext=None):
        n = len(claims) + 1
        c = {"id": cid or "%s-A%02d" % (uid.replace("U-", "C-U"), n), "unit": uid, "kind": kind,
             "expect": expect, "source": source}
        if ctext:
            c["text"] = ctext
        claims.append(c)

    fm, body = fm_block(text)
    for t in parse_targets(fm):
        kind = "fs_must_not_exist" if t["operation"] == "create" else (
            "fs_must_exist" if t["operation"] in ("modify", "delete") else None)
        if kind:
            add(kind, t["path"], "%s:target_files" % rel)
    for a in ANCHOR_RE.finditer(section(body, "Anchors")):
        add("fs_must_exist", "%s:%s%s" % (a.group(1), a.group(2), ("-" + a.group(3)) if a.group(3) else ""),
            "%s:## Anchors" % rel)
    for i in parse_interfaces(fm):
        if i["symbol"]:
            add("symbol", "%s:%s" % (i["file"], i["symbol"]), "%s:existing_interfaces" % rel)
        else:
            add("fs_must_exist", i["file"], "%s:existing_interfaces" % rel)
    for ln in section(body, "Claims").splitlines():
        m = CLAIM_RE.match(ln.strip())
        if not m:
            continue
        cid, ctext, exp = m.group(1), m.group(2), m.group(3).strip()
        if exp.endswith("must-not-exist"):
            add("fs_must_not_exist", exp.split("—")[0].strip(), "%s:## Claims" % rel, cid, ctext)
        elif exp.endswith("must-exist"):
            add("fs_must_exist", exp.split("—")[0].strip(), "%s:## Claims" % rel, cid, ctext)
        elif re.match(r"^[^\s:]+:[A-Za-z_]\w*$", exp):
            add("symbol", exp, "%s:## Claims" % rel, cid, ctext)
        else:
            add("text", exp, "%s:## Claims" % rel, cid, ctext)
    return claims
