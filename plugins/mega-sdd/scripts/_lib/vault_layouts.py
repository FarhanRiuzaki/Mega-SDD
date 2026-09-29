"""vault_layouts.py — single source for every vault layout the validators accept.

S6 EB-VAL-2: the three validate-bolt-artifacts modes discovered only the canonical
`.mega-sdd/vaults/*` layout while validate-unit-spec.sh discover_units() (S5R-3)
covers 10 patterns including `docs/mega-sdd/vaults/**` and `*-bound/` siblings —
so legacy-layout projects failed B1/orphan OPEN and B2 permanently false-CLOSED.
This module mirrors that pattern list; a pin test (tests/god-review-s6) asserts
parity against validate-unit-spec.sh so the two can never drift apart again.

Consumers import via:  sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
"""
import glob
import os

# One prefix per vault-root layout; `<prefix>/units/...` and `<prefix>/bolts/...`
# hang off each. Mirrors validate-unit-spec.sh discover_units() (the *-bound
# entries under docs/mega-sdd/vaults are subsumed by the `*` glob but kept
# explicit there; realpath-dedup makes the overlap harmless).
def vault_prefixes(cwd):
    return (
        os.path.join(cwd, ".mega-sdd", "vaults", "*"),
        os.path.join(cwd, "docs", "mega-sdd", "vaults", "*"),
        os.path.join(cwd, "*-bound"),
        os.path.join(cwd, "*", "*-bound"),
        os.path.join(cwd, "docs", "mega-sdd", "vaults", "*-bound"),
    )


def unit_files(cwd):
    """Every unit file across all layouts (both U-*.md and U-*/unit.md shapes),
    realpath-deduped and sorted — same contract as discover_units()."""
    got = []
    for pre in vault_prefixes(cwd):
        got.extend(glob.glob(os.path.join(pre, "units", "U-*.md")))
        got.extend(glob.glob(os.path.join(pre, "units", "U-*", "unit.md")))
    return sorted({os.path.realpath(p) for p in got})


def find_unit_file(cwd, uid):
    """First unit file for `uid` across all layouts, or None."""
    for pre in vault_prefixes(cwd):
        for pat in (os.path.join(pre, "units", uid + ".md"),
                    os.path.join(pre, "units", uid, "unit.md")):
            g = sorted(glob.glob(pat))
            if g:
                return g[0]
    return None


def find_bolt_artifact(cwd, uid, name):
    """First `<vault>/bolts/<uid>/<name>` across all layouts, or None."""
    for pre in vault_prefixes(cwd):
        g = sorted(glob.glob(os.path.join(pre, "bolts", uid, name)))
        if g:
            return g[0]
    return None


def batch_suite_files(cwd):
    """Every `<vault>/bolts/_batch-suite.json` across all layouts, deduped."""
    got = []
    for pre in vault_prefixes(cwd):
        got.extend(glob.glob(os.path.join(pre, "bolts", "_batch-suite.json")))
    return sorted({os.path.realpath(p) for p in got})


def decision_dirs(cwd):
    """Every `<vault>/decisions/` dir across all layouts (plus the one-level-nested
    shape the PBT citation check historically accepted), deduped."""
    got = []
    for pre in vault_prefixes(cwd):
        got.extend(glob.glob(os.path.join(pre, "decisions")))
    got.extend(glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "*", "decisions")))
    return sorted({os.path.realpath(p) for p in got if os.path.isdir(p)})
