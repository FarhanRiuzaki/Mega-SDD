"""state_probes.py — the ONE CWD probe library (P1, spec
2026-07-19-v5-execution-spec.md decision 8; research §3).

Shared by `derive-state.sh` (the routing state digest), `validate-preflight.sh`
(the FATAL preflight gate), and the session-start staleness notice via the
MEGA_SDD_LIB_DIR sys.path pattern — the W2/W5 shared-grammar precedent
(`binding_md.py` / `vault_md.py`) applied to the CWD-inspection surface: the
10-probe routing inspection and the preflight predicates can never re-diverge
again (the P0 `has_vault` fork — a 7-file vault without vault.json invisible to
routing yet visible to preflight — was exactly this failure class).

Two layers, deliberately distinct and BOTH in this one file so any residual
asymmetry is visible, never accidental:

  1. Preflight-parity predicates — `has_vault()` / `has_bound_or_vault()` /
     `has_units()` / `has_codebase_map()`: byte-identical semantics to the
     functions `validate-preflight.sh` shipped inline pre-P1 (canonical
     `.mega-sdd/vaults/` only for the vault predicates — preflight's historical
     FATAL contract; the map predicate probes canonical → legacy repo-root).
  2. Rich probes — the routing-rules §CWD inspection set (all path
     GENERATIONS per `references/paths.md §Read-side compatibility`). Each
     probe returns plain data — no policy.

Policy (position enum + proposed_next chain per the routing decision table)
lives ONLY in `derive()` at the bottom, so probes stay reusable data sources.

Binding/vault markdown is parsed via the shared grammars (`binding_md`,
`vault_md`) — never a re-implemented parser. No fabrication: absent facts stay
None/0/absent, never guessed (anti-halu invariant 5).
"""

import glob
import json
import os
import re
import subprocess
from datetime import datetime, timezone

import binding_md
import vault_md

# ── Path generations (references/paths.md §Read-side compatibility;
#    orchestrate-flow/references/routing-rules.md §CWD inspection) ────────────

# Vault roots, priority order. Layout tags mirror routing-rules probe 2:
# canonical accepts vault.json OR bare 0[0-6]-*.md docs; the legacy
# generations require vault.json (first hit wins).
VAULT_ROOT_GENERATIONS = (
    ("canonical", os.path.join(".mega-sdd", "vaults")),
    ("legacy-docs", os.path.join("docs", "mega-sdd", "vaults")),
    ("legacy-root", "vaults"),
)

# codebase-map, priority order (routing-rules probe 7; paths.md).
CODEBASE_MAP_GENERATIONS = (
    os.path.join(".mega-sdd", "codebase", "codebase-map.md"),
    "codebase-map.md",
)

# Knowledge-base README, the 4 generations (routing-rules probe 8; paths.md).
KB_README_GENERATIONS = (
    os.path.join(".mega-sdd", "knowledge-base", "README.md"),
    os.path.join("docs", "knowledge-base", "README.md"),
    os.path.join("docs", "mega-sdd", "knowledge-base", "README.md"),
    os.path.join("old-reference", "knowledge-base", "README.md"),
)

# Framework/package manifests (session-start Guard-1 list == auto.md starterkit
# probe superset). `.git` is probed separately via probe_git.
# P2 widened to the ecosystems the pack registry + scan Step 2 already
# enumerate — a .NET repo with two `ready` packs must not halt
# no_starterkit_detected because the probe never looked for *.csproj.
MANIFEST_SIGNALS = (
    "composer.json", "package.json", "Gemfile", "Cargo.toml", "go.mod",
    "build.gradle", "pom.xml", "requirements.txt", "pyproject.toml",
    "build.gradle.kts", "build.sbt", "Package.swift", "mix.exs",
    "pubspec.yaml", "Pipfile",
)
# Root-only glob manifests (fnmatch against root dirlist; matched REAL
# filenames are reported, so consumers keep list-of-files semantics).
MANIFEST_GLOB_SIGNALS = ("*.csproj", "*.sln")

# A pack may declare one canonical manifest while real repos use a sibling
# (the prose Step-2 table always allowed both) — deterministic alternates,
# checked ONLY when the canonical file is absent.
MANIFEST_ALTERNATES = {
    "pyproject.toml": ("requirements.txt", "Pipfile"),
    "build.gradle": ("build.gradle.kts",),
}

# Code-file extensions for greenfield/brownfield detection (routing-rules
# §Greenfield vs brownfield detection: ".{php,js,ts,py,rs,go,rb} etc." —
# the etc. enumerated tech-agnostically per CLAUDE.md).
CODE_EXTS = {
    ".php", ".js", ".ts", ".jsx", ".tsx", ".vue", ".py", ".rs", ".go", ".rb",
    ".java", ".kt", ".cs", ".swift", ".scala", ".ex", ".exs", ".c", ".cpp",
    ".h", ".hpp",
}
_CODE_SKIP_DIRS = {
    ".git", "node_modules", "vendor", ".mega-sdd", "__pycache__", ".venv",
    "venv", "dist", "build", "target", ".next", ".idea", ".vscode",
}

# `.dirty-paths.jsonl` journal (Mode D change signal).
DIRTY_JOURNAL_REL = os.path.join(".mega-sdd", "codebase", ".dirty-paths.jsonl")

# Foreign-SDD tool signals (P2 adoption gates, spec 2026-07-19-v5-execution-spec.md
# P2 row; research §3 entry matrix): spec-kit / Kiro / OpenSpec conventions plus a
# generic `specs/*.md` frontmatter sniff. Recognition only — the adoption verdict
# itself is certify-artifact.sh's job (routing proposes the DEMOTE lane; decision 7:
# a DEMOTE under --auto is ALWAYS a confirmed C2 halt, never silent).
FOREIGN_SDD_DIR_SIGNALS = (
    ("spec-kit", ".specify"),
    ("kiro", os.path.join(".kiro", "specs")),
    ("openspec", "openspec"),
    ("openspec", ".openspec"),
)

