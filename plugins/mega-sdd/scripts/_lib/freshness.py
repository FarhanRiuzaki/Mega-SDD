"""freshness.py — the state-anchor freshness engine (spec
docs/superpowers/specs/2026-09-25-state-anchor-design.md §5).

Code at HEAD is the source of truth; every vault/unit binding is a derived claim
stamped with the SHA it was verified against. This engine answers, per vault and
cheaply, "does that claim still describe HEAD?":
  (a) stamp == HEAD                         → no scope change, 0 git
  (c) stamp not an ancestor of HEAD          → STALE for the whole scope
      (diverged: rc 1; unreachable: rc 128 and the object is gone)
  (b) tree diff stamp..HEAD over the scope   → empty = no scope change;
      paths = STALE, minus own-target paths touched ONLY by the unit's own
      bolt commits (bolt_attrib), with `git log` context lines
  (d) dirty in-scope paths (scoped status)   → flagged, never FRESH-collapsed
  (e) behind the last-fetched upstream       → warning line only, never a fetch
It writes NOTHING but the per-worktree view cache in the git dir (never tracked,
never under .mega-sdd/) — no report, metric or log. Any git error makes that
group UNVERIFIED; the CLI always exits 0.

Trust tiers: FRESH / "verified at this HEAD" are used only for `unit-binding/2`
script stamps. Pre-honest short-8 heads and model-typed classic heads render as
hints ("no scope change since <h8> (…: hint)"), never FRESH.

Usage (CLI):  python3 freshness.py --cwd=<project root> [--print] [--cwd-rel=<rel>]
"""
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bolt_attrib  # noqa: E402
import vault_scope as vs  # noqa: E402

TIMEOUT = 15
MAX_STAMPS = 8
PATHSPEC_MAX_N = 200
PATHSPEC_MAX_BYTES = 8192
UP_DEPTH = 200
SHOW_FILES = 3
SHOW_COMMITS = 3
SUBJ_MAX = 50
PATH_MAX = 80
MAX_LINES = 6
BLOCK_MAX = 1200
CACHE_NAME = "mega-sdd-freshness"

RULE_LINE = ("Rule: code at HEAD decides what the code IS (files, symbols, lines, what is built). "
             "Memory, CLAUDE.md and vault/unit/bolt-report claims about what the code IS are derived: "
             "no SHA = hint, contradicts HEAD = STALE; say so, never use them silently. "
             "What the code SHOULD do stays with the vault: a spec-vs-code mismatch is a CONFLICT for a human.")

HEX_FULL = re.compile(r"^[0-9a-f]{40}(?:[0-9a-f]{24})?$")
HEX_SHORT = re.compile(r"^[0-9a-f]{7,64}$")
_SAFE = re.compile(r"[^A-Za-z0-9._/:()#@+ -]")


class GitError(Exception):
    pass


def sanitize(s, n=None):
    s = _SAFE.sub("_", str(s))
    if n and len(s) > n:
        s = s[: n - 1] + "…"
    return s


# ── git plumbing ─────────────────────────────────────────────────────────────
def _env():
    e = dict(os.environ)
    e["GIT_NO_REPLACE_OBJECTS"] = "1"
    e["MSYS_NO_PATHCONV"] = "1"
    e["GIT_OPTIONAL_LOCKS"] = "0"
    for k in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"):
        e.pop(k, None)
    return e


def git(top, args, ok=(0,)):
    cmd = ["git", "-c", "core.fsmonitor=false", "-c", "core.quotepath=false",
           "--no-optional-locks", "-C", top] + list(args)
    try:
        r = subprocess.run(cmd, capture_output=True, timeout=TIMEOUT, env=_env())
    except (OSError, subprocess.TimeoutExpired) as e:
        raise GitError("git %s: %s" % (args[0] if args else "", type(e).__name__))
    if r.returncode not in ok:
        err = (r.stderr.decode("utf-8", "replace").strip().splitlines() or [""])[0]
        raise GitError("git %s rc=%d: %s" % (args[0], r.returncode, err))
    return r.returncode, r.stdout.decode("utf-8", "replace")


def find_git(root):
    """Builtin-equivalent `.git` walk (the ONLY not-a-repo decision)."""
    d = os.path.abspath(root)
    while True:
        g = os.path.join(d, ".git")
        if os.path.isdir(g):
            gitdir, top = g, d
            break
        if os.path.isfile(g):
            try:
                line = open(g, encoding="utf-8", errors="replace").readline().strip()
            except OSError:
                return None
            if not line.startswith("gitdir:"):
                return None
            gd = line[len("gitdir:"):].strip()
            if not os.path.isabs(gd) and not re.match(r"^[A-Za-z]:/", gd):
                gd = os.path.join(d, gd)
            gitdir, top = os.path.normpath(gd), d
            break
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent
    common = gitdir
    try:
        c = open(os.path.join(gitdir, "commondir"), encoding="utf-8").readline().strip()
        if c:
            cc = c if os.path.isabs(c) else os.path.join(gitdir, c)
            if os.path.isdir(cc):
                common = os.path.normpath(cc)
    except OSError:
        pass
    prefix = os.path.relpath(os.path.abspath(root), top).replace("\\", "/")
    return {"top": top, "gitdir": gitdir, "common": common, "prefix": "" if prefix == "." else prefix}


def _read1(p):
    try:
        with open(p, encoding="utf-8", errors="replace") as f:
            return f.readline().strip()
    except OSError:
        return None


def _packed(common, ref):
    try:
        with open(os.path.join(common, "packed-refs"), encoding="utf-8", errors="replace") as f:
            for ln in f:
                ln = ln.strip()
                if ln.endswith(" " + ref):
                    sha = ln.split(" ", 1)[0]
                    return sha if HEX_FULL.match(sha) else None
    except OSError:
        pass
    return None


def read_ref(g, ref):
    for base in (g["gitdir"], g["common"]):
        s = _read1(os.path.join(base, ref))
        if s and HEX_FULL.match(s):
            return s
    return _packed(g["common"], ref)


