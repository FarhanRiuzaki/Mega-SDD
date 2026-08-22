#!/usr/bin/env bash
# migrate-paths.sh — migrate mega-sdd outputs from the legacy scattered layout
# to the canonical .mega-sdd/ consolidation (per references/paths.md).
#
# This is the deterministic, destructive core extracted from
# commands/migrate-paths.md (audit finding C6). The interactive confirm gate
# and the user-facing dirty-tree HALT live in the command; this script
# self-guards (idempotent no-op + dirty-tree refusal + target-exists conflict)
# so that direct or --auto-confirm invocation is still safe.
#
# Usage: migrate-paths.sh [--dry-run] [--from=auto|legacy|mixed]
#                         [--cwd=<path>] [--auto-confirm]
#        migrate-paths.sh --vault-layout[=<vault-dir>] [--apply] [--cwd=<path>]
#   --dry-run       Preview every move/rewrite; mutate nothing.
#   --from=auto     Source layout (default auto). --from=legacy confirms intent
#                   to migrate into a pre-existing, non-empty .mega-sdd/vaults/.
#   --cwd=<path>    Operate on this project root (default: current directory).
#   --auto-confirm  Accepted + ignored here (the confirm gate lives in the
#                   command); the dirty-tree guard below is the safety backstop.
#   --vault-layout  v7 Fase 3 rung: migrate legacy 7-file vault(s) to the
#                   4-file layout-2 (vault.md/model.md/flows.md/constraints.md).
#                   DRY-RUN BY DEFAULT — preview only; add --apply to execute.
#                   Without =<vault-dir>: every legacy vault under
#                   .mega-sdd/vaults/. After apply it runs derive-vault-json
#                   and prints the MANDATORY follow-up: full re-bind (line
#                   anchors in binding.json/.citation-map.json are invalidated
#                   by the merge and are NEVER patched — regenerate).
#
# Exit: 0 = migrated OR already-canonical no-op
#       1 = error (target-exists conflict; reference-update failure via set -e)
#       2 = refused (dirty git tree without --dry-run) | usage error
set -euo pipefail

DRY_RUN=0
FROM=auto
ROOT="."
VAULT_LAYOUT=""
VL_APPLY=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)        DRY_RUN=1 ;;
    --from=*)         FROM="${arg#*=}" ;;
    --cwd=*)          ROOT="${arg#*=}" ;;
    --to=*)           : ;;  # accepted + ignored: 'new' is the only implemented
                            # target (the default); --to=legacy rollback is unbuilt
    --auto-confirm)   : ;;  # no-op: confirm lives in the command
    --vault-layout)   VAULT_LAYOUT="__ALL__" ;;
    --vault-layout=*) VAULT_LAYOUT="${arg#*=}" ;;
    --apply)          VL_APPLY=1 ;;
    -h|--help)        sed -n '2,31p' "$0"; exit 0 ;;
    *) echo "migrate-paths: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

[ -d "$ROOT" ] || { echo "migrate-paths: --cwd is not a directory: $ROOT" >&2; exit 2; }
# Resolve BEFORE cd — $0 may be a relative path from the caller's cwd.
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
cd "$ROOT"

# run CMD... — echo under --dry-run, execute otherwise. ALL mutations route here.
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

TARGET_ROOT="./.mega-sdd"