_SHA40_RE = re.compile(r"[0-9a-f]{40}")
_STAMP_RE = re.compile(r"(?m)^last_scanned_commit:\s*(\S+)\s*$")
_PRD_NAME_RE = re.compile(r"(?:^|[-_.])(?:prd|brd)(?:[-_.]|$)", re.IGNORECASE)
_PENDING_SYNC_OPEN_RE = re.compile(r"(?m)^- \[ \]")
_SQUAD_ID_RE = re.compile(r"(?m)^\s*-\s+id\s*:")


def _iso(ts):
    return datetime.fromtimestamp(ts, timezone.utc).isoformat().replace(
        "+00:00", "Z"
    )


# ── Layer 1: preflight-parity predicates ─────────────────────────────────────
# IDENTICAL semantics to the inline functions validate-preflight.sh carried
# pre-P1 (Iter-79 O-1 + S4 BC-PREFLIGHT-LEGACY). Vault predicates probe the
# CANONICAL root only — preflight's historical FATAL contract. Pinned by
# tests/fixtures/code-delivery/preflight/verify.sh + god-review-s4 4C +
# tests/state/test-derive-state.sh parity assertions.


def _canonical_vault_root(cwd):
    return os.path.join(cwd, ".mega-sdd", "vaults")


def has_vault(cwd):
    vault_root = _canonical_vault_root(cwd)
    return bool(
        glob.glob(os.path.join(vault_root, "*", "vault.json")) or
        glob.glob(os.path.join(vault_root, "*", "0[0-6]-*.md"))
    )


def has_bound_or_vault(cwd):
    # Bound copy: canonical <vault>/bound/ (v3.4+) OR legacy <vault>-bound/.
    vault_root = _canonical_vault_root(cwd)
    return has_vault(cwd) or bool(
        glob.glob(os.path.join(vault_root, "*", "bound", "*")) or
        glob.glob(os.path.join(vault_root, "*-bound", "*"))
    )


def has_units(cwd):
    vault_root = _canonical_vault_root(cwd)
    return bool(
        glob.glob(os.path.join(vault_root, "*", "units", "U-*.md")) or
        glob.glob(os.path.join(vault_root, "*", "units", "U-*", "unit.md")) or
        glob.glob(os.path.join(vault_root, "*-bound", "units", "U-*.md")) or
        glob.glob(os.path.join(vault_root, "*-bound", "units", "U-*", "unit.md"))
    )


def has_codebase_map(cwd):
    # S4 BC-PREFLIGHT-LEGACY: probe the SAME order bind-codebase does
    # (SKILL.md §Inputs + paths.md back-compat) — canonical nested path, then
    # the legacy repo-root map.
    return (
        os.path.isfile(os.path.join(cwd, ".mega-sdd", "codebase", "codebase-map.md"))
        or os.path.isfile(os.path.join(cwd, "codebase-map.md"))
    )


# ── Layer 2: rich probes (routing-rules §CWD inspection, all generations) ────


# One level inside dirs whose name case-insensitively matches this FIXED set is
# scanned in addition to the root — teams routinely keep the PRD in a PRD/ or
# docs/ folder (field finding 2026-08-03: a root-only probe missed
# PRD/prd-simkredit.md, mis-deriving the position AND false-failing the
# generate-intent preflight check on the same assumption). Fixed set, one
# level, never a repo walk — determinism over completeness. Matching is done
# against os.listdir's ON-DISK names (round CL-F3: probing constant-cased
# names made macOS find `Docs/` while Linux missed it, AND emitted a
# wrong-case prefix that breaks case-sensitive consumers).
_PRD_SUBDIR_NAMES = {"prd", "docs", "documents", "requirements"}


def probe_prd_candidates(cwd):
    """Probe 1 — PRD/seed detection: `prd.md`, `seed-PRD.md`, or `*.md` PRD
    candidates (basename carries a prd/brd token) at the ROOT plus one level
    inside dirs whose name case-insensitively matches _PRD_SUBDIR_NAMES.
    Returns {"present", "candidates": [relative names], "newest": relname|None,
    "newest_mtime": iso|None}; subdir hits keep their ON-DISK dir prefix
    ("PRD/prd-simkredit.md"); `newest` is the argmax-mtime candidate (the
    prd_revision row must diff the NEW file, not candidates[0] — round CL-F1)."""
    candidates = []
    newest = [None, None]  # [mtime, relname]

    def _scan(dirpath, prefix):
        try:
            names = sorted(os.listdir(dirpath))
        except OSError:
            return
        for name in names:
            if not name.lower().endswith(".md"):
                continue
            path = os.path.join(dirpath, name)
            if not os.path.isfile(path):
                continue
            low = name.lower()
            stem = low[:-3]
            if low in ("prd.md", "seed-prd.md") or _PRD_NAME_RE.search(stem):
                rel = prefix + name
                candidates.append(rel)
                try:
                    mt = os.path.getmtime(path)
                    if newest[0] is None or mt > newest[0]:
                        newest[0] = mt
                        newest[1] = rel
                except OSError:
                    pass

    # Dedupe scanned dirs by (st_dev, st_ino): on a case-insensitive
    # filesystem (macOS default, Windows) PRD/ and prd/ resolve to the SAME
    # directory and a naive loop lists every candidate twice — realpath()
    # does NOT canonicalize case, so inode identity is the key. st_ino == 0
    # means the filesystem reports no inodes (FAT/exFAT, some SMB shares) —
    # never dedupe on it, or every subdir would false-collide with the root
    # and silently regress to the root-only bug (round CL-F5).
    def _dir_id(p):
        try:
            st = os.stat(p)
            if st.st_ino == 0:
                return None
            return (st.st_dev, st.st_ino)
        except OSError:
            return None

    seen_dirs = {_dir_id(cwd)} - {None}
    _scan(cwd, "")
    try:
        entries = sorted(os.listdir(cwd))
    except OSError:
        entries = []
    for name in entries:
        if name.lower() not in _PRD_SUBDIR_NAMES:
            continue
        sub = os.path.join(cwd, name)
        if not os.path.isdir(sub):
            continue
        did = _dir_id(sub)
        if did is not None:
            if did in seen_dirs:
                continue
            seen_dirs.add(did)
        _scan(sub, name + "/")
    return {
        "present": bool(candidates),
        "candidates": candidates,
        "newest": newest[1],
        "newest_mtime": _iso(newest[0]) if newest[0] else None,
    }