def read_head(g):
    """(sha or None, branch). Builtin reads; one rev-parse fallback."""
    h = _read1(os.path.join(g["gitdir"], "HEAD")) or ""
    if not os.path.isdir(os.path.join(g["common"], "reftable")):
        if h.startswith("ref: "):
            ref = h[5:]
            branch = ref[len("refs/heads/"):] if ref.startswith("refs/heads/") else ref
            sha = read_ref(g, ref)
            if sha:
                return sha, branch
        elif HEX_FULL.match(h):
            return h, "detached"
    try:
        _, out = git(g["top"], ["rev-parse", "--verify", "-q", "HEAD"])
        sha = out.strip()
    except GitError:
        sha = None
    branch = "detached"
    if os.path.isdir(os.path.join(g["common"], "reftable")):
        # reftable: the HEAD file holds `ref: refs/heads/.invalid` — ask git (rare path)
        try:
            rc, out = git(g["top"], ["symbolic-ref", "--short", "-q", "HEAD"], ok=(0, 1))
            branch = out.strip() if rc == 0 and out.strip() else "detached"
        except GitError:
            branch = "detached"
    elif h.startswith("ref: "):
        branch = h[5:].replace("refs/heads/", "", 1)
    return (sha if sha and HEX_FULL.match(sha) else None), branch


def upstream(g, branch):
    """(label, sha, fetched_age_s) of the last-fetched @{u}, from files only."""
    if not branch or branch == "detached":
        return None
    try:
        text = open(os.path.join(g["common"], "config"), encoding="utf-8", errors="replace").read()
    except OSError:
        return None
    m = re.search(r'(?ms)^\[branch\s+"%s"\]\s*\n(.*?)(?=^\[|\Z)' % re.escape(branch), text)
    if not m:
        return None
    body = m.group(1)
    rm = re.search(r"(?m)^\s*remote\s*=\s*(\S+)", body)
    mm = re.search(r"(?m)^\s*merge\s*=\s*(\S+)", body)
    if not (rm and mm):
        return None
    remote, merge = rm.group(1), mm.group(1)
    if remote == ".":
        ref, label = merge, merge.replace("refs/heads/", "", 1)
    else:
        short = merge.replace("refs/heads/", "", 1)
        ref, label = "refs/remotes/%s/%s" % (remote, short), "%s/%s" % (remote, short)
    sha = read_ref(g, ref)
    if not sha:
        return None
    age = None
    try:
        age = max(0, time.time() - os.path.getmtime(os.path.join(g["common"], "FETCH_HEAD")))
    except OSError:
        pass
    return label, sha, age


