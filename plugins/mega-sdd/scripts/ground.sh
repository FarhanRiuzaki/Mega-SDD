#!/usr/bin/env bash
# ground.sh — the v6 GROUND step: zero model tokens, seconds.
#   1. derive-state.sh   — probes (manifest sniff incl. the P2 pack matcher,
#                          spine, symbol-index freshness) -> .mega-sdd/state.json
#   2. build-symbol-index.sh — the retrieval substrate for bind --express
# GROUND deliberately does NOT: write starterkit-context.yaml (cache-keyed
# deep-scan artifact — a script stub would read as a false warm cache), or
# produce a codebase-map (scan-codebase stays the on-demand map seam).
# Exit 0 = grounded (index may still be honestly absent — see INDEX=);
# 2 = usage; derive-state failures pass through (read-only surface, never blocks).
set -u
CWD="."
while [ $# -gt 0 ]; do case "$1" in
  --cwd) CWD="$2"; shift 2;;
  --cwd=*) CWD="${1#*=}"; shift;;
  *) echo "usage: ground.sh [--cwd=<project-root>]" >&2; exit 2;;
esac; done
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

# ─── C1 self-resolve battery (moved here from hooks/session-start, v7 Fase 2) ─
# session-start must never write vault artifacts (gate-1 mandate); the 9-guard
# battery runs at M/L entry instead — BEFORE derive-state so the probes see
# repaired state. (v7.3.0: guards emit CHAT notices only — no telemetry.)
# ─── C1 self-resolve: mode_migrate (Iter 67.7.1, script-layer since v7) ─────
# Gate B response (reviewer 2026-05-27): C1 protocol shipped as prose has
# audit-failed 4×. Hook-layer enforcement deterministically detects + fixes
# the mode_migrate precondition before any chain starts.
#
# Detects: any active <cwd>/.mega-sdd/vaults/*/vault.json (excluding .archived/)
# where `mode` field is missing OR mismatches CWD signals.
# CWD signals → mode mapping (deterministic; no fabrication):
#   any of {.git, composer.json, package.json, Gemfile, Cargo.toml, go.mod,
#           build.gradle, pom.xml, requirements.txt, pyproject.toml} present
#     → expected_mode = "existing"
#   none present → expected_mode = "greenfield"
SELF_RESOLVE_NOTICES=""
CONFIG_FILE="${CWD}/.mega-sdd/config.yaml"
# v7.3.0: the guards are pipeline self-resolve — always on for a mega-sdd
# project (the old `telemetry: false` opt-out died with telemetry itself).
if [ -d "${CWD}/.mega-sdd" ]; then
    # Run C1 self-resolve guards via python (deterministic detection + fix).
  # Iter 67.7.1: mode_migrate.  Iter 67.7.2 (v3.51.1+): adds partial_state_corrupt.
  SELF_RESOLVE_NOTICES=$(CWD="$CWD" PLUGIN_ROOT_HINT="$SCRIPT_DIR/.." python3 <<'PYEOF' 2>/dev/null
import json
import os
import sys
import glob
from datetime import datetime, timezone

cwd = os.environ["CWD"]
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
session_id = os.environ.get("CLAUDE_SESSION_ID", "ground-script")  # not a documented hook env var; label-only fallback (stdin session_id is the real source if ever needed)
notices = []

def emit_event(halt_type, fix_applied, **payload_extras):
    # v7.3.0: telemetry removed — the chat notice (appended by each guard) is
    # the only record. Kept as a no-op so guard call sites stay unchanged.
    return

# ─── Guard 1: mode_migrate (vault.json mode vs CWD signals) ─────────────────
signals = [
    ".git", "composer.json", "package.json", "Gemfile", "Cargo.toml",
    "go.mod", "build.gradle", "pom.xml", "requirements.txt", "pyproject.toml",
]
detected_signals = [s for s in signals if os.path.exists(os.path.join(cwd, s))]
expected_mode = "existing" if detected_signals else "greenfield"

vault_jsons = []
for f in sorted(glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "vault.json"))):
    if "/.archived/" in f or "/.archived\\" in f:
        continue
    vault_jsons.append(f)