# ==========================================================================
# --vault-layout rung (v7 Fase 3): legacy 7-file vault → 4-file layout-2.
# DRY-RUN BY DEFAULT (--apply executes). Concat is VERBATIM relocation: the
# six lock values become YAML frontmatter (+ vault_layout: 2 + the
# kb_module_graph pointer when present); 01/02/05 bodies land under the hard
# anchor headers ## Overview / ## Architecture / ## Decisions; 03→model.md,
# 04→flows.md, 06→constraints.md; EVERY `## Open Questions` section moves to
# constraints.md with a per-line `[origin: <file>#<anchor>]` token stamped
# from the doc it came from (constraints-native OQs get none). The 00-index
# residue sections Glossary / Source documents / Auto-Classification Review /
# Changelog move VERBATIM into vault.md; every other 00-index section is
# DROPPED and NAMED in the output (ceremony — roll-up, reading paths, etc.).
# Line-anchored refs are NEVER rewritten to fake freshness: after apply the
# script runs derive-vault-json and prints the mandatory full re-bind step.
# ==========================================================================
if [ -n "$VAULT_LAYOUT" ]; then
  VAULTS=()
  if [ "$VAULT_LAYOUT" = "__ALL__" ]; then
    for d in ./.mega-sdd/vaults/*/; do
      [ -d "$d" ] || continue
      [ -f "${d}00-index.md" ] && [ ! -f "${d}vault.md" ] && VAULTS+=("${d%/}")
    done
  else
    [ -d "$VAULT_LAYOUT" ] || { echo "migrate-paths: vault dir not found: $VAULT_LAYOUT" >&2; exit 2; }
    [ -f "$VAULT_LAYOUT/vault.md" ] && { echo "migrate-paths: $VAULT_LAYOUT is already layout-2 (vault.md exists) — no-op."; exit 0; }
    [ -f "$VAULT_LAYOUT/00-index.md" ] || { echo "migrate-paths: $VAULT_LAYOUT has no 00-index.md — not a legacy vault" >&2; exit 2; }
    VAULTS+=("$VAULT_LAYOUT")
  fi
  if [ ${#VAULTS[@]} -eq 0 ]; then
    echo "migrate-paths: no legacy vaults to migrate (already layout-2, or none under .mega-sdd/vaults/)."
    exit 0
  fi
  if [ "$VL_APPLY" -eq 1 ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
     && [ -n "$(git status --porcelain 2>/dev/null | grep -v '^??')" ]; then
    echo "migrate-paths: REFUSED — git tree has uncommitted changes. Commit/stash first (preview stays available without --apply)." >&2
    exit 2
  fi
  for V in "${VAULTS[@]}"; do
    echo "== vault-layout: $V $([ "$VL_APPLY" -eq 1 ] && echo '(APPLY)' || echo '(dry-run — add --apply to execute)')"
    RC=0
    MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib" V_VAULT="$V" V_APPLY="$VL_APPLY" python3 <<'PYEOF' || RC=$?
import os, re, sys

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_md

vault = os.environ["V_VAULT"]
apply_ = os.environ["V_APPLY"] == "1"

DOCS = ["00-index.md", "01-overview.md", "02-architecture.md",
        "03-data-model.md", "04-flows.md", "05-decisions.md",
        "06-constraints.md"]
ORIGIN_OF = {"01-overview.md": "vault.md#Overview",
             "02-architecture.md": "vault.md#Architecture",
             "03-data-model.md": "model.md",
             "04-flows.md": "flows.md",
             "05-decisions.md": "vault.md#Decisions",
             "06-constraints.md": None}
docs = {}
for fn in DOCS:
    p = os.path.join(vault, fn)
    if os.path.isfile(p):
        docs[fn] = open(p, encoding="utf-8", errors="surrogateescape").read()

H2_RE = re.compile(r"(?m)^##\s+(.+?)\s*$")

def sections(md):
    """[(heading_text, start, end)] over H2 sections; end = next H2 or EOF."""
    heads = [(m.group(1), m.start()) for m in H2_RE.finditer(md)]
    out = []
    for n, (h, s) in enumerate(heads):
        e = heads[n + 1][1] if n + 1 < len(heads) else len(md)
        out.append((h, s, e))
    return out

def cut_section(md, name):
    """(section_body_without_heading, md_without_section). Case-insensitive
    prefix match on the H2 text; first hit only."""
    for h, s, e in sections(md):
        if h.lower().startswith(name.lower()):
            body = md[s:e]
            body = body.split("\n", 1)[1] if "\n" in body else ""
            return body.strip("\n"), (md[:s] + md[e:])
    return None, md

def strip_h1(md):
    """Remove the doc's leading H1 line (+ one following blank)."""
    lines = md.split("\n")
    if lines and lines[0].startswith("# "):
        lines = lines[1:]
        if lines and lines[0].strip() == "":
            lines = lines[1:]
    return "\n".join(lines)

OQ_LINE_INJECT_RE = re.compile(
    r"^(-\s*\[[ x~]\]\s*\*\*OQ-(?:[A-Z]+(?:-[A-Z0-9]+)*-)?\d+\*\*(?:\s*\[[^\]]*\])*)")

def stamp_origin(body, origin):
    if not origin:
        return body
    out = []
    for line in body.split("\n"):
        m = OQ_LINE_INJECT_RE.match(line)
        if m and "[origin:" not in line:
            line = line[:m.end(1)] + " [origin: %s]" % origin + line[m.end(1):]
        out.append(line)
    return "\n".join(out)

# ── harvest OQ sections from every doc (VERBATIM blocks + origin stamps) ──
oq_parts = []
bodies = {}
for fn in DOCS[1:]:
    md = docs.get(fn, "")
    oq_body, rest = cut_section(md, "Open Questions")
    bodies[fn] = rest
    if oq_body and oq_body.strip():
        oq_parts.append(stamp_origin(oq_body, ORIGIN_OF[fn]))

# ── 00-index residue ──
idx = docs.get("00-index.md", "")
lock = vault_md.parse_vault_lock(idx)
kbg = re.search(r"(?m)^\s*`?kb_module_graph`?\s*:\s*(\S+)", idx)
m_h1 = re.match(r"^#\s+(.+?)\s*$", idx, re.M)
title = m_h1.group(0) if m_h1 else "# Vault"
moved, remaining = {}, idx
for name in ("Glossary", "Source documents", "Auto-Classification Review", "Changelog"):
    body, remaining = cut_section(remaining, name)
    if body and body.strip():
        moved[name] = body
dropped = []
for h, s, e in sections(remaining):
    hl = h.lower()
    if hl.startswith("vault lock"):
        continue
    dropped.append(h)

def yq(v):
    return '"%s"' % v if v is not None else "null"

fm = ["---", "vault_layout: 2"]
for label, key in (("vault_version", "vault_version"),
                   ("project_shape", "project_shape"),
                   ("implementation_mode", "implementation_mode"),
                   ("mode_migration_trigger", "mode_migrate_after"),
                   ("prd_status", "prd_status"),
                   ("output_mode", "output_mode")):
    if key in lock:
        fm.append("%s: %s" % (label, yq(lock[key])))
if kbg:
    fm.append("kb_module_graph: %s" % kbg.group(1))
fm.append("---")

def sec(anchor, body):
    return "## %s\n\n%s" % (anchor, body.strip("\n"))

parts = ["\n".join(fm), title]
parts.append(sec("Overview", strip_h1(bodies.get("01-overview.md", "")) or "(no overview doc in the legacy vault)"))
parts.append(sec("Architecture", strip_h1(bodies.get("02-architecture.md", "")) or "(no architecture doc in the legacy vault)"))
parts.append(sec("Decisions", strip_h1(bodies.get("05-decisions.md", "")) or "(no decisions doc in the legacy vault)"))
for name in ("Glossary", "Source documents", "Auto-Classification Review", "Changelog"):
    if name in moved:
        parts.append(sec(name, moved[name]))
vault_md_text = "\n\n".join(p.strip("\n") for p in parts if p is not None) + "\n"

model_text = (bodies.get("03-data-model.md", "").strip("\n") or "# Data Model") + "\n"
flows_text = (bodies.get("04-flows.md", "").strip("\n") or "# Flows") + "\n"
cons = bodies.get("06-constraints.md", "").strip("\n") or "# Constraints"
if oq_parts:
    cons += "\n\n## Open Questions\n\n" + "\n".join(p.strip("\n") for p in oq_parts)
cons_text = cons + "\n"

plan = [("vault.md", vault_md_text), ("model.md", model_text),
        ("flows.md", flows_text), ("constraints.md", cons_text)]
for name, text in plan:
    print("  %s %s (%d bytes)" % ("write" if apply_ else "[dry-run] write",
                                  os.path.join(vault, name), len(text.encode("utf-8"))))
for fn in DOCS:
    if fn in docs:
        print("  %s %s" % ("remove" if apply_ else "[dry-run] remove",
                           os.path.join(vault, fn)))
if dropped:
    print("  DROPPED 00-index sections (ceremony — review before --apply): "
          + "; ".join(dropped))
if apply_:
    for name, text in plan:
        with open(os.path.join(vault, name), "w", encoding="utf-8",
                  errors="surrogateescape") as f:
            f.write(text)
PYEOF
    [ "$RC" -eq 0 ] || { echo "migrate-paths: vault-layout transform failed on $V (rc=$RC)" >&2; exit 1; }
    if [ "$VL_APPLY" -eq 1 ]; then
      for fn in 00-index.md 01-overview.md 02-architecture.md 03-data-model.md 04-flows.md 05-decisions.md 06-constraints.md; do
        [ -f "$V/$fn" ] || continue
        if git ls-files --error-unmatch "$V/$fn" >/dev/null 2>&1; then
          git rm -q -f "$V/$fn"
        else
          rm -f "$V/$fn"
        fi
      done
      # doc-name refs INSIDE the vault (units vault_source section refs +
      # VAULT-DIFF) — NAME-only rewrite; line anchors are NOT touched (the
      # full re-bind below is the honest fix for those).
      for f in "$V"/units/*.md "$V/VAULT-DIFF.md"; do
        [ -f "$f" ] || continue
        sed -i.vlbak \
          -e 's/01-overview\.md/vault.md/g' -e 's/02-architecture\.md/vault.md/g' \
          -e 's/05-decisions\.md/vault.md/g' -e 's/03-data-model\.md/model.md/g' \
          -e 's/04-flows\.md/flows.md/g'    -e 's/06-constraints\.md/constraints.md/g' \
          -e 's/00-index\.md/vault.md/g' "$f"
        rm -f "$f.vlbak"
      done
      bash "${SCRIPT_DIR}/derive-vault-json.sh" --vault="$V" || {
        echo "migrate-paths: derive-vault-json FAILED after layout migration of $V — inspect the FAIL lines above" >&2; exit 1; }
    fi
  done
  if [ "$VL_APPLY" -eq 1 ]; then
    echo ""
    echo "NEXT (MANDATORY): full re-bind required — binding line anchors invalidated."
    echo "  The merge shifted line numbers; binding.json / .citation-map.json are NEVER"
    echo "  patched (regenerate, jangan fabricate): run /mega-sdd (bind) ulang untuk"
    echo "  vault ini, lalu graph/emisi akan self-heal pada run berikutnya."
  else
    echo ""
    echo "Preview only — nothing changed. Re-run with --apply to execute."
  fi
  exit 0
fi

# --------------------------------------------------------------------------
# Step 1 — detect legacy layout
# --------------------------------------------------------------------------
LEGACY_VAULTS_DIR=""
# Only count it as legacy when it actually holds vaults — an empty leftover
# parent from a prior run must not block the idempotency no-op below.
if [ -d "./docs/mega-sdd/vaults" ] && [ -n "$(ls -A "./docs/mega-sdd/vaults" 2>/dev/null)" ]; then
  LEGACY_VAULTS_DIR="./docs/mega-sdd/vaults"
fi

LEGACY_KB_DIR=""
for candidate in ./docs/knowledge-base ./old-reference/knowledge-base; do
  [ -d "$candidate" ] && LEGACY_KB_DIR="$candidate" && break
done

LEGACY_CODEBASE_MAP=""
[ -f "./codebase-map.md" ] && LEGACY_CODEBASE_MAP="./codebase-map.md"

LEGACY_MEMORY_DIR=""
[ -d "./.mega-sdd-memory" ] && LEGACY_MEMORY_DIR="./.mega-sdd-memory"

# --------------------------------------------------------------------------
# Guard 1 (idempotency) — MUST precede the dirty-tree guard. A completed
# migration leaves the tree dirty (staged git-mv renames + new config/log), so
# a clean re-run has to no-op HERE, before the dirty guard would wrongly fire.
# --------------------------------------------------------------------------
if [ -z "$LEGACY_VAULTS_DIR" ] && [ -z "$LEGACY_KB_DIR" ] \
   && [ -z "$LEGACY_CODEBASE_MAP" ] && [ -z "$LEGACY_MEMORY_DIR" ]; then
  echo "migrate-paths: no legacy paths detected — layout already canonical (.mega-sdd/). No-op."
  exit 0
fi

# --------------------------------------------------------------------------
# Detect git work tree (used by the dirty guard + git mv / plain mv selection)
# --------------------------------------------------------------------------
IN_GIT=0
if [ -d ".git" ] || git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  IN_GIT=1
fi

# --------------------------------------------------------------------------
# Guard 2 (dirty tree) — refuse to mutate an uncommitted tree unless --dry-run.
# Mirrors the command's dirty-tree HALT; this script-level backstop is what
# makes --auto-confirm / direct invocation safe.
# --------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 0 ] && [ "$IN_GIT" -eq 1 ]; then
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "migrate-paths: refusing to migrate — git working tree is dirty." >&2
    echo "  Commit or stash your changes first, then re-run (or pass --dry-run to preview)." >&2
    exit 2
  fi
fi

# --------------------------------------------------------------------------
# Guard 3 (target-exists conflict) — a non-empty .mega-sdd/vaults/ under
# --from=auto means a partial/prior migration; refuse rather than nest/clobber.
# Explicit --from=legacy confirms overwrite intent.
# --------------------------------------------------------------------------
if [ -n "$LEGACY_VAULTS_DIR" ] && [ -d "$TARGET_ROOT/vaults" ] \
   && [ -n "$(ls -A "$TARGET_ROOT/vaults" 2>/dev/null)" ] && [ "$FROM" = "auto" ]; then
  echo "migrate-paths: $TARGET_ROOT/vaults already exists and is non-empty." >&2
  echo "  Pass --from=legacy to confirm overwrite intent, or resolve the conflict manually." >&2
  exit 1
fi

echo "migrate-paths: migrating to canonical .mega-sdd/ layout (dry-run=$DRY_RUN, in-git=$IN_GIT)"

# move_path SRC DST — git mv when SRC is tracked, else plain mv; ensure parent.
move_path() {
  local src="$1" dst="$2"
  run mkdir -p "$(dirname "$dst")"
  if [ "$IN_GIT" -eq 1 ] && git ls-files --error-unmatch "$src" >/dev/null 2>&1; then
    run git mv "$src" "$dst"
  else
    run mv "$src" "$dst"
  fi
  if [ "$DRY_RUN" -eq 1 ]; then echo "  • plan: $src → $dst"; else echo "  ✓ moved: $src → $dst"; fi
}

# --------------------------------------------------------------------------
# Step 4 — execute moves (vaults FIRST so the internal-rename loop below runs
# on the post-move location, matching the original command's ordering)
# --------------------------------------------------------------------------
if [ -n "$LEGACY_VAULTS_DIR" ]; then
  run mkdir -p "$TARGET_ROOT/vaults"
  for vdir in "$LEGACY_VAULTS_DIR"/*/; do
    [ -d "$vdir" ] || continue
    slug="$(basename "$vdir")"
    move_path "${vdir%/}" "$TARGET_ROOT/vaults/$slug"
  done
  # Tidy the now-empty legacy parent(s) so a re-run sees a clean canonical
  # layout (idempotency). rmdir is data-safe: it refuses a non-empty directory.
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  • plan: rmdir empty $LEGACY_VAULTS_DIR (+ ./docs/mega-sdd if empty)"
  else
    rmdir "$LEGACY_VAULTS_DIR" 2>/dev/null || true
    rmdir "./docs/mega-sdd" 2>/dev/null || true
  fi