def probe_git(cwd):
    """Probe 6a — git repo + HEAD sha in ONE batched call (no subprocess
    storm). {"is_repo": bool, "head": sha|None} — head None when unborn."""
    try:
        r = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--is-inside-work-tree", "HEAD"],
            capture_output=True, text=True, timeout=10,
        )
        lines = [ln.strip() for ln in (r.stdout or "").splitlines()]
    except Exception:
        lines = []
    is_repo = bool(lines) and lines[0] == "true"
    head = None
    if is_repo and len(lines) > 1 and _SHA40_RE.fullmatch(lines[1]):
        head = lines[1]
    return {"is_repo": is_repo, "head": head}


def probe_manifests(cwd):
    """Probe 6b — package/framework manifests present at root (fixed names +
    root-only globs; glob hits report the REAL filenames)."""
    found = [m for m in MANIFEST_SIGNALS if os.path.isfile(os.path.join(cwd, m))]
    try:
        root_files = sorted(os.listdir(cwd))
    except OSError:
        root_files = []
    import fnmatch
    for pat in MANIFEST_GLOB_SIGNALS:
        for fn in root_files:
            if fnmatch.fnmatch(fn, pat) and os.path.isfile(os.path.join(cwd, fn)):
                found.append(fn)
    return found


# ── P2 GROUND: the manifest→pack fingerprint matcher ─────────────────────────
# Executes the `detection_signature` frontmatter every pack already carries
# (data-complete since the packs shipped; until P2 the mapping ran MODEL-side
# in scan Step 8.5). ONE matcher, here in the shared probe engine — the
# resolver and routing both read its state.json output; never a second sniff.

_PACK_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "references", "framework-conventions",
)
_FM_KEY_RE = {
    "framework": re.compile(r"(?m)^framework:\s*(\S+)\s*$"),
    "package_manifest": re.compile(r"(?m)^\s{2}package_manifest:\s*(.+)$"),
    "dependency_marker": re.compile(r"(?m)^\s{2}dependency_marker:\s*(.+)$"),
    "fallback_dependency_marker": re.compile(
        r"(?m)^\s{2}fallback_dependency_marker:\s*(.+)$"),
    "detection_priority": re.compile(r"(?m)^detection_priority:\s*(\d+)\s*(?:#.*)?$"),
}


def _fm_scalar(raw):
    """Strip a YAML scalar: quoted span wins; else cut a trailing comment."""
    raw = raw.strip()
    if raw[:1] in ("'", '"'):
        q = raw[0]
        end = raw.find(q, 1)
        if end > 0:
            return raw[1:end]
    return raw.split(" #", 1)[0].strip()


def _read_pack_signatures():
    """[{framework, package_manifest, markers[], priority}] from every pack
    frontmatter carrying a detection_signature. Read-only; parse failures
    skip the pack (never fabricate a match)."""
    sigs = []
    try:
        names = sorted(os.listdir(_PACK_DIR))
    except OSError:
        return sigs
    for fn in names:
        if not fn.endswith(".md") or fn.startswith("_") or fn == "README.md":
            continue
        try:
            with open(os.path.join(_PACK_DIR, fn), encoding="utf-8",
                      errors="replace") as f:
                head = f.read(4096)
        except OSError:
            continue
        if "detection_signature:" not in head:
            continue
        fm_end = head.find("\n---", 4)
        fm = head[:fm_end] if fm_end > 0 else head
        vals = {}
        for key, rx in _FM_KEY_RE.items():
            m = rx.search(fm)
            if m:
                vals[key] = _fm_scalar(m.group(1))
        if not vals.get("framework") or not vals.get("package_manifest"):
            continue
        markers = [vals[k] for k in
                   ("dependency_marker", "fallback_dependency_marker")
                   if vals.get(k)]
        sigs.append({
            "framework": vals["framework"],
            "package_manifest": vals["package_manifest"],
            "markers": markers,
            "priority": int(vals.get("detection_priority") or 100),
        })
    return sigs