for vj in vault_jsons:
    try:
        with open(vj) as f:
            data = json.load(f)
    except Exception:
        continue  # corrupted vault.json — separate halt class (future slice)
    current_mode = data.get("mode")
    if current_mode == expected_mode:
        continue
    old_mode_repr = current_mode if current_mode is not None else "(missing)"
    data["mode"] = expected_mode
    try:
        with open(vj, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
    except Exception:
        continue
    rel_vj = os.path.relpath(vj, cwd)
    scope_name = os.path.basename(os.path.dirname(vj))
    emit_event(
        "mode_migrate",
        f"vault.json mode {old_mode_repr} → {expected_mode}",
        scope=scope_name,
        detected_signals=detected_signals,
        vault_json_path=rel_vj,
    )
    notices.append(f"[self-resolved] mode_migrate: {scope_name} mode {old_mode_repr} → {expected_mode}")

# ─── Guard 2: partial_state_corrupt (Iter 67.7.2 — v3.51.1+) ───────────────
# Scan <cwd>/.mega-sdd/vaults/*-bound/bolts/U-*/partial-state.json
# If file fails JSON parse → rename to partial-state.json.corrupt-<ISO8601>
# (forensics preserved; --resume restarts fresh per plugins/mega-sdd/references/halt-protocol.md).
# NEVER halts. Honors same opt-out as mode_migrate (handled by GUARD_ENABLED above).
ts_fname = ts.replace(":", "-").replace(".", "-")  # filename-safe ISO8601
for f in sorted(glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*-bound", "bolts", "U-*", "partial-state.json"))):
    if "/.archived/" in f or "/.archived\\" in f:
        continue
    try:
        with open(f) as fh:
            json.load(fh)
        # Parsed cleanly; no action
        continue
    except json.JSONDecodeError:
        # Corrupted — rename and emit
        corrupt_path = f"{f}.corrupt-{ts_fname}"
        try:
            os.rename(f, corrupt_path)
        except Exception:
            continue  # rename failed; don't claim resolve
        rel_orig = os.path.relpath(f, cwd)
        rel_corrupt = os.path.relpath(corrupt_path, cwd)
        unit_id = os.path.basename(os.path.dirname(f))  # U-XXX from path
        emit_event(
            "partial_state_corrupt",
            f"renamed → {os.path.basename(corrupt_path)}; --resume will restart fresh",
            unit_id=unit_id,
            original_path=rel_orig,
            corrupt_path=rel_corrupt,
        )
        notices.append(f"[self-resolved] partial_state_corrupt: {unit_id} renamed (JSON parse fail); --resume will restart fresh")
    except Exception:
        # Non-JSONDecodeError (file system error, encoding etc.) → skip; not a clean self-resolve
        continue

# ─── Guard 4: verify_unit_writable (Iter 67.7.4 — v3.52.0+) ────────────────
# Scan units for task_type=verify with non-empty target_files (forbidden per
# attestation reclassification: verify units MUST be read-only). DETECTION-ONLY:
# emit a chat notice; DO NOT modify on-disk unit (preserves
# bad spec for human review). Dispatch-time auto-clear is execute-bolts's job
# (separate concern).
#
# Two layouts (per Iter 67.6.1 validator pattern):
#   Layout A (phase-2):  <vault>/*-bound/units/U-*.md
#   Layout B (phase-1):  <vault>/*-bound/units/U-*/unit.md
import re as _re

FRONTMATTER_RE_VW = _re.compile(r"^---\n(.*?)\n---", _re.DOTALL)
unit_paths_vw = sorted(
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*-bound", "units", "U-*.md")) +
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*-bound", "units", "U-*", "unit.md"))
)
for up in unit_paths_vw:
    if "/.archived/" in up or "/.archived\\" in up:
        continue
    try:
        body = open(up).read()
    except Exception:
        continue
    m = FRONTMATTER_RE_VW.match(body)
    if not m:
        continue
    fm = m.group(1)
    # Quick task_type extraction
    tt_match = _re.search(r"^task_type:\s*(\w+)", fm, _re.MULTILINE)
    if not tt_match or tt_match.group(1) != "verify":
        continue
    # Line-based target_files block extraction (regex with nested groups is unreliable
    # for YAML lists with mixed indent — see Iter 67.7.x debug). The block is
    # everything from `target_files:` up to the next top-level YAML key or end of fm.
    fm_lines = fm.split("\n")
    in_block = False
    block_lines = []
    for ln in fm_lines:
        if ln.startswith("target_files:"):
            in_block = True
            continue
        if in_block:
            if ln and ln[0] not in " \t":
                break  # next top-level key
            block_lines.append(ln)
    block_text = "\n".join(block_lines)
    if not block_text.strip():
        continue
    forbidden_ops = _re.findall(r"operation:\s*(create|modify|delete)", block_text)
    if not forbidden_ops:
        continue
    # Violation: verify unit with writable target_files
    rel_up = os.path.relpath(up, cwd)
    # Layout A uses unit_id:, Layout B uses id: — accept both
    unit_id_match = _re.search(r"^(?:unit_id|id):\s*(\S+)", fm, _re.MULTILINE)
    if unit_id_match:
        unit_id = unit_id_match.group(1)
    elif os.path.basename(up) == "unit.md":
        # Layout B fallback: dir name (e.g., U-002-some-name)
        unit_id = os.path.basename(os.path.dirname(up))
    else:
        unit_id = os.path.basename(up).replace(".md", "")
    emit_event(
        "verify_unit_writable",
        f"detected at GROUND; on-disk unit preserved for review; execute-bolts will auto-clear at dispatch time",
        unit_id=unit_id,
        unit_path=rel_up,
        forbidden_operations=forbidden_ops,
    )
    notices.append(f"[self-resolved] verify_unit_writable: {unit_id} has task_type=verify + writable target_files (review needed; dispatch will auto-clear)")

# ─── Guard 5: framework_pack_unparseable (B.7) + framework_pack_cycle (B.8) ─
# + framework_pack_missing (B.10) — combined pack-integrity scan.
# Pack files live under <cwd>/.mega-sdd/codebase/framework-conventions/*.md
# OR referenced from binding docs / starterkit-context.yaml.
# Walking-skeleton scope:
#   - Find all *.md files under framework-conventions/
#   - For each: try to read; check for `extends:` field that points to other pack
#   - Build inheritance graph; detect cycles
#   - Detect references in binding/starterkit-context.yaml pointing to missing packs
pack_dir_candidates = [
    os.path.join(cwd, ".mega-sdd", "packs"),   # F-14: the canonical project pack root
    os.path.join(cwd, ".mega-sdd", "codebase", "framework-conventions"),
    os.path.join(cwd, ".mega-sdd", "codebase", "packs"),
]
pack_dir = next((d for d in pack_dir_candidates if os.path.isdir(d)), None)
pack_files = {}  # basename → path
pack_extends = {}  # basename → list of extended basenames

if pack_dir:
    for pf in sorted(glob.glob(os.path.join(pack_dir, "*.md"))):
        base = os.path.basename(pf).replace(".md", "")
        pack_files[base] = pf
        # Try to parse — detect unparseable + extends references
        try:
            content = open(pf, encoding="utf-8").read()
        except Exception:
            emit_event(
                "framework_pack_unparseable",
                f"pack {base} could not be read as UTF-8 text",
                pack_name=base,
                pack_path=os.path.relpath(pf, cwd),
                reason="non-utf8 or read error",
            )
            notices.append(f"[self-resolved] framework_pack_unparseable: {base} unreadable; skipping pack")
            continue
        # Look for extends: field in YAML frontmatter
        fm_match = _re.match(r"^---\n(.*?)\n---", content, _re.DOTALL) if "_re" in dir() else None
        if not fm_match:
            import re as _re2
            fm_match = _re2.match(r"^---\n(.*?)\n---", content, _re2.DOTALL)
        if fm_match:
            fm = fm_match.group(1)
            import re as _re3
            ext_match = _re3.search(r"^extends:\s*\[?([^\]\n]+)\]?", fm, _re3.MULTILINE)
            if ext_match:
                ext_value = ext_match.group(1).strip().strip("'\"")
                # Could be list "[A, B]" or single "A"
                ext_list = [e.strip().strip("'\"") for e in ext_value.split(",") if e.strip()]
                pack_extends[base] = ext_list

    # Detect cycles via DFS
    import re as _re4
    visited = set()
    rec_stack = set()

    def find_cycle(node, path):
        if node in rec_stack:
            return path + [node]
        if node in visited:
            return None
        visited.add(node)
        rec_stack.add(node)
        for nxt in pack_extends.get(node, []):
            cyc = find_cycle(nxt, path + [node])
            if cyc:
                return cyc
        rec_stack.remove(node)
        return None

    cycles_reported = set()
    for base in pack_files:
        cyc = find_cycle(base, [])
        if cyc:
            cyc_key = tuple(sorted(set(cyc)))
            if cyc_key in cycles_reported:
                continue
            cycles_reported.add(cyc_key)
            emit_event(
                "framework_pack_cycle",
                f"pack inheritance cycle detected: {' → '.join(cyc)}",
                cycle_path=cyc,
                break_at=cyc[-2] if len(cyc) >= 2 else cyc[0],
            )
            notices.append(f"[self-resolved] framework_pack_cycle: cycle {' → '.join(cyc[:3])}... breaking at most-derived edge")

    # Detect missing pack references (referenced in extends but file not found)
    for base, ext_list in pack_extends.items():
        for ext in ext_list:
            if ext not in pack_files:
                emit_event(
                    "framework_pack_missing",
                    f"pack {base} extends nonexistent pack {ext}",
                    referencing_pack=base,
                    missing_pack=ext,
                )
                notices.append(f"[self-resolved] framework_pack_missing: {base} extends missing {ext}; dropping reference")

# ─── Guard 6: dep_missing (B.11 — non-interactive only) ────────────────────
# Check required binaries on PATH. Per reviewer 2026-05-27 refinement R2:
# DETECTION only at GROUND. Auto-install is NOT performed here (would
# risk hanging on sudo/network). Emit a chat notice.
# install-deps subsystem invocation is left to explicit user action.
import shutil as _shutil
required_bins = ["ast-grep"]  # optional but useful (tree-sitter lane removed v7.4.0)
missing_bins = [b for b in required_bins if _shutil.which(b) is None]
if missing_bins:
    emit_event(
        "dep_missing",
        f"required binaries missing on PATH (advisory): {missing_bins}",
        missing_binaries=missing_bins,
        suggested_action="run /mega-sdd:install-deps (non-interactive only; manual install if needed)",
        will_degrade_to="regex tier (scan-codebase) / v1 grammar (execute-bolts)",
    )
    notices.append(f"[self-resolved] dep_missing: {missing_bins} not on PATH; will degrade gracefully")

# ─── Guard 7: deep_scan_cache_corrupt (B.9) ────────────────────────────────
# Check <cwd>/.mega-sdd/codebase/starterkit-context.yaml — if exists, validate
# it as parseable YAML (or at least structured key:value pairs). If corrupt,
# rename and let scan-codebase re-build on next invocation.
import re as _re5
starterkit_path = os.path.join(cwd, ".mega-sdd", "codebase", "starterkit-context.yaml")
if os.path.isfile(starterkit_path):
    try:
        with open(starterkit_path, "rb") as f:
            raw = f.read()
        try:
            content = raw.decode("utf-8")
            # Heuristic: must have at least one top-level key: value or comment
            if not raw or not _re5.search(r"^[a-zA-Z_][\w-]*:", content, _re5.MULTILINE):
                raise ValueError("no top-level YAML keys found")
        except (UnicodeDecodeError, ValueError) as e:
            corrupt_path = f"{starterkit_path}.corrupt-{ts_fname}"
            os.rename(starterkit_path, corrupt_path)
            rel_orig = os.path.relpath(starterkit_path, cwd)
            rel_corrupt = os.path.relpath(corrupt_path, cwd)
            emit_event(
                "deep_scan_cache_corrupt",
                f"starterkit-context.yaml unparseable; renamed → {os.path.basename(corrupt_path)}; the next ON-DEMAND scan-codebase run rebuilds it (scan is not in the default express chain)",
                original_path=rel_orig,
                corrupt_path=rel_corrupt,
                reason=str(e),
            )
            notices.append(f"[self-resolved] deep_scan_cache_corrupt: starterkit-context.yaml renamed; an on-demand scan-codebase run rebuilds it")
    except Exception:
        pass

# ─── Guard 8: model_tier_unknown (edge-case track — GROUND config pre-validation) ─
# Reframe of Phase A flagged slice 5. Original was mid-chain orchestrate-flow Step 2.8.f
# (no GROUND surface). Reframe: pre-validate user/project model-tier config files
# against canonical catalog at GROUND (M/L entry). Catches misconfigs before they fire mid-chain.
import re as _re_mt

mt_catalog_path = None
# Catalog ships in plugin source; find via SCRIPT_DIR → plugin root
# PLUGIN_ROOT_HINT is unreliable; derive from known hook location instead.
import pathlib as _pathlib_mt
_hook_dir = _pathlib_mt.Path(__file__).resolve().parent if "__file__" in dir() else None
_plugin_root_derived = str(_hook_dir.parent) if _hook_dir else ""
plugin_root_env = os.environ.get("PLUGIN_ROOT_HINT", "") or _plugin_root_derived
catalog_candidates = [
    os.path.join(plugin_root_env, "references", "model-tiers.md") if plugin_root_env else None,
]
# Fallback: walk cache directory, picking the LATEST version by SemVer (NOT a
# lexical string sort — "4.9.0" > "4.36.0" lexically; mirrors scripts/resolve-plugin-root.sh).
import glob as _glob_mt
def _semver_key_mt(_p):
    try:
        _ver = _p.split("/mega-sdd/mega-sdd/")[1].split("/")[0]
        return [int(_x) for _x in _ver.split(".")]
    except Exception:
        return [-1]
for cached in sorted(_glob_mt.glob(os.path.expanduser(
        "~/.claude/plugins/cache/mega-sdd/mega-sdd/*/references/model-tiers.md")), key=_semver_key_mt, reverse=True):
    catalog_candidates.append(cached)
    break  # newest version first
for c in catalog_candidates:
    if c and os.path.isfile(c):
        mt_catalog_path = c
        break

if mt_catalog_path:
    try:
        catalog_content = open(mt_catalog_path).read()
        # Role names live in the SECOND cell (backticked) — the first cell is
        # the row number. The old first-cell capture collected row numbers, so
        # every legitimate override tripped a spurious model_tier_unknown
        # (2026-08 doc-audit finding, fixed with the v7.6.0 catalog reshape).
        catalog_roles = set(_re_mt.findall(
            r"^\|\s*\d+[a-z]?\s*\|\s*`?([\w-]+)`?\s*\|", catalog_content, _re_mt.MULTILINE))
    except Exception:
        catalog_roles = set()

    config_paths = [
        os.path.join(cwd, ".mega-sdd", "config.yaml"),
    ]
    # (v7.3.0: the user-scope preferences.md model-tier source died with the
    # memory lane; project config.yaml is the single model_tiers source.)

    for cp in config_paths:
        if not os.path.isfile(cp):
            continue
        try:
            cfg_text = open(cp).read()
        except Exception:
            continue
        # Look for model_tiers: block or preferences.md ## Model tiers section
        # Extract `- role: tier` or `role: tier` lines
        in_block = False
        for ln in cfg_text.split("\n"):
            if _re_mt.match(r"^\s*model_tiers:\s*$", ln) or _re_mt.match(r"^##\s+Model\s+tiers", ln, _re_mt.IGNORECASE):
                in_block = True
                continue
            if in_block:
                # End block on next top-level key or heading
                if _re_mt.match(r"^\w", ln) or _re_mt.match(r"^##\s", ln):
                    in_block = False
                    continue
                # Try to match role: tier (with or without leading - )
                m = _re_mt.match(r"^\s*-?\s*([\w-]+):\s*(\w+)", ln)
                if m:
                    role = m.group(1)
                    tier = m.group(2)
                    if role in ("model_tiers", "preferences"):
                        continue
                    if catalog_roles and role not in catalog_roles:
                        emit_event(
                            "model_tier_unknown",
                            f"override role '{role}' not in catalog ({len(catalog_roles)} known roles); chain will use catalog default",
                            unknown_role=role,
                            override_tier=tier,
                            override_source=os.path.relpath(cp, cwd) if cp.startswith(cwd) else cp,
                        )
                        notices.append(f"[self-resolved] model_tier_unknown: role '{role}' unknown; chain uses catalog default")

if notices:
    print("\n".join(notices))
PYEOF
)
fi

# Surface the notices as GROUND output (the model relays them at M/L entry).
if [ -n "$SELF_RESOLVE_NOTICES" ]; then
  printf '%s\n' "$SELF_RESOLVE_NOTICES"
fi

bash "$SCRIPT_DIR/derive-state.sh" --cwd="$CWD"
STATE_RC=$?

# Pre-init CWD: probes only, never mint .mega-sdd/ from a status view (the
# EB-GATE-6 phantom-root doctrine; round F10 — build-symbol-index would
# otherwise makedirs .mega-sdd/codebase/ and arm the dirty journal on a
# repo the user never adopted).
if [ ! -d "${CWD}/.mega-sdd" ]; then
  echo "GROUND: pre-init (no .mega-sdd/) — probes only, no artifacts minted"
  exit 0
fi

# Sync-pending guard (round F1 — REPRODUCED false 'in sync'): rebuilding the
# index HERE re-stamps head_commit to HEAD BEFORE derive-changed-paths.sh
# consumes the old stamp as its diff baseline — the changed set would derive
# empty and the sync would reconcile nothing. Defer; bind --express E0
# rebuilds AFTER the re-verdict, advancing the stamp at the correct point.
POSITION=$(python3 -c "
import json
try:
    print(json.load(open('${CWD}/.mega-sdd/state.json')).get('derived', {}).get('position', ''))
except Exception:
    print('')
" 2>/dev/null)
if [ "$POSITION" = "maintenance_sync" ]; then
  echo "GROUND: state rc=$STATE_RC · index: rebuild DEFERRED (sync pending — the stale stamp IS the changed-set baseline; bind --express E0 rebuilds after the re-verdict)"
  exit 0
fi

bash "$SCRIPT_DIR/build-symbol-index.sh" --cwd="$CWD"
IDX_RC=$?
case "$IDX_RC" in
  0) INDEX="built" ;;
  3) INDEX="absent (ast-grep not installed — the chain renders CLASSIC; /mega-sdd:install-deps adds ast-grep)" ;;
  *) INDEX="absent (build failed rc=$IDX_RC — the chain renders CLASSIC)" ;;
esac
echo "GROUND: state rc=$STATE_RC · index: $INDEX"
exit 0