def _age(s):
    if s is None:
        return "fetch time unknown"
    if s < 3600:
        return "fetched %dm ago" % max(1, int(s // 60))
    if s < 86400:
        return "fetched %dh ago" % int(s // 3600)
    return "fetched %dd ago" % int(s // 86400)


# ── scope helpers ────────────────────────────────────────────────────────────
def to_top(g, p):
    """Project-relative (may start ../) → worktree-top-relative, or None when it
    leaves the repository."""
    if p.startswith(vs.GLOB_PREFIX):
        return p
    q = os.path.normpath(os.path.join(g["prefix"], p)).replace("\\", "/") if g["prefix"] else os.path.normpath(p).replace("\\", "/")
    if q == ".." or q.startswith("../") or q == ".":
        return None
    return q


def to_proj(g, q):
    """Worktree-top-relative → project-relative display form."""
    if g["prefix"] and (q == g["prefix"] or q.startswith(g["prefix"] + "/")):
        return q[len(g["prefix"]) + 1:]
    if g["prefix"]:
        return os.path.relpath(q, g["prefix"]).replace("\\", "/")
    return q


def _is_wild(spec):
    """A glob-shaped target_files entry (B3 accepts them). `[` is NOT a wildcard here:
    it is a literal Next.js segment (`[id]`) and B3's matcher escapes it."""
    return not spec.startswith(vs.GLOB_PREFIX) and ("*" in spec or "?" in spec)


def _wild_base(spec):
    """The literal directory prefix of a glob-shaped entry: git lists a superset,
    matches() filters with B3's own matcher (git's default `**/` misses zero dirs,
    and `:(glob)` would read `[` as a class)."""
    lit = []
    for seg in spec.split("/")[:-1]:
        if "*" in seg or "?" in seg:
            break
        lit.append(seg)
    return "/".join(lit) or "."


def matches(q, spec):
    """Top-relative path q under a top-relative scope entry: exact, ancestor dir, the
    basename glob lane, or a glob-shaped entry through B3's matcher."""
    if spec.startswith(vs.GLOB_PREFIX):
        name = spec[len(vs.GLOB_PREFIX):]
        return q == name or q.endswith("/" + name)
    if q == spec or q.startswith(spec + "/") or spec.startswith(q + "/"):
        return True
    return _is_wild(spec) and bolt_attrib.postflight_rules._glob_match(q, spec, basename_fallback=False)


def pathspecs(specs):
    """Exact pathspec list, coarsened to parent dirs past the cap (the view may
    then over-report, never under-report; the gate always uses exact paths)."""
    specs = sorted({_wild_base(s) if _is_wild(s) else s for s in specs})
    if len(specs) <= PATHSPEC_MAX_N and sum(len(s) + 1 for s in specs) <= PATHSPEC_MAX_BYTES:
        return specs
    level = 3
    while level >= 1:
        out = set()
        for s in specs:
            if s.startswith(vs.GLOB_PREFIX):
                out.add(s)
            else:
                parts = s.split("/")
                out.add("/".join(parts[:level]) if len(parts) > level else s)
        if len(out) <= PATHSPEC_MAX_N and sum(len(s) + 1 for s in out) <= PATHSPEC_MAX_BYTES:
            return sorted(out)
        level -= 1
    return ["."]


# ── collection ───────────────────────────────────────────────────────────────
def _stamp_of_unit(bj):
    """(stamp, trust, cause). trust ∈ script | prehonest | null | none | unparseable."""
    try:
        doc = json.load(open(bj, encoding="utf-8"))
    except (OSError, ValueError):
        return None, "unparseable", "binding.json unparseable"
    if not isinstance(doc, dict):
        return None, "unparseable", "binding.json not an object"
    if doc.get("schema") == "unit-binding/2":
        s = str(doc.get("based_on_sha") or "").lower()
        if HEX_FULL.match(s):
            return s, "script", None
        return None, "null", str(doc.get("null_cause") or "stamp null")
    h = str(doc.get("head") or "").lower()
    if HEX_SHORT.match(h):
        return h, "prehonest", None
    return None, "none", "no head"


def collect(root, g):
    bound_roots = bolt_attrib.bound_vault_roots(root)
    out = []
    for vdir in vs.vaults(root):
        v = {"dir": vdir, "name": vs.vault_name(root, vdir), "units": [], "classic": None,
             "unbound": 0, "rel": os.path.relpath(vdir, root).replace("\\", "/")}
        cbj = os.path.join(vdir, "binding.json")
        if os.path.isfile(cbj):
            try:
                cdoc = json.load(open(cbj, encoding="utf-8"))
            except (OSError, ValueError):
                cdoc = {}
            h = str((cdoc or {}).get("head") or "").lower() if isinstance(cdoc, dict) else ""
            sc = vs.classic_scope(root, vdir)
            v["classic"] = {"stamp": h if HEX_SHORT.match(h) else None,
                            "trust": "model" if HEX_SHORT.match(h) else "none",
                            "scope": {to_top(g, p) for p in sc["paths"] | sc["globs"]} - {None},
                            "subunits": []}
        for uid in vs.unit_ids(vdir):
            bj = os.path.join(vdir, "bolts", uid, "binding.json")
            sc = vs.unit_scope(root, vdir, uid)
            u = {"uid": uid,
                 "scope": {to_top(g, p) for p in sc["paths"] | sc["globs"]} - {None},
                 "targets": set(sc["targets"]),
                 "bolt_dir": os.path.relpath(os.path.join(vdir, "bolts", uid), root).replace("\\", "/"),
                 "implemented": os.path.isfile(os.path.join(vdir, "bolts", uid, "bolt-report.md"))}
            if not os.path.isfile(bj):
                if v["classic"] is None:
                    v["unbound"] += 1
                else:
                    # a classic unit: its scope joins the vault-level classic group (§4 vault_scope)
                    v["classic"]["scope"] |= u["scope"]
                    v["classic"]["subunits"].append(u)
                continue
            u["stamp"], u["trust"], u["cause"] = _stamp_of_unit(bj)
            v["units"].append(u)
        if v["units"] or v["classic"] or v["unbound"]:
            out.append(v)
    # two vaults sharing a basename in different layouts (.mega-sdd/vaults/web and
    # root vaults/web) must never share a name: the view keys scope and lines by it
    counts = {}
    for v in out:
        counts[v["name"]] = counts.get(v["name"], 0) + 1
    for v in out:
        if counts[v["name"]] > 1:
            v["name"] = v["rel"]
    return out, bound_roots


def _collisions(vaults):
    """{(vault dir, uid): targets of same-ID units in OTHER vaults} — the gate's
    collision switch-off rule (glob-aware through hits_target at the use site)."""
    by_uid = {}
    for v in vaults:
        for u in v["units"] + (v["classic"]["subunits"] if v["classic"] else []):
            by_uid.setdefault(u["uid"], []).append((v["dir"], u["targets"]))
    out = {}
    for uid, homes in by_uid.items():
        for vd, _ in homes:
            out[(vd, uid)] = set().union(*[t for d, t in homes if d != vd]) if len(homes) > 1 else set()
    return out


# ── the engine ───────────────────────────────────────────────────────────────
def _ancestry(g, head, stamp):
    """'equal' | 'ancestor' | 'diverged' | 'unreachable' | 'error'"""
    if head.startswith(stamp):
        return "equal"
    try:
        rc, _ = git(g["top"], ["merge-base", "--is-ancestor", stamp, head], ok=(0, 1, 128))
    except GitError:
        return "error"
    if rc == 0:
        return "ancestor"
    if rc == 1:
        return "diverged"
    # rc 128: "unreachable" ONLY when the stamp object is gone while HEAD itself
    # still resolves — a safe.directory / corrupt-repo rc 128 fails both and is an
    # error (UNVERIFIED), never a verdict
    try:
        rc2, _ = git(g["top"], ["cat-file", "-e", stamp + "^{commit}"], ok=(0, 1, 128))
        if rc2 == 0:
            return "error"
        rc3, _ = git(g["top"], ["cat-file", "-e", head + "^{commit}"], ok=(0, 1, 128))
    except GitError:
        return "error"
    return "unreachable" if rc3 == 0 else "error"


LOG_FMT = "--format=%x1e%H%x1f%P%x1f%s%x1f%(trailers:key=Unit,valueonly,separator=%x2C)%x1f%B%x1d"


def _parse_log(out):
    commits = []
    for chunk in out.split("\x1e"):
        if not chunk.strip():
            continue
        head, _, files = chunk.partition("\x1d")
        parts = head.split("\x1f")
        if len(parts) < 5:
            continue
        commits.append({"sha": parts[0].strip(), "parents": parts[1].split(), "subject": parts[2],
                        "trailer": parts[3], "body": parts[4],
                        "files": [f for f in files.split("\n") if f.strip()]})
    return commits


def log_range(g, base, head, paths_top):
    """Commits in base..head touching the top-relative paths, first-parent history of
    merges, with subject, Unit-trailer atom and full body (§5 b step 2)."""
    if not paths_top:
        return []
    _, lo = git(g["top"], ["log", "--no-relative", "--full-history", "--diff-merges=first-parent",
                           "--no-renames", "--name-only", LOG_FMT, "%s..%s" % (base, head), "--"] + sorted(paths_top))
    return _parse_log(lo)


class Attributor:
    """Own-commit attribution (§5 b step 3), shared by the view, the writer and the
    gate. The full changed-path sets of candidate commits and the gates' newest-300
    walk are fetched lazily, once, only when a candidate exists."""

    def __init__(self, root, g, bound_roots, commits):
        self.root, self.g, self.bound_roots = root, g, bound_roots
        self.commits = list(commits)
        self.cand = {c["sha"]: None for c in self.commits
                     if len(c["parents"]) == 1 and re.search(r"(?m)^SDD-PROVENANCE:", c["body"])}
        self.walk = None
        self._loaded = False

    def _load(self):
        self._loaded = True
        if not self.cand:
            return
        try:
            _, out = git(self.g["top"], ["log", "--no-relative", "--no-walk=unsorted", "--no-renames", "--full-diff",
                                         "--format=%x1e%H%x1d", "--name-only"] + sorted(self.cand))
            for chunk in out.split("\x1e"):
                if not chunk.strip():
                    continue
                sha, _, files = chunk.partition("\x1d")
                self.cand[sha.strip()] = [f for f in files.split("\n") if f.strip()]
            # the run-boundary gates walk only the newest 300 commits of the project
            # subtree: an exempted commit must lie inside that walk
            _, wl = git(self.root, ["rev-list", "-300", "HEAD"] + (["--", "."] if self.g["prefix"] else []))
            self.walk = set(wl.split())
        except GitError:
            self.cand, self.walk = {}, None

    def own(self, c, u):
        """u: {"uid", "targets" (project-relative), "bolt_dir" (project-relative)}"""
        if not bolt_attrib.own_shaped(c, u["uid"]) or not bolt_attrib.v5_keyed(self.commits, u["uid"]):
            return False
        if not self._loaded:
            self._load()
        files = self.cand.get(c["sha"])
        if files is None or self.walk is None or c["sha"] not in self.walk:
            return False
        proj = [to_proj(self.g, q) for q in files]
        if not any(not p.startswith("../") for p in proj):
            return False  # a commit invisible to the project-scoped gates never exempts
        # a root-escaping path is own only when it hits a target (never "sanctioned")
        proj = [p if not p.startswith("../") or bolt_attrib.hits_target(p, u["targets"]) else None for p in proj]
        return bolt_attrib.within_own(proj, u["targets"], u["bolt_dir"], self.bound_roots)

    def only_own(self, q, u):
        """(touched, all_own): whether any commit touches top-relative q, and whether
        every one of them is u's own commit (the non-vacuity rule: no commit → False)."""
        touching = [c for c in self.commits if q in c["files"]]
        if not touching:
            return False, False
        return True, all(self.own(c, u) for c in touching)


def evaluate(root, g, head, vaults, bound_roots):
    collide = _collisions(vaults)
    # groups: stamp → list of members (unit dicts or classic pseudo-members)
    by_stamp = {}
    for v in vaults:
        for u in v["units"]:
            if u["stamp"]:
                by_stamp.setdefault(u["stamp"], []).append((v, u))
        c = v["classic"]
        if c and c["stamp"]:
            by_stamp.setdefault(c["stamp"], []).append((v, c))
    order = sorted(by_stamp, key=lambda s: -len(by_stamp[s]))
    checked, skipped = order[:MAX_STAMPS], order[MAX_STAMPS:]
    res = {}  # stamp → {"state": ..., "changed": set, "commits": [...]}
    for s in checked:
        st = _ancestry(g, head, s)
        r = {"state": st, "changed": set(), "commits": []}
        if st == "ancestor":
            specs = set()
            for _, m in by_stamp[s]:
                specs |= m["scope"]
            try:
                _, out = git(g["top"], ["diff", "--no-relative", "--no-renames", "--name-only", "-z", s, head, "--"] + pathspecs(specs))
                ch = {q for q in out.split("\0") if q}
                r["changed"] = {q for q in ch if any(matches(q, sp) for sp in specs)}
                if r["changed"]:
                    r["commits"] = log_range(g, s, head, r["changed"])
            except GitError:
                r["state"] = "error"
        res[s] = r
    for s in skipped:
        res[s] = {"state": "skipped", "changed": set(), "commits": []}

    att = Attributor(root, g, bound_roots, [c for r in res.values() for c in r["commits"]])

    # per-member verdicts
    for v in vaults:
        members = [(u, "unit") for u in v["units"]] + ([(v["classic"], "classic")] if v["classic"] else [])
        for m, kind in members:
            m["verdict"] = None
            m["stale"] = []
            m["own_changed"] = []
            if not m["stamp"]:
                m["verdict"] = "unstamped"
                continue
            r = res[m["stamp"]]
            if r["state"] in ("equal",):
                m["verdict"] = "fresh"
                continue
            if r["state"] in ("diverged", "unreachable", "error", "skipped"):
                m["verdict"] = r["state"]
                continue
            mine = sorted(q for q in r["changed"] if any(matches(q, sp) for sp in m["scope"]))
            stale, own_changed = [], []
            for q in mine:
                p = to_proj(g, q)
                touching = [c for c in r["commits"] if q in c["files"]]
                # the unit(s) whose OWN target this path is: the unit itself, or — for a
                # classic vault-level group — the vault's units read from their unit files
                owners = [o for o in ([m] if kind == "unit" else m["subunits"]) if bolt_attrib.hits_target(p, o["targets"])]
                if owners:
                    dropped = False
                    for o in owners:
                        ours = [c for c in touching if att.own(c, o)]
                        if ours:
                            o["implemented"] = True
                        if touching and len(ours) == len(touching) and not bolt_attrib.hits_target(p, collide.get((v["dir"], o["uid"]), ())):
                            dropped = True  # touched only by that unit's own bolt commits
                    if dropped:
                        continue
                    if kind == "unit":
                        own_changed.append(q)
                    elif all(o["implemented"] for o in owners):
                        for o in owners:
                            o.setdefault("own_changed", []).append(q)
                    else:
                        stale.append(q)
                    continue
                stale.append(q)
            m["stale"], m["own_changed"] = stale, own_changed
            m["verdict"] = "fresh" if not stale and not own_changed else "changed"
    return res


def _object_format(g):
    try:
        cfg = open(os.path.join(g["common"], "config"), encoding="utf-8", errors="replace").read()
        if re.search(r"(?mi)^\s*objectformat\s*=\s*sha256\s*$", cfg):
            return "sha256"
    except OSError:
        pass
    return "sha1"


def blob_hash(g, q):
    """git blob id of the working-tree bytes of top-relative q (python, 0 exec): the
    file bytes, or the symlink target as git stores it; None when absent from disk."""
    full = os.path.join(g["top"], q)
    try:
        if os.path.islink(full):
            data = os.readlink(full).encode("utf-8", "surrogateescape")
        elif os.path.isfile(full):
            with open(full, "rb") as f:
                data = f.read()
        else:
            return None
    except OSError:
        return None
    h = hashlib.sha256() if _object_format(g) == "sha256" else hashlib.sha1()
    h.update(b"blob %d\0" % len(data))
    h.update(data)
    return h.hexdigest()


def _exact_case(full):
    """On a case-insensitive filesystem a mis-cased scope path `exists` but is not the
    tracked file: only an exact on-disk name counts (else it would be permanent dirt)."""
    d, b = os.path.split(full)
    try:
        return b in os.listdir(d or ".")
    except OSError:
        return False


def dirty_map(g, specs):
    """THE dirty map (§5 d; the only definition — capture, writer, index, view and
    gate all call it): scoped `status` + `ls-files -v` (assume-unchanged,
    skip-worktree present on disk) + exact non-directory scope paths present on
    disk but untracked (ignored or not). {top-relative path: blob hash | None}.
    Raises GitError (the caller decides: the view shows nothing, the gate denies)."""
    specs = set(specs)
    if not specs:
        return {}
    ps = pathspecs(specs)
    dirty = set()
    _, st = git(g["top"], ["status", "--porcelain=v1", "-z", "--untracked-files=all", "--"] + ps)
    items = st.split("\0")
    i = 0
    while i < len(items):
        it = items[i]
        i += 1
        if len(it) < 4:
            continue
        code, path = it[:2], it[3:]
        if code[0] in "RC":
            i += 1  # the rename source follows
        dirty.add(path)
    _, lf = git(g["top"], ["ls-files", "-v", "-z", "--"] + ps)
    tracked = set()
    for it in lf.split("\0"):
        if len(it) < 3:
            continue
        tag, path = it[0], it[2:]
        tracked.add(path)
        if tag.islower():
            dirty.add(path)  # assume-unchanged: the index lies about it
        elif tag == "S" and os.path.lexists(os.path.join(g["top"], path)):
            dirty.add(path)  # skip-worktree that exists on disk (not an out-of-cone entry)
    for sp in specs:
        if sp.startswith(vs.GLOB_PREFIX):
            continue
        full = os.path.join(g["top"], sp)
        # a real directory is never a dirty key itself: untracked files beneath it
        # already show in the scoped status, flags apply to its tracked files
        if os.path.isdir(full) and not os.path.islink(full):
            continue
        if sp in tracked or _is_wild(sp):
            continue
        if os.path.lexists(full) and _exact_case(full):
            dirty.add(sp)  # present on disk, not in the index: untracked (ignored or not)
    return {q: blob_hash(g, q) for q in sorted(dirty) if any(matches(q, sp) for sp in specs)}


def index_mismatch(g, index_doc, dirty_now_proj, scope_top):
    """§3 "A dirty index": does the symbol index read different working-tree bytes than
    the binding captures, on the unit scope ∩ the index's enumerated file set? A key
    absent from either map is CLEAN on that side. An index with no dirty map (an older
    plugin) cannot vouch for dirty code files. One rule for the writer and rebind-units."""
    rec = index_doc.get("dirty")
    files = index_doc.get("files")
    dom = set(files) if isinstance(files, list) else (set(rec or {}) | {s.get("file", "") for s in (index_doc.get("symbols") or [])})
    in_scope = lambda p: any(matches(to_top(g, p) or "", sp) for sp in scope_top)
    if not isinstance(rec, dict):
        return any(p in dom and in_scope(p) for p in dirty_now_proj)
    cand = {p for p in set(rec) | set(dirty_now_proj) if p in dom and in_scope(p)}
    return any(rec.get(p) != dirty_now_proj.get(p) for p in cand)


def dirty_paths(g, vaults):
    specs = set()
    for v in vaults:
        for u in v["units"]:
            specs |= u["scope"]
        if v["classic"]:
            specs |= v["classic"]["scope"]
    return set(dirty_map(g, specs))


# ── the BOLTS gate leg (Slice 2, §8) ─────────────────────────────────────────
BINDING_V2_FIELDS = ("based_on_sha", "scope", "own_targets", "unit_sha256", "dirty", "index_head", "claims")
# reason 6 is not exhaustible: the writer hashes the unit AFTER its R1 rewrite, so a
# unit change at the re-bind HEAD is always a NEW edit a 3.9b clears (never a failed one)
EXHAUSTIBLE = ("stamp_null", "diverged", "stamp_unreachable", "binding_stale", "uncommitted_in_scope")
_BSHA_RE = re.compile(r"(?m)^\s*binding_sha256:\s*([0-9a-f]{64})\s*$")


def _sha256_file(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def binding_scope_top(g, doc):
    return {to_top(g, p) for p in (doc.get("scope") or []) if isinstance(p, str)} - {None}


def other_vault_targets(root, vault_dir, uid):
    """own_targets of same-ID units in OTHER vaults (the collision switch-off)."""
    import unit_claims
    out = set()
    me = os.path.realpath(vault_dir)
    for vd in vs.vaults(root):
        if os.path.realpath(vd) == me:
            continue
        uf = vs.unit_file(vd, uid)
        if uf:
            try:
                fm, _ = unit_claims.fm_block(open(uf, encoding="utf-8", errors="replace").read())
            except OSError:
                continue
            out |= {vs.norm(root, t["path"]) for t in unit_claims.parse_targets(fm)} - {None}
    return out


def gate_check(root, vault_dir, uid, prompt_path=None):
    """→ (reason | None, detail). Reasons 1–9 of §8 in table order; a hit on an
    EXHAUSTIBLE reason at the HEAD a 3.9b re-bind already bound at becomes
    `rebind_exhausted`. A git failure raises GitError (the caller denies
    `not_evaluated`); no `.git` at all → (None, {}) (the gate does not deny)."""
    root = os.path.abspath(root)
    g = find_git(root)
    if not g:
        return None, {}
    head, _ = read_head(g)
    if not head:
        raise GitError("HEAD does not resolve")
    bj = os.path.join(vault_dir, "bolts", uid, "binding.json")
    if not os.path.isfile(bj):
        return "binding_absent", {}
    try:
        raw = open(bj, "rb").read()
        doc = json.loads(raw.decode("utf-8"))
    except (OSError, ValueError, UnicodeDecodeError):
        return "binding_unparseable", {}
    if not isinstance(doc, dict) or not isinstance(doc.get("scope"), list):
        return "binding_unparseable", {}
    if doc.get("schema") != "unit-binding/2" or any(k not in doc for k in BINDING_V2_FIELDS):
        return "binding_legacy", {}
    exhausted = bool(doc.get("rebind_head")) and doc.get("rebind_head") == head

    def hit(reason, **d):
        if exhausted and reason in EXHAUSTIBLE:
            d["cause"] = reason
            return "rebind_exhausted", d
        return reason, d

    stamp = doc.get("based_on_sha")
    if not (isinstance(stamp, str) and HEX_FULL.match(stamp)):
        return hit("stamp_null", null_cause=doc.get("null_cause") or "no stamp")
    if prompt_path is not None:
        try:
            m = _BSHA_RE.search(open(prompt_path, encoding="utf-8", errors="replace").read())
        except OSError:
            m = None
        if not m or m.group(1) != hashlib.sha256(raw).hexdigest():
            return "dispatch_prompt_stale", {}
    uf = vs.unit_file(vault_dir, uid)
    if not uf or _sha256_file(uf) != doc.get("unit_sha256"):
        return hit("unit_changed_since_bind")
    anc = _ancestry(g, head, stamp)
    if anc == "diverged":
        return hit("diverged", stamp=stamp)
    if anc == "unreachable":
        return hit("stamp_unreachable", stamp=stamp)
    if anc in ("error", "skipped"):
        raise GitError("ancestry of %s undecidable" % stamp[:8])
    scope = binding_scope_top(g, doc)
    if anc == "ancestor" and scope:
        _, out = git(g["top"], ["diff", "--no-relative", "--no-renames", "--name-only", "-z", stamp, head, "--"] + pathspecs(scope))
        changed = sorted(q for q in out.split("\0") if q and any(matches(q, sp) for sp in scope))
        if changed:
            try:
                commits = log_range(g, stamp, head, changed)
            except GitError as e:
                if "diff-merges" not in str(e):
                    raise  # a timeout / lock / access failure stays not_evaluated (§8)
                commits = []  # §14 git floor (< 2.31): nothing is dropped → binding_stale; a 3.9b clears it
            att = Attributor(root, g, bolt_attrib.bound_vault_roots(root), commits)
            u = {"uid": uid, "targets": set(doc.get("own_targets") or []),
                 "bolt_dir": os.path.relpath(os.path.join(vault_dir, "bolts", uid), root).replace("\\", "/")}
            foreign = other_vault_targets(root, vault_dir, uid)
            stale = []
            for q in changed:
                p = to_proj(g, q)
                if bolt_attrib.hits_target(p, u["targets"]) and not bolt_attrib.hits_target(p, foreign):
                    touched, all_own = att.only_own(q, u)
                    if touched and all_own:
                        continue
                stale.append(q)
            if stale:
                seen, cm = set(), []
                for c in commits:
                    if c["sha"] not in seen and any(q in c["files"] for q in stale):
                        seen.add(c["sha"])
                        cm.append("%s %s" % (c["sha"][:7], sanitize(c["subject"], SUBJ_MAX)))
                return hit("binding_stale", stamp=stamp, paths=[to_proj(g, q) for q in stale], commits=cm[:SHOW_COMMITS])
    now = dirty_map(g, scope)
    snap = {}
    for p, h in (doc.get("dirty") or {}).items():
        q = to_top(g, p)
        if q:
            snap[q] = h
    if now != snap:
        diff = sorted(set(now) ^ set(snap) | {q for q in set(now) & set(snap) if now[q] != snap[q]})
        return hit("uncommitted_in_scope", paths=[to_proj(g, q) for q in diff])
    return None, {}


def gate_main(argv):
    root = vault = unit = prompt = None
    for a in argv:
        if a.startswith("--cwd="):
            root = a.split("=", 1)[1]
        elif a.startswith("--vault="):
            vault = a.split("=", 1)[1]
        elif a.startswith("--unit="):
            unit = a.split("=", 1)[1]
        elif a.startswith("--prompt="):
            prompt = a.split("=", 1)[1]
    try:
        reason, detail = gate_check(root, vault, unit, prompt)
    except GitError as e:
        reason, detail = "not_evaluated", {"error": str(e)}
    sys.stdout.write(json.dumps({"reason": reason, "detail": detail}) + "\n")
    return 0


# ── rendering ────────────────────────────────────────────────────────────────
def _files_txt(g, qs):
    shown = [sanitize(to_proj(g, q), PATH_MAX) for q in qs[:SHOW_FILES]]
    more = len(qs) - len(shown)
    return ", ".join(shown) + (" +%d" % more if more > 0 else "")


def _commits_txt(commits, qs):
    seen, out = set(), []
    for c in commits:
        if c["sha"] in seen or not any(q in c["files"] for q in qs):
            continue
        seen.add(c["sha"])
        out.append("%s %s" % (c["sha"][:7], sanitize(c["subject"], SUBJ_MAX)))
        if len(out) >= SHOW_COMMITS:
            break
    return "; ".join(out)


HINT_TAG = {"prehonest": "pre-honest stamp: hint", "model": "stamp model-typed: hint"}


def vault_view(g, head, v, res, dirty):
    """→ dict(name, word, line, extra[], collapsible, trusted, prefixes)"""
    name = sanitize(v["name"], 40)
    members = [m for m in v["units"]] + ([v["classic"]] if v["classic"] else [])
    scope = set()
    for m in members:
        scope |= m["scope"]
    d = sorted(q for q in dirty if any(matches(q, sp) for sp in scope))
    dtxt = " · dirty %d (as of check)" % len(d) if d else ""
    trusts = {m["trust"] for m in members if m.get("stamp")}
    hint = next((HINT_TAG[t] for t in ("model", "prehonest") if t in trusts), None)
    trusted = bool(members) and trusts == {"script"} and all(m.get("stamp") for m in members)
    pending = [m for m in v["units"] if not m.get("implemented")]
    live = pending + ([v["classic"]] if v["classic"] else [])
    done_only = not live and bool(v["units"])
    if done_only:
        live = list(v["units"])  # every unit is bolted: the vault's status is its done units'
    extra = []
    subs = v["classic"]["subunits"] if v["classic"] else []
    impl = [(m["uid"], m["own_changed"]) for m in v["units"] + subs if m.get("implemented") and m.get("own_changed")]
    if impl:
        extra.append("%s: implemented code changed since bolt: %s" % (
            name, ", ".join("%s (%s)" % (u, _files_txt(g, qs)) for u, qs in impl[:3])))
    # pending units whose own targets moved under someone else count as STALE
    for m in pending:
        if m.get("own_changed"):
            m["stale"] = sorted(set(m["stale"]) | set(m["own_changed"]))
    if v["unbound"]:
        extra.append("%s: %d unbound unit(s) — no stamp, claims are hints" % (name, v["unbound"]))
    prefixes = set()
    for q in scope:
        if q.startswith(vs.GLOB_PREFIX):
            continue
        parts = to_proj(g, q).split("/")
        if parts[0] in ("", ".."):
            continue
        prefixes.add("/".join(parts[:2]) if len(parts) >= 3 else parts[0])
    base = {"name": name, "extra": extra, "trusted": trusted, "prefixes": sorted(prefixes), "dirty": len(d)}
    if not live:
        # no bound unit and no classic binding: only the unbound count speaks
        return dict(base, word="unbound", line="", collapsible=False)

    def eff(m):
        # a done unit's changes surface through the "implemented code changed" line;
        # D4: done units are never re-grounded, so they never make the vault STALE
        if m.get("uid") and m.get("implemented") and m["verdict"] == "changed":
            return "fresh"
        return m["verdict"]
    verdicts = [eff(m) for m in live]
    tag = " (%s)" % hint if hint else ""
    for bad in ("unreachable", "diverged"):
        hit = [m for m in live if m["verdict"] == bad]
        if hit:
            s8 = hit[0]["stamp"][:8]
            txt = ("STALE · stamp unreachable (history rewritten or gc) — whole scope" if bad == "unreachable"
                   else "STALE · HEAD does not descend from stamp %s (rebase/branch switch) — whole scope" % s8)
            return dict(base, word="STALE", line="%s: %s%s%s" % (name, txt, dtxt, tag), collapsible=False)
    stale_m = [m for m in live if eff(m) == "changed" and m["stale"]]
    if stale_m:
        qs = sorted({q for m in stale_m for q in m["stale"]})
        stamp8 = stale_m[0]["stamp"][:8]
        cm = _commits_txt(res[stale_m[0]["stamp"]]["commits"], qs)
        pu = [m["uid"] for m in stale_m if m.get("uid")]
        pu += [s["uid"] for s in subs if not s.get("implemented") and any(matches(q, sp) for q in qs for sp in s["scope"])]
        line = "%s: STALE since %s · %d file(s): %s%s%s%s%s" % (
            name, stamp8, len(qs), _files_txt(g, qs), (" · " + cm) if cm else "",
            (" · pending: " + ",".join(pu[:6])) if pu else "", dtxt, tag)
        return dict(base, word="STALE since %s%s" % (stamp8, tag), line=line, collapsible=False)
    if any(x in ("error", "skipped") for x in verdicts):
        return dict(base, word="UNVERIFIED", line="%s: UNVERIFIED (git error)%s" % (name, dtxt), collapsible=False)
    if all(x == "unstamped" for x in verdicts):
        nulls = [m for m in live if m.get("trust") == "null"]
        if nulls:
            cause = sanitize(nulls[0].get("cause") or "stamp null", 40)
            return dict(base, word="stamp null", line="%s: stamp null (%s) — claims are hints; re-bound at dispatch%s" % (name, cause, dtxt),
                        collapsible=False)
        return dict(base, word="UNSTAMPED", line="%s: UNSTAMPED (no script stamp) — its claims are hints%s" % (name, dtxt),
                    collapsible=False)
    if hint:
        h8 = next(m["stamp"][:8] for m in live if m.get("stamp"))
        return dict(base, word="no scope change since %s (%s)" % (h8, hint),
                    line="%s: no scope change since %s (%s)%s" % (name, h8, hint, dtxt), collapsible=False)
    if any(x == "unstamped" for x in verdicts):
        return dict(base, word="UNSTAMPED", line="%s: UNSTAMPED (no script stamp) — its claims are hints%s" % (name, dtxt),
                    collapsible=False)
    return dict(base, word="FRESH", line="%s: FRESH%s" % (name, dtxt), collapsible=not d and not extra)


def run(root, want_upstream=True):
    root = os.path.abspath(root)
    g = find_git(root)
    if not g:
        return {"nogit": True}
    head, branch = read_head(g)
    r = {"nogit": False, "git": g, "head": head, "branch": branch or "detached", "vaults": [], "up": None,
         "root": root, "inputs": []}
    if not head:
        return r
    r["inputs"] = vs.vaults(root)
    r["gen0"] = input_gen(root, r["inputs"])
    vaults, bound_roots = collect(root, g)
    try:
        res = evaluate(root, g, head, vaults, bound_roots)
    except GitError:
        res = {}
        for v in vaults:
            for m in v["units"] + ([v["classic"]] if v["classic"] else []):
                m["verdict"] = "error" if m.get("stamp") else "unstamped"
                m.setdefault("stale", [])
                m.setdefault("own_changed", [])
    try:
        dirty = dirty_paths(g, vaults)
    except GitError:
        dirty = set()
    r["vaults"] = [vault_view(g, head, v, res, dirty) for v in vaults]
    r["scope"] = {}
    for v, vv in zip(vaults, r["vaults"]):
        sc = set()
        for m in v["units"] + ([v["classic"]] if v["classic"] else []):
            sc |= m["scope"]
        r["scope"][vv["name"]] = sorted(sc)
    if want_upstream:
        try:
            up = upstream(g, branch)
            if up and up[1] != head:
                allsc = sorted({q for s in r["scope"].values() for q in s})
                if allsc:
                    _, out = git(g["top"], ["log", "--no-relative", "-n", str(UP_DEPTH), "--format=%x1e%H%x1d", "--name-only",
                                            "%s..%s" % (head, up[1]), "--"] + pathspecs(allsc))
                    hit_v, n = [], 0
                    for chunk in out.split("\x1e"):
                        if not chunk.strip():
                            continue
                        files = [f for f in chunk.partition("\x1d")[2].split("\n") if f.strip()]
                        touched = [name for name, sc in r["scope"].items() if any(matches(f, sp) for f in files for sp in sc)]
                        if touched:
                            n += 1
                            hit_v += [t for t in touched if t not in hit_v]
                    if n:
                        r["up"] = "upstream %s (%s): %d commit(s) touching %s not pulled" % (
                            sanitize(up[0], 60), _age(up[2]), n, ", ".join(hit_v[:4]))
        except GitError:
            pass
    return r


def header(r, cached_at=None):
    if r.get("nogit"):
        return "mega-sdd state · no git repository at this project root:"
    if not r.get("head"):
        return "mega-sdd state @ (no commits yet) (%s):" % sanitize(r.get("branch") or "", 60)
    sha, br = r["head"][:12], sanitize(r["branch"], 60)
    if cached_at:
        return "mega-sdd state @ %s (%s) · as of check %s; later moves checked by content only:" % (sha, br, cached_at[:8])
    if not [v for v in r["vaults"] if v["line"]]:
        return "mega-sdd state @ %s (%s):" % (sha, br)
    if all(v["trusted"] for v in r["vaults"] if v["line"]):
        return "mega-sdd state @ %s (%s) · verified at this HEAD:" % (sha, br)
    return "mega-sdd state @ %s (%s) · checked at this HEAD (hint-tier stamps marked):" % (sha, br)


def render_lines(vaults, up, cwd_rel):
    """The vault lines of the block: cwd's vault first, FRESH collapse, ≤6 lines."""
    def mine(v):
        return bool(cwd_rel) and any(cwd_rel == p or cwd_rel.startswith(p + "/") for p in v["prefixes"])
    ordered = sorted(vaults, key=lambda v: (0 if mine(v) else 1, v["name"]))
    fresh = [v["name"] for v in ordered if v["collapsible"]]
    lines = []
    if fresh:
        lines.append("FRESH: " + ", ".join(fresh))
    for v in ordered:
        if v["collapsible"]:
            continue
        if v["line"]:
            lines.append(v["line"])
        lines.extend(v["extra"])
    if up:
        lines.append(up)
    if len(lines) > MAX_LINES:
        more = len(lines) - (MAX_LINES - 1)
        lines = lines[:MAX_LINES - 1] + ["+%d more line(s) — details at M/L entry" % more]
    return ["- " + ln for ln in lines]


def render(r, cwd_rel=""):
    head = header(r)
    lines = render_lines(r.get("vaults") or [], r.get("up"), cwd_rel)
    block = "\n".join([head] + lines + [RULE_LINE])
    if len(block.encode("utf-8")) > BLOCK_MAX:
        short = ["- %s: %s" % (v["name"], v["word"]) for v in (r.get("vaults") or []) if v["word"]]
        block = "\n".join([head] + short[:MAX_LINES] + [RULE_LINE])
    return block


# ── view cache (per-worktree git dir; never tracked) ─────────────────────────
WATCH_DIRS = (os.path.join(".mega-sdd", "vaults"), os.path.join("docs", "mega-sdd", "vaults"), "vaults")


def input_files(root, vdirs):
    """Every input the view is derived from — the SessionStart hook walks the same
    set with builtin `-nt` tests (a HIT needs the cache strictly newer than all)."""
    out = [os.path.join(root, w) for w in WATCH_DIRS if os.path.isdir(os.path.join(root, w))]
    for d in vdirs:
        out += [d, os.path.join(d, "bolts"), os.path.join(d, "units"), os.path.join(d, "binding.json")]
        out += glob.glob(os.path.join(d, "bolts", "U-*", "binding.json"))
        out += glob.glob(os.path.join(d, "units", "U-*.md")) + glob.glob(os.path.join(d, "units", "U-*", "unit.md"))
    return out


def input_gen(root, vdirs):
    gen = 0.0
    for p in input_files(root, vdirs):
        try:
            gen = max(gen, os.path.getmtime(p))
        except OSError:
            pass
    return gen


def write_view(r):
    if r.get("nogit") or not r.get("head"):
        return False
    g = r["git"]
    path = os.path.join(g["gitdir"], CACHE_NAME)
    # an input rewritten while the engine ran would leave a cache NEWER than that
    # input — a false HIT later; skip the write, the next run recomputes
    if input_gen(r["root"], r.get("inputs", [])) != r.get("gen0"):
        return False
    lines = ["v=1", "checked=" + r["head"], "branch=" + sanitize(r["branch"], 60), "top=" + g["top"],
             "prefix=" + g["prefix"], "hdr=" + header(r)]
    for w in WATCH_DIRS:
        if os.path.isdir(os.path.join(r["root"], w)):
            lines.append("watch=" + os.path.join(r["root"], w))
    if r.get("up"):
        # the upstream line carries a count + fetch age: a later fetch must miss the HIT
        for f in (os.path.join(g["common"], "FETCH_HEAD"), os.path.join(g["common"], "packed-refs")):
            if os.path.isfile(f):
                lines.append("watch=" + f)
    for d in r.get("inputs", []):
        lines.append("vdir=" + d)
    for v in r["vaults"]:
        lines.append("vault=" + "\x1f".join([v["name"], v["word"], "1" if v["collapsible"] else "0",
                                             " ".join(v["prefixes"]), v["line"]]))
        for x in v["extra"]:
            lines.append("xline=" + "\x1f".join([v["name"], x]))
    if r.get("up"):
        lines.append("up=" + r["up"])
    lines.append("end=" + r["head"])
    scope = ["v=1", "checked=" + r["head"]]
    for name, sc in (r.get("scope") or {}).items():
        for sp in pathspecs(sc):
            scope.append("s=" + name + "\x1f" + sp)
    scope.append("end=" + r["head"])
    try:
        for p, body in ((path + ".scope", scope), (path, lines)):
            tmp = p + ".tmp.%d" % os.getpid()
            with open(tmp, "w", encoding="utf-8", newline="\n") as f:
                f.write("\n".join(body) + "\n")
            os.replace(tmp, p)
        try:
            os.remove(path + ".overlay")
        except OSError:
            pass
        return True
    except OSError:
        return False


def main(argv):
    root, do_print, cwd_rel = ".", False, ""
    for a in argv:
        if a.startswith("--cwd="):
            root = a.split("=", 1)[1]
        elif a == "--print":
            do_print = True
        elif a.startswith("--cwd-rel="):
            cwd_rel = a.split("=", 1)[1]
    try:
        r = run(root)
        write_view(r)
        if do_print:
            sys.stdout.write(render(r, cwd_rel) + "\n")
    except Exception as e:  # the view is advisory: never a traceback, never a non-zero exit
        if do_print:
            sys.stdout.write("mega-sdd state · freshness check failed (%s) — treat memory/vault claims as hints.\n%s\n"
                             % (type(e).__name__, RULE_LINE))
    return 0


if __name__ == "__main__":
    if "--gate" in sys.argv[1:]:
        sys.exit(gate_main([a for a in sys.argv[1:] if a != "--gate"]))
    sys.exit(main(sys.argv[1:]))