def probe_framework_pack(cwd, manifests):
    """P2 GROUND — deterministic manifest→pack resolution.

    Match = the pack's manifest (or a MANIFEST_ALTERNATES sibling, canonical
    absent) exists at root AND any declared marker substring appears in it
    (markers absent → manifest presence alone, weakest). Winner = lowest
    detection_priority, then name sort; every match is reported in
    candidates[] for honesty. No match → `_universal`, same as scan Step 8.5.
    """
    import fnmatch
    out = {"pack": "_universal", "manifest": None, "candidates": []}
    if not manifests:
        return out
    mset = list(manifests)
    content_cache = {}

    def _content(fn):
        if fn not in content_cache:
            try:
                with open(os.path.join(cwd, fn), encoding="utf-8",
                          errors="replace") as f:
                    content_cache[fn] = f.read(262144)
            except OSError:
                content_cache[fn] = ""
        return content_cache[fn]

    matches = []
    for sig in _read_pack_signatures():
        pat = sig["package_manifest"]
        if any(ch in pat for ch in "*?["):
            files = [m for m in mset if fnmatch.fnmatch(m, pat)]
        else:
            files = [pat] if pat in mset else [
                alt for alt in MANIFEST_ALTERNATES.get(pat, ()) if alt in mset
            ][:1]
        for fn in files:
            if not sig["markers"] or any(mk in _content(fn) for mk in sig["markers"]):
                matches.append((sig["priority"], sig["framework"], fn))
                break
    if not matches:
        return out
    matches.sort()
    out["pack"] = matches[0][1]
    out["manifest"] = matches[0][2]
    out["candidates"] = ["%s(%s,p%d)" % (m[1], m[2], m[0]) for m in matches]
    return out


_INDEX_HEAD_RE = re.compile(r'"head_commit"\s*:\s*(?:"([0-9a-f]{7,40})"|null)')


def probe_symbol_index(cwd, head=None):
    """P2 — symbol-index presence + freshness stamp (the change-signal
    substrate for express-born projects that never grow a codebase-map)."""
    p = os.path.join(cwd, ".mega-sdd", "codebase", "symbol-index.json")
    out = {"present": False, "head_commit": None, "matches_head": "n/a"}
    if not os.path.isfile(p):
        return out
    out["present"] = True
    try:
        with open(p, encoding="utf-8", errors="replace") as f:
            head_chunk = f.read(512)  # head_commit lives in the envelope keys
    except OSError:
        return out
    m = _INDEX_HEAD_RE.search(head_chunk)
    stamp = m.group(1) if m else None
    out["head_commit"] = stamp
    if stamp and head:
        out["matches_head"] = "yes" if stamp == head else "no"
    return out


def probe_spine(cwd):
    """`spine:` from .mega-sdd/config.yaml — "express" (default) or
    "classic". P2 flip: express is the default spine; classic restores the
    scan-first chains verbatim. Same contract as probe_profile: top-level
    key only, first match wins, absent/unreadable → default."""
    try:
        with open(os.path.join(cwd, ".mega-sdd", "config.yaml"),
                  encoding="utf-8", errors="replace") as f:
            for ln in f:
                m = re.match(r"^spine:\s*[\"']?(express|classic)[\"']?\s*(?:#.*)?$", ln)
                if m:
                    return m.group(1)
    except OSError:
        pass
    return "express"


def probe_code_files(cwd, limit=4000):
    """Existing-code signal for greenfield/brownfield detection. Bounded
    walk (early exit at the first code file; vendored/state dirs skipped).
    scan_capped=True means the bound was hit WITHOUT a hit — treat as
    unknown-leaning-false, never fabricate."""
    visited = 0
    stack = [cwd]
    while stack:
        d = stack.pop()
        try:
            with os.scandir(d) as it:
                for entry in it:
                    visited += 1
                    if visited > limit:
                        return {"has_code_files": False, "scan_capped": True}
                    if entry.is_dir(follow_symlinks=False):
                        if entry.name not in _CODE_SKIP_DIRS and not entry.name.startswith("."):
                            stack.append(entry.path)
                    elif entry.is_file(follow_symlinks=False):
                        if os.path.splitext(entry.name)[1].lower() in CODE_EXTS:
                            return {"has_code_files": True, "scan_capped": False}
        except OSError:
            continue
    return {"has_code_files": False, "scan_capped": False}


def probe_codebase_map(cwd, head=None):
    """Probe 7 — codebase-map at its path generations + freshness stamp.
    matches_head: "yes"|"no"|"n/a" (n/a when stamp or HEAD unavailable; a
    literal `HEAD` stamp reads as missing per the validate-codebase-map
    consumer rule)."""
    hit = None
    for rel in CODEBASE_MAP_GENERATIONS:
        if os.path.isfile(os.path.join(cwd, rel)):
            hit = rel
            break
    out = {"present": bool(hit), "path": hit, "last_scanned_commit": None,
           "matches_head": "n/a"}
    if not hit:
        return out
    try:
        with open(os.path.join(cwd, hit), encoding="utf-8", errors="replace") as f:
            md = f.read(8192)  # frontmatter lives at the top
    except OSError:
        return out
    m = _STAMP_RE.search(md)
    stamp = m.group(1) if m else None
    if stamp == "HEAD":  # literal HEAD = missing (god-review-s3 r2 rule)
        stamp = None
    out["last_scanned_commit"] = stamp
    if stamp and head:
        out["matches_head"] = "yes" if stamp == head else "no"
    return out


def probe_knowledge_base(cwd):
    """Probe 8 — KB README at its 4 path generations; first hit wins."""
    for rel in KB_README_GENERATIONS:
        if os.path.isfile(os.path.join(cwd, rel)):
            return {"present": True, "path": rel}
    return {"present": False, "path": None}