fi
[ -n "$LEGACY_KB_DIR" ]       && move_path "$LEGACY_KB_DIR"       "$TARGET_ROOT/knowledge-base"
[ -n "$LEGACY_CODEBASE_MAP" ] && move_path "$LEGACY_CODEBASE_MAP" "$TARGET_ROOT/codebase/codebase-map.md"
[ -n "$LEGACY_MEMORY_DIR" ]   && move_path "$LEGACY_MEMORY_DIR"   "$TARGET_ROOT/memory"

# Per-vault internal rename: <vault>/.mega-sdd/ → <vault>/.internal/ (avoids
# confusion with the top-level .mega-sdd/). Runs on the POST-move location.
for vault in "$TARGET_ROOT"/vaults/*/; do
  [ -d "$vault" ] || continue
  if [ -d "${vault}.mega-sdd" ]; then
    if [ "$IN_GIT" -eq 1 ] && git ls-files --error-unmatch "${vault}.mega-sdd" >/dev/null 2>&1; then
      run git mv "${vault}.mega-sdd" "${vault}.internal"
    else
      run mv "${vault}.mega-sdd" "${vault}.internal"
    fi
    if [ "$DRY_RUN" -eq 1 ]; then echo "  • plan: ${vault}.mega-sdd → ${vault}.internal"; else echo "  ✓ renamed: ${vault}.mega-sdd → ${vault}.internal"; fi
  fi
done

# --------------------------------------------------------------------------
# Step 5 — update internal references (legacy path strings in vault.json +
# binding.md). One unified rewrite set; non-matching patterns are no-ops.
# --------------------------------------------------------------------------
rewrite_refs() {
  local f="$1"
  [ -f "$f" ] || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  • plan: rewrite legacy path refs in $f"
    return 0
  fi
  sed -i.bak \
    -e 's|docs/mega-sdd/vaults/|.mega-sdd/vaults/|g' \
    -e 's|docs/knowledge-base/|.mega-sdd/knowledge-base/|g' \
    -e 's|/\.mega-sdd-memory/|/.mega-sdd/memory/|g' \
    -e 's|<vault>/\.mega-sdd/|<vault>/.internal/|g' \
    "$f" && rm -f "${f}.bak"
  echo "  ✓ rewrote refs: $f"
}

for vjson in "$TARGET_ROOT"/vaults/*/vault.json; do
  [ -f "$vjson" ] || continue
  rewrite_refs "$vjson"
