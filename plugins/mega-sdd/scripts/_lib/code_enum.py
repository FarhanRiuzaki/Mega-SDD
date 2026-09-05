# code_enum.py — the ONE code-file enumeration (extensions + exclusions +
# git-or-walk), shared by build-symbol-index.sh and derive-extract-census.sh
# so the census and the symbol index always count the SAME source set.
# (Standing lesson: two hand-copied constant lists WILL drift — derive, never
# duplicate. This is the enumeration sibling of _lib/postflight_rules.py.)
#
# exclusions.md (scan-codebase) remains the prose owner of the exclusion list;
# these constants are its script mirror, moved verbatim from
# build-symbol-index.sh (spec 2026-08-26-extract-revamp-contract-design.md).
import os
import subprocess

# Extensions covered by the shipped ast-grep packs (membership-only gate for
# the file enumeration — ast-grep assigns each file's language by its own ext
# mapping, so the values here are documentation of WHICH pack's lane covers
# the ext). .jsx maps to javascript (ast-grep's js grammar parses JSX; jsx.yml
# must never exist — it would double-count every .jsx symbol).
EXTS = {".ts": "typescript", ".tsx": "tsx", ".js": "javascript",
        ".jsx": "javascript", ".mjs": "javascript", ".cjs": "javascript",
        ".php": "php", ".py": "python", ".rs": "rust", ".go": "go",
        ".rb": "ruby", ".java": "java", ".cs": "csharp",
        ".kt": "kotlin", ".kts": "kotlin", ".swift": "swift",
        ".scala": "scala", ".c": "c", ".h": "c",
        ".cpp": "cpp", ".cc": "cpp", ".cxx": "cpp", ".hpp": "cpp", ".hh": "cpp",
        ".dart": "dart", ".ex": "elixir", ".exs": "elixir",
        ".lua": "lua", ".sh": "bash", ".bash": "bash", ".hs": "haskell"}

# Legacy-stack extensions the CENSUS must enumerate but the symbol index must
# NOT (ast-grep has no grammar for them; indexing lane stays EXTS-only).
# 7.26.0, spec 2026-09-05-kb-verify-lane-design.md Fase 4 — the Host-AS400
# census had to be hand-built ("manual, AS400 ext") because these were absent.
# NOTE: AS400 member exports that encode the type as a filename PREFIX with no
# extension (Qrpgsrc.DD0215) still need a hand-adjusted census — record that
# honestly in generated_by when it happens.
LEGACY_EXTS = {".rpg": "rpg", ".rpgle": "rpgle", ".sqlrpgle": "rpgle",
               ".dds": "dds", ".pf": "dds", ".lf": "dds",
               ".clp": "cl", ".clle": "cl",
               ".cbl": "cobol", ".cob": "cobol", ".cpy": "cobol-copy"}

# Committed dirs git ls-files can still admit (exclusions.md is the owner of
# the full list). Segment-based, so a nested packages/app/node_modules/ is
# excluded too — matching the list's `**` semantics.
# any-depth: dependency trees + caches (nested packages/app/node_modules too)
EXCL_DIR_NAMES = {"node_modules", "vendor", "__pycache__", ".venv", "venv",
                  ".next", ".nuxt", ".svelte-kit", ".astro", ".turbo", ".git",
                  ".mega-sdd", "bower_components", ".yarn", ".pnpm-store",
                  ".gradle", ".cache", ".parcel-cache", ".pytest_cache",
                  ".mypy_cache", ".ruff_cache", ".tox", "htmlcov",
                  ".nyc_output", ".bundle"}

# top-level only: these names are legitimate NESTED source dirs (cargo's
# src/bin/*.rs multi-binary convention, go cmd trees) — pruning them anywhere
# drops real tracked source (round-2 finding B9)
EXCL_TOP = ("bin/", "obj/", "out/", "build/", "target/", "env/", "dist/",
            "coverage/", "storage/framework/", "bootstrap/cache/",
            "public/build/", "public/hot/")


def excluded(relpath):
    return relpath.startswith(EXCL_TOP) or \
           any(seg in EXCL_DIR_NAMES for seg in relpath.split("/")[:-1])


def enumerate_code_files(cwd, git_timeout=30, include_legacy=False):
    """Enumerate code files under cwd: git ls-files (tracked,
    .gitignore-honoring) when cwd is a git tree, else an os.walk with the same
    prune prefixes. Returns (sorted relpaths filtered to EXTS + not excluded,
    git_ok). include_legacy=True adds LEGACY_EXTS (census lane; the symbol
    index NEVER passes it — ast-grep has no grammar for those stacks).
    An EMPTY tracked list is an answer, not a fallback trigger."""
    files, git_ok = [], False
    try:
        p = subprocess.run(["git", "ls-files", "-z"], cwd=cwd,
                           capture_output=True, text=True, errors="replace",
                           timeout=git_timeout, stdin=subprocess.DEVNULL)
        if p.returncode == 0:
            git_ok = True
            files = [f for f in p.stdout.split("\0") if f]
    except (subprocess.TimeoutExpired, OSError):
        pass
    if not git_ok:
        for root, dirs, names in os.walk(cwd):
            rel = os.path.relpath(root, cwd)
            rel = "" if rel == "." else rel.replace(os.sep, "/") + "/"
            dirs[:] = [d for d in dirs
                       if d not in EXCL_DIR_NAMES
                       and not (rel + d + "/").startswith(EXCL_TOP)]
            for n in names:
                files.append(rel + n)
    exts = dict(EXTS, **LEGACY_EXTS) if include_legacy else EXTS
    return (sorted(f for f in files
                   if os.path.splitext(f)[1].lower() in exts and not excluded(f)),
            git_ok)