def probe_foreign_sdd(cwd, cap=20):
    """Foreign-SDD artifact recognition (P2 adoption) — read-only + bounded.
    Known tool dirs (spec-kit `.specify/`, Kiro `.kiro/specs/`, OpenSpec
    `openspec/`|`.openspec/`) + generic `specs/*.md` whose head opens with YAML
    frontmatter. Returns [{"tool", "path"}] rows — plain data; the adoption
    lane (certify-artifact --rung=prd, DEMOTE always confirmed) is policy and
    lives in the routing table, never here."""
    hits = []
    for tool, rel in FOREIGN_SDD_DIR_SIGNALS:
        if os.path.isdir(os.path.join(cwd, rel)):
            hits.append({"tool": tool, "path": rel})
    sdir = os.path.join(cwd, "specs")
    if os.path.isdir(sdir):
        try:
            names = sorted(os.listdir(sdir))
        except OSError:
            names = []
        for name in names:
            if len(hits) >= cap:
                break
            if not name.lower().endswith(".md"):
                continue
            path = os.path.join(sdir, name)
            if not os.path.isfile(path):
                continue
            try:
                with open(path, encoding="utf-8", errors="replace") as f:
                    head = f.read(256)
            except OSError:
                continue
            # Frontmatter sniff: bare prose notes in a specs/ folder are not an
            # SDD signal; a frontmatter-opened spec file is.
            if head.startswith("---\n") or head.startswith("---\r\n"):
                hits.append({"tool": "generic-specs",
                             "path": os.path.join("specs", name)})
    return hits


def probe_dirty_journal(cwd):
    """Mode D signal — `.dirty-paths.jsonl` row count (non-empty lines;
    `grep -c .` parity)."""
    path = os.path.join(cwd, DIRTY_JOURNAL_REL)
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return sum(1 for ln in f if ln.strip("\n"))
    except OSError:
        return 0


def _count_units(vdir):
    """Unit files across BOTH layouts (U-*.md phase-2 / U-*/unit.md phase-1)
    and the legacy `-bound` sibling — the has_units() glob set, counted."""
    n = len(glob.glob(os.path.join(vdir, "units", "U-*.md")))
    n += len(glob.glob(os.path.join(vdir, "units", "U-*", "unit.md")))
    sib = vdir + "-bound"
    n += len(glob.glob(os.path.join(sib, "units", "U-*.md")))
    n += len(glob.glob(os.path.join(sib, "units", "U-*", "unit.md")))
    return n


def _bolt_reports(vdir):
    reports = glob.glob(os.path.join(vdir, "bolts", "U-*", "bolt-report.md"))
    reports += glob.glob(os.path.join(vdir + "-bound", "bolts", "U-*", "bolt-report.md"))
    return reports


def _conflict_block_stats(md):
    """(active, resolved) CONFLICT detail-block counts inside `## Conflicts`
    — binding_md.parse_conflict_resolutions' block grammar (its compiled
    regexes imported, never re-invented), reduced to counting."""
    lines = md.splitlines()
    start = end = None
    for i, line in enumerate(lines):
        if start is None and line.strip().startswith("## Conflicts"):
            start = i + 1
            continue
        if start is not None and line.startswith("## "):
            end = i
            break
    if start is None:
        return 0, 0
    if end is None:
        end = len(lines)
    blocks = []
    for i in range(start, end):
        m = binding_md.CONFLICT_HEADING_RE.match(lines[i])
        if m:
            blocks.append((i, m.group(1)))
    active = resolved = 0
    for n, (i, conflict_id) in enumerate(blocks):
        j = blocks[n + 1][0] if n + 1 < len(blocks) else end
        heading = lines[i]
        body = "\n".join(lines[i + 1: j])
        head_resolved = ("✅" in heading) or re.search(
            rf"{re.escape(conflict_id)}\s+RESOLVED\b", heading
        )
        if head_resolved or binding_md.RESOLUTION_LINE_RE.search(body):
            resolved += 1
        else:
            active += 1
    return active, resolved


def probe_binding(vdir):
    """binding.md + binding.json presence, conflict counts, resolution-action
    tallies, and the recorded bind-time head (shared binding_md grammar)."""
    out = {
        "binding_md": os.path.isfile(os.path.join(vdir, "binding.md")),
        "binding_json": os.path.isfile(os.path.join(vdir, "binding.json")),
        "head": None,
        "conflicts_active": 0,
        "conflicts_resolved": 0,
        "resolution_actions": {},
    }
    if not out["binding_md"]:
        return out
    try:
        with open(os.path.join(vdir, "binding.md"), encoding="utf-8",
                  errors="replace") as f:
            md = f.read()
    except OSError:
        return out
    out["head"] = binding_md.parse_frontmatter_metadata(md).get("head")
    active, resolved = _conflict_block_stats(md)
    out["conflicts_active"] = active
    out["conflicts_resolved"] = resolved
    errors = []
    actions = {}
    for action in binding_md.parse_conflict_resolutions(md, errors).values():
        actions[action] = actions.get(action, 0) + 1
    out["resolution_actions"] = actions
    return out


def probe_oq_counts(vdir):
    """Probe 9 — P0/P1 OQ counts split open-vs-deferred (routing-rules §OQ
    counting note). vault.json first (the derived manifest); fallback: the
    shared vault_md OQ grammar over the numbered docs. `pending` and a
    missing status read as open (back-compat rule)."""
    rows = None
    vj = os.path.join(vdir, "vault.json")
    if os.path.isfile(vj):
        try:
            with open(vj, encoding="utf-8") as f:
                data = json.load(f)
            oqs = data.get("open_questions")
            if isinstance(oqs, list):
                rows = oqs
        except Exception:
            rows = None  # corrupt manifest → markdown fallback
    if rows is None:
        rows = []
        errors = []
        for doc in sorted(glob.glob(os.path.join(vdir, "0[0-6]-*.md"))):
            try:
                with open(doc, encoding="utf-8", errors="replace") as f:
                    md = f.read()
            except OSError:
                continue
            rows.extend(
                vault_md.parse_open_questions(os.path.basename(doc), md, errors)
            )
    pending = deferred = 0
    for oq in rows:
        if not isinstance(oq, dict):
            continue
        if (oq.get("priority") or "").upper() not in ("P0", "P1"):
            continue
        status = oq.get("status") or "open"
        if status == "pending":
            status = "open"
        if status == "open":
            pending += 1
        elif status == "deferred":
            deferred += 1
    return {"pending_p0_p1": pending, "deferred_p0_p1": deferred}


