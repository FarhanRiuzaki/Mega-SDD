"""vault_scope.py — the ONE scope grammar of the state anchor (spec
docs/superpowers/specs/2026-09-25-state-anchor-design.md §4).

A unit's scope is the set of code paths its claims are ABOUT; a vault's scope is
the union over its units plus its classic binding.json anchors. The grammar is
the path set sync-intersect.sh and rebind-units.sh already compute (a parity
test pins vault_scope ⊇ theirs), with three widenings they lack:
  * root-escaping paths (`../packages/shared/x.ts`, absolute) are RETURNED, never
    dropped — the engine diffs them from the worktree top;
  * both unit shapes (`units/U-*.md`, `units/U-*/unit.md`) and both binding
    shapes (per-unit bolts/U-*/binding.json, classic <vault>/binding.json);
  * the root `vaults/*` generation state_probes.py recognises and
    vault_layouts.vault_prefixes() does not list.
Slash-less anchor pieces (`UserController.php:45`) keep the basename lane of
sync-intersect.sh as the pathspec `:(glob)**/<Name>`. `.mega-sdd/**` is never
in scope (it is derived state, not code).

Consumers import via:  sys.path.insert(0, <plugin>/scripts/_lib)
"""
import glob
import json
import os
import re

import vault_layouts

# Same token literal as sync-intersect.sh / rebind-units.sh / derive-unit-claims.sh
# (Next.js `(group)`, `[id]`, `@slot` segments are legal path segments).
ANCHOR_TOKEN_RE = re.compile(
    r"(?<![\w:/])((?:(?:[\w.\-]+|\([\w.\-]+\)|\[[\w.\-]+\]|@[\w.\-]+)/)*[\w.\-]+\.[A-Za-z]\w{0,7})(?::\d+(?:-\d+)?)?\b")
CLAIM_RE = re.compile(r'^-\s+(C-U[\w-]+)\s+"(.+?)"\s+—\s+expect:\s+(.+?)\s*$')
SYMBOL_EXPECT_RE = re.compile(r"^([^\s:]+):[A-Za-z_]\w*$")
GLOB_PREFIX = ":(glob)**/"


def _vault_dirs_patterns(root):
    return tuple(vault_layouts.vault_prefixes(root)) + (os.path.join(root, "vaults", "*"),)


def _is_vault(d):
    if not os.path.isdir(d):
        return False
    return (os.path.isdir(os.path.join(d, "units")) or os.path.isdir(os.path.join(d, "bolts"))
            or os.path.isfile(os.path.join(d, "binding.json")) or os.path.isfile(os.path.join(d, "binding.md")))


def vaults(root):
    """Every vault dir under `root` across all layouts, realpath-deduped, sorted."""
    got = {}
    for pat in _vault_dirs_patterns(root):
        for d in glob.glob(pat):
            if _is_vault(d):
                got.setdefault(os.path.realpath(d), d)
    return [got[k] for k in sorted(got)]


def vault_name(root, vdir):
    """Short display name: the vault dir basename, or its root-relative path when
    two vaults would share a basename."""
    return os.path.basename(os.path.normpath(vdir))


def unit_ids(vdir):
    ids = {os.path.basename(p)[:-3] for p in glob.glob(os.path.join(vdir, "units", "U-*.md"))}
    ids |= {os.path.basename(os.path.dirname(p)) for p in glob.glob(os.path.join(vdir, "units", "U-*", "unit.md"))}
    return sorted(ids)


def unit_file(vdir, uid):
    for p in (os.path.join(vdir, "units", uid + ".md"), os.path.join(vdir, "units", uid, "unit.md")):
        if os.path.isfile(p):
            return p
    return None


def norm(root, p):
    """Project-relative normal form. Root-escaping paths come back as `../…`
    (normalised), never None; empty / prose → None; `.mega-sdd/**` → None."""
    p = str(p).strip().strip("'\"`").replace("\\", "/")
    if not p or p in ("—", "n/a"):
        return None
    if re.match(r"^[A-Za-z]:/", p) or os.path.isabs(p):
        p = os.path.relpath(p, root).replace("\\", "/")
    p = os.path.normpath(p).replace("\\", "/")
    if p in (".", ""):
        return None
    if p == ".mega-sdd" or p.startswith(".mega-sdd/"):
        return None
    return p


def _frontmatter(text):
    m = re.match(r"\A---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(?:\r?\n|\Z)", text, re.S)
    return (m.group(1), text[m.end():]) if m else ("", text)