done
for bmd in "$TARGET_ROOT"/vaults/*/binding.md "$TARGET_ROOT"/vaults/*/bound/*.md; do
  [ -f "$bmd" ] || continue
  rewrite_refs "$bmd"
done

# --------------------------------------------------------------------------
# Step 6 — create config.yaml (clobber-guard: never overwrite a user's config)
# --------------------------------------------------------------------------
CONFIG="$TARGET_ROOT/config.yaml"
if [ -e "$CONFIG" ]; then
  echo "  ⊘ config.yaml exists — preserved (not overwritten)"
elif [ "$DRY_RUN" -eq 1 ]; then
  echo "  • plan: create $CONFIG"
else
  mkdir -p "$TARGET_ROOT"
  cat > "$CONFIG" <<'YAML'
mega_sdd_schema: 1
output_root: .mega-sdd/
layout: new
defaults:
  memory_enabled: true
  emit_agents_md: true
  defensive_generation: true
probe_paths:
  vault_candidates:
    - .mega-sdd/vaults/
    - docs/mega-sdd/vaults/    # legacy fallback
  knowledge_base_candidates:
    - .mega-sdd/knowledge-base/
    - docs/knowledge-base/
    - old-reference/knowledge-base/
YAML
  echo "  ✓ created $CONFIG"
fi

# --------------------------------------------------------------------------
# Step 7 — verification (advisory; warnings do not fail the run)
# --------------------------------------------------------------------------
echo "Verifying canonical paths:"
for expected in "$TARGET_ROOT/vaults" "$TARGET_ROOT/config.yaml"; do
  if [ -e "$expected" ] || [ "$DRY_RUN" -eq 1 ]; then echo "  ✓ $expected"; else echo "  ⚠️  $expected MISSING"; fi
done
echo "Verifying legacy paths cleared:"
for legacy in "$LEGACY_VAULTS_DIR" "$LEGACY_CODEBASE_MAP" "$LEGACY_MEMORY_DIR"; do
  [ -n "$legacy" ] || continue
  if [ -e "$legacy" ] && [ "$DRY_RUN" -eq 0 ]; then echo "  ⚠️  $legacy still exists (not moved)"; else echo "  ✓ $legacy cleared"; fi
done

# --------------------------------------------------------------------------
# Step 8 — append migration-log.md (real runs only)
# --------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 0 ]; then
  LOG="$TARGET_ROOT/migration-log.md"
  mkdir -p "$TARGET_ROOT"
  if [ ! -f "$LOG" ]; then printf '# Mega-SDD Path Migration Log\n' > "$LOG"; fi
  {
    printf '\n## Migration %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
    printf -- '- Source layout: legacy (scattered paths)\n'
    printf -- '- Target layout: new (canonical `.mega-sdd/`)\n'
    printf -- '- Tool used: %s\n' "$([ "$IN_GIT" -eq 1 ] && echo 'git mv (history preserved)' || echo 'mv (fallback)')"
  } >> "$LOG"
  echo "migrate-paths: done. Log appended to $LOG"
else
  echo "migrate-paths: dry-run complete — no changes written."
fi

exit 0