def probe_vault_dir(cwd, vdir, layout):
    """Everything routing wants to know about ONE vault dir — plain data."""
    docs = glob.glob(os.path.join(vdir, "0[0-6]-*.md"))
    vj = os.path.join(vdir, "vault.json")
    mode = None
    if os.path.isfile(vj):
        try:
            with open(vj, encoding="utf-8") as f:
                mode = json.load(f).get("mode")
        except Exception:
            mode = None
    bound_present = bool(
        glob.glob(os.path.join(vdir, "bound", "*")) or
        glob.glob(os.path.join(vdir + "-bound", "*"))
    )
    bolt_reports = _bolt_reports(vdir)
    last_bolt = None
    for r in bolt_reports:
        try:
            mt = os.path.getmtime(r)
            if last_bolt is None or mt > last_bolt:
                last_bolt = mt
        except OSError:
            pass
    drift = os.path.join(vdir, "DRIFT-REPORT.md")
    drift_present = os.path.isfile(drift)
    drift_mtime = None
    if drift_present:
        try:
            drift_mtime = os.path.getmtime(drift)
        except OSError:
            drift_present = False
    pending_sync = 0
    ps = os.path.join(vdir, "PENDING-SYNC.md")
    if os.path.isfile(ps):
        try:
            with open(ps, encoding="utf-8", errors="replace") as f:
                pending_sync = len(_PENDING_SYNC_OPEN_RE.findall(f.read()))
        except OSError:
            pass
    squad_count = 0
    sq = os.path.join(vdir, "_meta", "squads.yaml")
    if os.path.isfile(sq):
        try:
            with open(sq, encoding="utf-8", errors="replace") as f:
                squad_count = len(_SQUAD_ID_RE.findall(f.read()))
        except OSError:
            pass
    interfaces_count = 0
    idir = os.path.join(vdir, "interfaces")
    if os.path.isdir(idir):
        interfaces_count = len([
            n for n in os.listdir(idir)
            if n.endswith(".md") and n != "_index.md"
        ])
    mtimes = []
    for p in docs + ([vj] if os.path.isfile(vj) else []):
        try:
            mtimes.append(os.path.getmtime(p))
        except OSError:
            pass
    return {
        "name": os.path.basename(vdir),
        "path": os.path.relpath(vdir, cwd),
        "layout": layout,
        "has_vault_json": os.path.isfile(vj),
        "vault_doc_count": len(docs),
        "mode": mode,
        "bound_present": bound_present,
        "binding": probe_binding(vdir),
        "units_count": _count_units(vdir),
        "bolts_count": len(bolt_reports),
        "last_bolt_mtime": _iso(last_bolt) if last_bolt else None,
        "oq": probe_oq_counts(vdir),
        "squad_count": squad_count,
        "interfaces_count": interfaces_count,
        "drift_report": {
            "present": drift_present,
            "mtime": _iso(drift_mtime) if drift_mtime else None,
        },
        "pending_sync_open": pending_sync,
        "mtime": _iso(max(mtimes)) if mtimes else None,
    }


def probe_vaults(cwd):
    """Probe 2 — vault dirs across ALL generations, priority order. `-bound`
    siblings, dotdirs, and .archived are not vaults. A canonical dir counts
    with vault.json OR bare 0[0-6]-*.md docs; legacy generations require
    vault.json (routing-rules probe 2 / P0 unification)."""
    out = []
    for layout, rel in VAULT_ROOT_GENERATIONS:
        root = os.path.join(cwd, rel)
        if not os.path.isdir(root):
            continue
        for name in sorted(os.listdir(root)):
            if name.startswith(".") or name.endswith("-bound"):
                continue
            vdir = os.path.join(root, name)
            if not os.path.isdir(vdir):
                continue
            has_json = os.path.isfile(os.path.join(vdir, "vault.json"))
            has_docs = bool(glob.glob(os.path.join(vdir, "0[0-6]-*.md")))
            if layout == "canonical":
                if not (has_json or has_docs):
                    continue
            elif not has_json:
                continue
            out.append(probe_vault_dir(cwd, vdir, layout))
    return out


def collect_probes(cwd):
    """The full probes object — plain data, no policy."""
    git_info = probe_git(cwd)
    manifests = probe_manifests(cwd)
    return {
        "prd": probe_prd_candidates(cwd),
        "vaults": probe_vaults(cwd),
        "git": git_info,
        "manifests": manifests,
        "code": probe_code_files(cwd),
        "codebase_map": probe_codebase_map(cwd, git_info.get("head")),
        "symbol_index": probe_symbol_index(cwd, git_info.get("head")),
        "framework_pack": probe_framework_pack(cwd, manifests),
        "knowledge_base": probe_knowledge_base(cwd),
        "dirty_journal_rows": probe_dirty_journal(cwd),
        "profile": probe_profile(cwd),
        "spine": probe_spine(cwd),
        "foreign_sdd": probe_foreign_sdd(cwd),
        "preflight_predicates": {
            "has_vault": has_vault(cwd),
            "has_bound_or_vault": has_bound_or_vault(cwd),
            "has_units": has_units(cwd),
            "has_codebase_map": has_codebase_map(cwd),
        },
    }


# ── Policy: derived position + proposed_next (routing decision table) ────────
# The ONE place probe data becomes a routing default. Mirrors
# orchestrate-flow/references/routing-rules.md §Decision matrix — outcomes
# identical; flag-/intent-conditioned rows (--greenfield, rebuild intent,
# --sync force) stay the DOC's call and surface here only as notes.