def _section(body, name):
    m = re.search(r"(?ims)^##[ \t]+%s\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)" % re.escape(name), body)
    return m.group(1) if m else ""


def _block_values(fm, key, field):
    """`field:` values of a block list-of-maps under top-level `key:`; also the
    inline `key: [a, b]` form."""
    out = []
    m = re.search(r"(?m)^%s[ \t]*:[ \t]*(.*)$" % re.escape(key), fm)
    if not m:
        return out
    inline = m.group(1).strip()
    if inline and inline != "[]":
        if inline.startswith("[") and inline.endswith("]"):
            out.extend(x for x in (i.strip() for i in inline[1:-1].split(",")) if x)
        return out
    for line in fm[m.end():].split("\n"):
        if line.strip() == "" or re.match(r"^[ \t]", line):
            fm_ = re.search(r"(?:^|[\s-])%s[ \t]*:[ \t]*(.+?)[ \t]*$" % re.escape(field), line)
            if fm_:
                out.append(fm_.group(1))
        else:
            break
    return out


def _add_piece(root, piece, paths, globs):
    """One anchor/expect piece → exact path or basename glob. Pieces with no
    '/', ':' or dot-extension are prose and dropped (sync-intersect rule)."""
    piece = piece.strip()
    if not piece:
        return
    if not (":" in piece or "/" in piece or re.search(r"\.[A-Za-z0-9]+$", piece)):
        return
    piece = re.sub(r":\d+(-\d+)?$", "", piece)
    sm = SYMBOL_EXPECT_RE.match(piece)
    if sm and "." in sm.group(1):
        piece = sm.group(1)
    p = norm(root, piece)
    if not p:
        return
    if "/" in p:
        paths.add(p)
    elif re.search(r"\.[A-Za-z0-9]+$", p):
        globs.add(GLOB_PREFIX + p)


def unit_scope(root, vdir, uid):
    """{"paths": set of project-relative exact paths (may start with ../),
        "globs": set of `:(glob)**/<Name>` pathspecs,
        "targets": set of the unit's own target_files paths}"""
    paths, globs, targets = set(), set(), set()
    uf = unit_file(vdir, uid)
    if uf:
        try:
            text = open(uf, encoding="utf-8", errors="replace").read()
        except OSError:
            text = ""
        fm, body = _frontmatter(text)
        for t in _block_values(fm, "target_files", "path"):
            p = norm(root, t)
            if p:
                paths.add(p)
                targets.add(p)
        for f in _block_values(fm, "existing_interfaces", "file"):
            p = norm(root, f)
            if p:
                paths.add(p)
        for am in ANCHOR_TOKEN_RE.finditer(_section(body, "Anchors")):
            _add_piece(root, am.group(0), paths, globs)
        for ln in _section(body, "Claims").splitlines():
            m = CLAIM_RE.match(ln.strip())
            if m:
                exp = m.group(3).split("—")[0].strip()
                _add_piece(root, exp, paths, globs)
    bj = os.path.join(vdir, "bolts", uid, "binding.json")
    if os.path.isfile(bj):
        try:
            doc = json.load(open(bj, encoding="utf-8"))
        except (OSError, ValueError):
            doc = {}
        for c in (doc.get("claims") or []) if isinstance(doc, dict) else []:
            if not isinstance(c, dict):
                continue
            for field in ("anchor", "expect"):
                v = c.get(field)
                if v:
                    for piece in re.split(r"\s*\+\s*", str(v)):
                        _add_piece(root, piece, paths, globs)
    return {"paths": paths, "globs": globs, "targets": targets}


def classic_scope(root, vdir):
    """Anchor paths of a classic whole-vault <vault>/binding.json."""
    paths, globs = set(), set()
    bj = os.path.join(vdir, "binding.json")
    if os.path.isfile(bj):
        try:
            doc = json.load(open(bj, encoding="utf-8"))
        except (OSError, ValueError):
            doc = {}
        for c in (doc.get("claims") or []) if isinstance(doc, dict) else []:
            if isinstance(c, dict) and c.get("anchor"):
                for piece in re.split(r"\s*\+\s*", str(c["anchor"])):
                    _add_piece(root, piece, paths, globs)
    return {"paths": paths, "globs": globs}


def vault_scope(root, vdir):
    paths, globs = set(), set()
    for uid in unit_ids(vdir):
        s = unit_scope(root, vdir, uid)
        paths |= s["paths"]
        globs |= s["globs"]
    c = classic_scope(root, vdir)
    return {"paths": paths | c["paths"], "globs": globs | c["globs"]}
