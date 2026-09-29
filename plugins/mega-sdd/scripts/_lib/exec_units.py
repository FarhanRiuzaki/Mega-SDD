"""exec_units.py — one reading of a unit for the inline `execute-bolts` run: the run-start gate
(scripts/derive-exec-plan.sh) and the run-boundary scan (_lib/conflict_bypass.py) parse
depends_on / target_files and decide "done" the same way.

done = the unit's evidence says it is implemented: bolt-report.md, acceptance.json pass, no
       quarantine.json; a verify unit needs a success report, any other unit a passing
       postflight.json and a target_hashes entry per file that still matches — or whose file
       changed since only through commits of units that own it (their target_files cover the
       path) or fix(review) / fix(delivery) commits, with a clean working tree. A later unit that
       modifies what an earlier one created does not make the earlier one pending again.
Commit identity is postflight_rules.unit_of — the grammar every bolt-artifact validator uses.
"""
import fnmatch
import glob
import hashlib
import json
import os
import re
import subprocess

from postflight_rules import unit_of

REVIEW_FIX = re.compile(r"^fix\((?:review|delivery)\)!?:")


def pnorm(p):
    p = re.sub(r":\d+(-\d+)?$", "", str(p or "").strip().strip("`'\"")).replace("\\", "/")
    while p.startswith("./"):
        p = p[2:]
    return p


def unit_files(vault):
    """{uid: path} for units/U-*.md and the nested units/U-*/unit.md layout."""
    out = {}
    for p in sorted(glob.glob(os.path.join(vault, "units", "U-*.md")) + glob.glob(os.path.join(vault, "units", "U-*", "unit.md"))):
        b = os.path.basename(p)
        out.setdefault(b[:-3] if b.startswith("U-") else os.path.basename(os.path.dirname(p)), p)
    return out


def _list(fm, key):
    """A frontmatter list, flow `[a, b]` or block `- a` form, `#` comments stripped."""
    m = re.search(r"(?m)^%s:[ \t]*(\[[^\]]*\])?[ \t]*(?:#[^\n]*)?\n((?:[ \t]+-[^\n]*\n?)*)" % key, fm)
    raw = (m.group(1)[1:-1].split(",") if m.group(1) else [re.sub(r"^[ \t]+-", "", ln) for ln in m.group(2).splitlines()]) if m else []
    return [x for x in (re.sub(r"\s*#.*$", "", d).strip().strip("'\"") for d in raw) if x]


def parse(path):
    """The frontmatter facts the inline gates read. Raises OSError when unreadable."""
    txt = open(path, encoding="utf-8", errors="replace").read()
    m = re.match(r"\A---[ \t]*\n(.*?)\n---[ \t]*(?:\n|\Z)", txt, re.S)
    fm = (m.group(1) if m else "") + "\n"

    def field(k):
        f = re.search(r"(?m)^%s:[ \t]*(.+?)[ \t]*$" % k, fm)
        return f.group(1).strip("'\"") if f else ""
    targets = []
    tb = re.search(r"(?m)^target_files:[ \t]*\n((?:[ \t]+.*\n?)*)", fm)
    for ln in (tb.group(1).splitlines() if tb else []):
        pm, om = re.match(r"\s*-\s*path:\s*(\S+)", ln), re.match(r"\s*operation:\s*(\w+)", ln)
        if pm:
            targets.append({"path": pnorm(pm.group(1)), "operation": "create"})
        elif om and targets:
            targets[-1]["operation"] = om.group(1).lower()
    b = os.path.basename(path)
    return {"file": path, "deps": [d for d in _list(fm, "depends_on") if d.startswith("U-")], "targets": targets,
            "title": field("title") or (b[:-3] if b.startswith("U-") else os.path.basename(os.path.dirname(path))),
            "status": field("status").lower(), "task_type": field("task_type").lower(),
            "consumes": _list(fm, "consumes_interfaces"), "squad": field("squad")}


def _git(root, *a):
    try:
        r = subprocess.run(["git", "-C", root, *a], capture_output=True, timeout=60)
    except (subprocess.TimeoutExpired, OSError):
        return None
    return r.stdout if r.returncode == 0 else None


def _jpass(p):
    try:
        return str(json.load(open(p, encoding="utf-8")).get("status") or "").lower() == "pass"
    except (OSError, ValueError, AttributeError):
        return False


def _sha(p):
    try:
        return hashlib.sha256(open(p, "rb").read()).hexdigest()
    except OSError:
        return None


def target_hashes(report):
    m = re.match(r"\A---\n(.*?)\n---\n", report or "", re.S)
    tb = re.search(r"(?m)^target_hashes:[ \t]*(?:#.*)?\n((?:[ \t]+.*\n?)*)", m.group(1) + "\n") if m else None
    return dict(re.findall(r"(?m)^[ \t]+([^\s:#][^:]*?):[ \t]*([0-9a-f]{64})\b", tb.group(1))) if tb else {}


def owned_change(root, units, rel, recorded):
    """rel changed after the recorded hash only through commits of units that own it (or a
    review fix), and the working tree holds exactly the committed content."""
    if _git(root, "status", "--porcelain", "--", rel) != b"":
        return False
    own = {u for u, d in units.items() if d and any(t["path"] == rel or fnmatch.fnmatch(rel, t["path"]) for t in d["targets"])}
    log = (_git(root, "log", "--format=%x01%H%x02%s%x02%(trailers:key=Unit,valueonly,separator=%x2C)", "--", rel) or b"")
    for chunk in log.decode("utf-8", "replace").split("\x01")[1:]:
        sha, subj, trl = (chunk.split("\x02") + ["", ""])[:3]
        blob = _git(root, "show", "%s:./%s" % (sha.strip(), rel))
        if blob is not None and hashlib.sha256(blob).hexdigest() == recorded:
            return True
        if unit_of(subj, trl.strip()) not in own and not REVIEW_FIX.match(subj):
            return False
    return False


def done(root, vault, uid, units):
    """True when uid is done by its evidence (see the module docstring)."""
    b = os.path.join(vault, "bolts", uid)
    if os.path.isfile(os.path.join(b, "quarantine.json")) or not _jpass(os.path.join(b, "acceptance.json")):
        return False
    try:
        rep = open(os.path.join(b, "bolt-report.md"), encoding="utf-8", errors="replace").read()
    except OSError:
        return False
    if (units.get(uid) or {}).get("task_type") == "verify":
        return bool(re.search(r"(?m)^status:\s*(success|forced_pass)\b", rep))
    hashes = target_hashes(rep)
    if not hashes or not _jpass(os.path.join(b, "postflight.json")):
        return False
    return all(_sha(os.path.join(root, rel)) == h or owned_change(root, units, rel, h) for rel, h in hashes.items())