POSITIONS = (
    "empty", "legacy_code_only", "prd_no_vault", "kb_no_vault",
    "oq_gate", "prd_revision", "maintenance_sync",
    "vault_greenfield_no_units", "vault_no_map", "vault_map_unbound",
    "binding_resolved_no_rebind", "bound_no_units",
    "units_pending_bolts", "all_units_executed", "pipeline_complete",
)


def probe_profile(cwd):
    """`profile:` from .mega-sdd/config.yaml — "lean" or "full" (default).
    Tranche E: lean is a NAMED opt-in that trims advisory/second-opinion
    surfaces only; no gate, validator, or hook-deny path reads this value."""
    try:
        with open(os.path.join(cwd, ".mega-sdd", "config.yaml"),
                  encoding="utf-8", errors="replace") as f:
            for ln in f:
                m = re.match(r"^profile:\s*[\"']?(lean|full)[\"']?\s*(?:#.*)?$", ln)
                if m:
                    return m.group(1)
    except OSError:
        pass
    return "full"


def _primary_vault(vaults):
    """First hit wins, generation priority then name sort (probe_vaults
    already emits in that order)."""
    return vaults[0] if vaults else None


def derive(probes):
    """position + proposed_next per the routing decision table. Data in,
    routing default out. Never invents intent: rows needing a user signal
    (rebuild intent, --greenfield) yield an empty chain + a note."""
    vault = _primary_vault(probes["vaults"])
    manifests = probes["manifests"]
    git_repo = probes["git"]["is_repo"]
    has_code = probes["code"]["has_code_files"]
    cmap = probes["codebase_map"]
    sindex = probes.get("symbol_index") or {
        "present": False, "head_commit": None, "matches_head": "n/a"}
    notes = []

    if not git_repo and not manifests and not has_code:
        mode_inferred = "greenfield"
    else:
        mode_inferred = "brownfield"
    starterkit = "detected" if manifests else "absent"

    change_signal = {
        "dirty_journal_rows": probes["dirty_journal_rows"],
        "map_stamp_matches_head": cmap["matches_head"],
        # P2: the freshness stamp an express-born project HAS — without it,
        # every change-signal surface is map-gated and sync goes silent
        # forever on projects that never grow a map.
        "index_stamp_matches_head": sindex["matches_head"],
    }

    foreign_sdd = probes.get("foreign_sdd") or []

    profile = probes.get("profile", "full")
    spine = probes.get("spine", "express")
    fpack = probes.get("framework_pack") or {"pack": "_universal",
                                             "manifest": None,
                                             "candidates": []}
    derived = {
        "vault": vault["name"] if vault else None,
        "profile": profile,
        "spine": spine,
        "framework_pack": fpack["pack"],
        "framework_pack_manifest": fpack["manifest"],
        "vault_path": vault["path"] if vault else None,
        "position": None,
        "proposed_next": [],
        "mode_inferred": mode_inferred,
        "starterkit": starterkit,
        "change_signal": change_signal,
        "drift_recent": False,
        "manifest_derive_needed": bool(
            vault and not vault["has_vault_json"] and vault["vault_doc_count"]
        ),
        "foreign_sdd": foreign_sdd,
        "notes": notes,
    }

    if foreign_sdd:
        # Adoption lane (P2): recognition only — a DEMOTE re-ingest burns
        # generate-intent tokens and produces a DIFFERENT vault than the user
        # placed, so it is ALWAYS confirmed (C2 adoption_demote_confirm,
        # decision 7). Never a silent chain hop.
        tools = ",".join(sorted({h["tool"] for h in foreign_sdd}))
        notes.append(
            "foreign SDD artifacts detected (%s) -> adoption lane: "
            "certify-artifact --rung=prd per spec file (DEMOTE is always a "
            "confirmed C2 adoption_demote_confirm halt under --auto, never "
            "unconfirmed)" % tools
        )

    def finish(position, chain):
        derived["position"] = position
        if profile == "lean":
            # Tranche E cut 1: the advisor legs already ship --no-advisor with
            # the honest `advisor: skipped` provenance — lean only routes it.
            chain = [
                (h + " --no-advisor")
                if (h.split()[0] in ("generate-intent", "bind-codebase")
                    and "--no-advisor" not in h) else h
                for h in chain
            ]
        if spine == "express":
            # P2 flip: every bind hop retrieves claim-scoped by default (the
            # lean-injection pattern — ONE site, never per return). classic
            # renders today's chains verbatim.
            chain = [
                (h + " --express")
                if (h.split()[0] == "bind-codebase" and "--express" not in h)
                else h
                for h in chain
            ]
        if derived["manifest_derive_needed"] and chain:
            # P0 unification: bare vault docs → derive the manifest FIRST,
            # never hand-write it, before any phase that reads vault.json.
            chain = [
                "scripts/derive-vault-json.sh --vault %s" % vault["path"]
            ] + chain
        derived["proposed_next"] = chain
        return derived

    # ── No vault: input-shape ladder ─────────────────────────────────────
    if vault is None:
        if probes["knowledge_base"]["present"]:
            return finish("kb_no_vault", [
                "generate-intent --kb=%s" % os.path.dirname(
                    probes["knowledge_base"]["path"]
                ),
            ])
        if probes["prd"]["present"]:
            prd = probes["prd"]["candidates"][0]
            if starterkit == "detected":
                if spine == "express":
                    # P2 default: GROUND already ran as a script (derive-state
                    # + build-symbol-index); no scan phase, no --scan= arg —
                    # intent grounds via the index, bind verifies --express.
                    return finish("prd_no_vault", [
                        "generate-intent %s" % prd,
                        "bind-codebase",
                        "generate-units",
                    ])
                return finish("prd_no_vault", [
                    "scan-codebase",
                    "generate-intent %s --scan=<codebase-map>" % prd,
                    "bind-codebase",
                    "generate-units",
                ])
            notes.append(
                "starterkit absent + no --greenfield flag -> halt "
                "no_starterkit_detected (scaffold first / opt in greenfield / cancel)"
            )
            return finish("prd_no_vault", [])
        if has_code or manifests or git_repo:
            notes.append(
                "codebase without PRD/KB/vault: needs user intent — rebuild "
                "(extract-intelligence lane) vs new-feature brief "
                "(generate-intent --from-prompt); routing table decides"
            )
            return finish("legacy_code_only", [])
        notes.append("no inputs found (scanned the root + one level inside PRD//docs//documents//requirements dirs): provide a PRD/brief or run inside a codebase")
        return finish("empty", [])

    # ── Vault present: precedence gates first ────────────────────────────
    binding = vault["binding"]
    units = vault["units_count"]
    bolts = vault["bolts_count"]

    # 1. Intent gate: pending P0/P1 OQs outrank everything.
    if vault["oq"]["pending_p0_p1"] > 0:
        return finish("oq_gate", ["resolve-oq"])

    # 2. New PRD revision (file newer than vault) outranks sync.
    if (
        probes["prd"]["present"] and probes["prd"]["newest_mtime"]
        and vault["mtime"] and probes["prd"]["newest_mtime"] > vault["mtime"]
    ):
        return finish("prd_revision", [
            # the NEW revision, not candidates[0] — with subdir scanning a
            # newer docs/ PRD would otherwise trigger the position while the
            # unchanged root file got diffed, forever (round CL-F1)
            "diff-vault %s" % (probes["prd"]["newest"]
                               or probes["prd"]["candidates"][0]),
        ])

    # 3. Mode D — maintenance/sync: a freshness substrate (map OR symbol
    # index — P2: express-born projects never grow a map) + binding exist
    # AND a change signal fired.
    if (cmap["present"] or sindex["present"]) and binding["binding_md"] and (
        change_signal["dirty_journal_rows"] > 0
        or change_signal["map_stamp_matches_head"] == "no"
        or change_signal["index_stamp_matches_head"] == "no"
    ):
        vp = vault["path"]
        if cmap["present"]:
            # Map-bearing project: today's chain, unchanged — scan
            # --changed-only refreshes the map AND writes the changed set.
            return finish("maintenance_sync", [
                "scan-codebase --changed-only",
                "detect-drift --scope=@%s/.sync-changed-paths.txt" % vp,
                "bind-codebase --paths=@%s/.sync-changed-paths.txt" % vp,
                "generate-units --reconcile",
                "execute-bolts",
            ])
        # Express-born (index, no map): the changed set derives from git
        # (index head_commit..HEAD) ∪ the dirty journal — a script, zero
        # model tokens; same downstream consumer contract.
        return finish("maintenance_sync", [
            "scripts/derive-changed-paths.sh --vault %s" % vp,
            "detect-drift --scope=@%s/.sync-changed-paths.txt" % vp,
            "bind-codebase --paths=@%s/.sync-changed-paths.txt" % vp,
            "generate-units --reconcile",
            "execute-bolts",
        ])

    # ── Pipeline ladder ──────────────────────────────────────────────────
    if (vault["mode"] or ("greenfield" if mode_inferred == "greenfield" else "existing")) == "greenfield":
        if units == 0:
            return finish("vault_greenfield_no_units", ["generate-units"])
    if not cmap["present"] and not vault["bound_present"] and units == 0:
        if spine == "express":
            # P2: without the flip this position is an unreachable trap —
            # the map never exists on the express spine, so every brownfield
            # vault would demand a scan forever. Express bind needs no map.
            return finish("vault_no_map", ["bind-codebase", "generate-units"])
        return finish("vault_no_map", [
            "scan-codebase", "bind-codebase", "generate-units",
        ])
    if not vault["bound_present"] and units == 0:
        actions = binding["resolution_actions"]
        if (
            binding["binding_md"]
            and binding["conflicts_active"] == 0
            and actions
            and set(actions) <= {"KEEP_VAULT", "DEFER"}
        ):
            # KEEP_VAULT/DEFER-only resolution leaves bound/ absent by design;
            # a re-bind would re-raise the SAME conflict and loop.
            return finish("binding_resolved_no_rebind", ["generate-units"])
        return finish("vault_map_unbound", ["bind-codebase"])
    if units == 0:
        return finish("bound_no_units", ["generate-units"])
    if bolts < units:
        # Chain dispatch is wave-parallel (token-and-latency spec §2a): the
        # --per-squad procedure is parallel by construction; the --all leg
        # carries --parallel explicitly. Standalone suggestions elsewhere keep
        # plain --all — this is the CHAIN proposer.
        chain = (
            ["execute-bolts --per-squad"] if vault["squad_count"] >= 2
            else ["execute-bolts --all --parallel"]
        )
        return finish("units_pending_bolts", chain)

    # All units executed → drift check recency.
    drift = vault["drift_report"]
    drift_recent = bool(
        drift["present"] and (
            vault["last_bolt_mtime"] is None
            or (drift["mtime"] or "") >= vault["last_bolt_mtime"]
        )
    )
    derived["drift_recent"] = drift_recent
    if not drift_recent:
        return finish("all_units_executed", ["detect-drift"])
    return finish("pipeline_complete", [])


def collect_state(cwd):
    """probes + derived — the full state.json payload (minus envelope)."""
    probes = collect_probes(cwd)
    return {"probes": probes, "derived": derive(probes)}
