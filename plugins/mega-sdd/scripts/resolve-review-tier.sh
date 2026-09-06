#!/usr/bin/env bash
# resolve-review-tier.sh — v6 P3 (A5): the deterministic review-tier router.
# The six risk signals from review-panel.md §Tier selection, evaluated by
# SCRIPT instead of model judgment (the signals themselves are UNCHANGED):
#   1. target_files path matches the pack's auth_hints/authz_hints globs
#   2. a dependency manifest is in target_files
#   3. target_files count >= 4
#   4. body vocabulary (auth/session/token/crypto/password/payment/upload/
#      role/permission/access/admin/acl/approv- + Indonesian equivalents)
#   5. binding_refs cite a constitution §B (Security) clause (B-NNN)
#   6. unit frontmatter risk: high|critical
#
# PER-LENS ROUTING (v7.8, spec 2026-08-29 Fase 3). The predicate was
# `if fired: tier = "full"` — an OR over six predicates measuring different
# things. Measured on a live 30-unit vault: full 30/30, minimal 0/30, because
# `file_count>=4` (a SIZE fact) fired 22/30. Each signal now buys the lens it
# justifies:
#   spec      = always (the moat lens)
#   standards = always above minimal (cheap; conventions on any new code)
#   quality   = file_count>=3 OR risk: high|critical      (surface area)
#   security  = auth_globs|manifest|constitution_b|vocabulary OR risk: critical
#   design    = added by the CONTROLLER for UI-bearing units, not here
# `tier` is kept as the LABEL of that set (flags/config/bolt-report speak
# tiers): full = security lens in play; minimal = spec only; else standard.
# Signal 4 (vocabulary) is SCOPED to the unit contract sections — see below.
# Output: one JSON line {"tier","lenses":[],"signals_fired":[],"signals_evaluated":[],
# "target_files":N,"task_type":...,"implementer_model","effort","unit_tier"}.
# unit_tier (size-weighted spec 2026-08-23 §1a, A1 option i — approved
# 2026-09-05) is a PAYLOAD label for the dispatch-prompt builder, never a
# routing input: panel lenses + implementer_model are untouched by it.
#   xs    = tier "minimal" AND a small size-proxy from structure this script
#           already parses: acceptance_test entries 1..2 AND work items 1..3
#           (numbered `## Implementation steps` — canonical grammar — or
#           `## Requirements` bullets on legacy units; BOTH must be within
#           ceiling when both exist). Absent/empty/unparsed structure is
#           never small — unknown never lowers a tier.
#   s/m/l = label mapping of the existing verdict (minimal->s, standard->m,
#           full->l).
# The two
# v7.1 fields are DERIVED from the SAME signals (per-unit model routing spec
# 2026-08-22 — rail A5: deterministic evidence, never model self-assessment):
#   implementer_model: opus  <- tier full (a SECURITY signal, v7.8)
#                      haiku <- tier minimal AND task_type verify ONLY
#                      sonnet<- everything else (unknown never lowers a tier)
#   effort:            low for haiku, high otherwise (recorded in the bolt-report;
#                      no per-dispatch effort mechanism exists today — honest)
# The override chain (--review-panel= / --model-tier= > config > auto) is
# applied by the CALLER — this script always reports the auto verdict.
# Exit 0 = verdict printed; 2 = usage/unreadable unit (caller falls back to
# `standard`/`sonnet`, never minimal/haiku — unknown rc != low).
set -u
UNIT=""
PACK_FILE=""
WRITE=0
while [ $# -gt 0 ]; do case "$1" in
  --write) WRITE=1; shift;;
  --unit) UNIT="$2"; shift 2;;
  --unit=*) UNIT="${1#*=}"; shift;;
  --pack) PACK_FILE="$2"; shift 2;;
  --pack=*) PACK_FILE="${1#*=}"; shift;;
  *) echo "usage: resolve-review-tier.sh --unit <U-*.md> [--pack <resolved-pack.md>] [--write]" >&2; exit 2;;
esac; done
[ -n "$UNIT" ] && [ -f "$UNIT" ] || { echo "usage: resolve-review-tier.sh --unit <U-*.md> [--pack <pack.md>]" >&2; exit 2; }

# F-26 (spec 2026-08-30 §3.4): --write persists the verdict as
# <vault>/bolts/U-XXX/review-tier.json — the OBLIGATION KEY of the panel-evidence
# gate (F-07). Keyed at dispatch, like B4 keys on the commit trailer, so a bolt
# dispatched before this version never retro-blocks.
export MEGA_SDD_LIB_DIR="$(cd "$(dirname "$0")" && pwd)/_lib"
V_UNIT="$UNIT" V_PACK="${PACK_FILE:-}" V_WRITE="$WRITE" python3 <<'PYEOF'
import fnmatch, json, os, re, sys

unit_path = os.environ["V_UNIT"]
pack_path = os.environ.get("V_PACK") or ""
try:
    text = open(unit_path, encoding="utf-8", errors="replace").read()
except OSError as e:
    print("FAIL: cannot read unit: %s" % e, file=sys.stderr)
    sys.exit(2)
text = text.lstrip("\ufeff")  # a BOM must not blank the whole frontmatter

# frontmatter block (body starts AFTER the closing --- line)
fm = ""
body = text
if text.startswith("---"):
    end = text.find("\n---", 3)
    if end > 0:
        fm = text[3:end]
        body = text[end + 4:]

m = re.search(r"(?m)^task_type:\s*[\"']?(\w+)", fm)
task_type = m.group(1) if m else ""
m = re.search(r"(?m)^risk:\s*[\"']?(\w+)", fm)
risk = (m.group(1).lower() if m else "")

# target_files paths — block mapping, scalar-list, AND inline-flow shapes;
# quoted paths (spaces) captured whole. A parse-MISS is never a small unit
# (round doc-4): tf_key_present + zero parsed => standard, marked.
tf_key_present = bool(re.search(r"(?m)^target_files:", fm))
tf_block = ""
# (?m) WITHOUT (?s): under DOTALL `[ \t]+.*` swallowed the REST of the
# frontmatter, so on scalar-list shaped target_files the plain-dash fallback
# also counted binding_refs/acceptance items as paths (a 2-file unit measured
# target_files:5 and false-fired file_count — found 2026-09-05, size-weighted
# step 1). The block must stop at the next column-0 key.
m = re.search(r"(?m)^target_files:[ \t]*\n((?:[ \t]+[^\n]*\n?)*)", fm)
if m:
    tf_block = m.group(1)

def _cap(rx, s):
    out = []
    for g in re.findall(rx, s):
        if isinstance(g, tuple):
            g = next((x for x in g if x), "")
        if g:
            out.append(g)
    return out

paths = _cap(r"(?m)^[ \t]*-?[ \t]*path:\s*(?:\"([^\"]+)\"|'([^']+)'|([^\s#]+))", tf_block)
if not paths:
    paths = _cap(r"(?m)^[ \t]*-[ \t]+(?:\"([^\"]+)\"|'([^']+)'|([^\s#:]+))[ \t]*$", tf_block)
if not paths:
    fm_inline = re.search(r"(?m)^target_files:\s*\[([^\]]*)\]", fm)
    if fm_inline:
        paths = [p.strip().strip("\"'") for p in fm_inline.group(1).split(",")
                 if p.strip()]
n_files = len(paths)
parse_note = None
if tf_key_present and n_files == 0 and task_type != "verify":
    parse_note = "target_files_unparsed"

signals_evaluated = ["auth_globs", "manifest", "file_count", "vocabulary",
                    "constitution_b", "risk_field"]
fired = []

# 1. pack auth/authz globs — CASEFOLDED both sides (round blocker: posix
# fnmatch is case-sensitive; `**/auth*` never matched `Auth/LoginController`),
# with a stripped-prefix basename leg so `**/auth*` also reaches a root-level
# `auth.php`.
globs = []
if pack_path and os.path.isfile(pack_path):
    ptxt = open(pack_path, encoding="utf-8", errors="replace").read()
    for key in ("auth_hints", "authz_hints"):
        gm = re.search(r"(?ms)^%s:\s*\n((?:[ \t]+-[ \t]+.*\n?)*)" % key, ptxt)
        if gm:
            globs += re.findall(r"(?m)^[ \t]+-[ \t]+[\"']?([^\s\"'#]+)", gm.group(1))

def _glob_hit(p, g):
    pl, gl = p.lower(), g.lower()
    bl = os.path.basename(pl)
    gtail = gl.split("/")[-1]
    return (fnmatch.fnmatch(pl, gl) or fnmatch.fnmatch(bl, gl)
            or (gtail and fnmatch.fnmatch(bl, gtail))
            or any(fnmatch.fnmatch(seg, gtail) for seg in pl.split("/")))

if any(_glob_hit(p, g) for p in paths for g in globs):
    fired.append("auth_globs")

# 2. dependency manifest in target_files
MANIFESTS = {"package.json", "composer.json", "requirements.txt",
             "pyproject.toml", "go.mod", "Cargo.toml", "Gemfile",
             "build.gradle", "build.gradle.kts", "pom.xml", "mix.exs",
             "pubspec.yaml", "Package.swift", "Pipfile", "build.sbt"}
if any(os.path.basename(p) in MANIFESTS for p in paths):
    fired.append("manifest")

# 3. file count
if n_files >= 4:
    fired.append("file_count")

# 4. body vocabulary — the review-panel.md signal-4 list VERBATIM (round
# doc-3: the script must never drift from the doc it implements). Whole
# words with an optional plural suffix (passwords/tokens/sessions — round
# code-4); multi-word phrases tolerate any whitespace incl. soft wraps;
# derived-form STEMS matched as substrings (the model era handled
# morphology implicitly — authentication/authorization/oauth/menyetujui).
VOCAB = ("auth", "session", "token", "crypto", "password", "payment",
         "upload", "role", "permission", "access", "admin", "acl",
         # Indonesian (review-panel.md signal 4, verbatim)
         "kata sandi", "sandi", "pembayaran", "unggah", "hak akses",
         "peran", "izin", "otorisasi", "autentikasi", "otentikasi",
         "persetujuan")
STEMS = ("approv", "authenticat", "authoriz", "oauth", "setuju")

# v7.8 (spec 2026-08-29 Fase 3): the match is SCOPED to the unit's CONTRACT
# sections. Measured on a live 30-unit vault, the unscoped body match fired
# 18/30 — hitting `## Context (read first)` 9x, `## Goal` 8x and
# `## Implementation steps` 17x, i.e. orientation NARRATIVE. A bank CIF app
# says "peran"/"akses" everywhere it explains itself; that is not evidence of a
# security surface. In `## Hard rules` the same word is a binding claim.
# Scoped: 13/30 on the same vault.
CONTRACT_SECTIONS = ("hard rules", "acceptance criteria", "requirements",
                     "ui contract")


def _contract_text(b):
    parts = re.split(r"(?m)^(##\s+.*)$", b)
    out = []
    for i in range(1, len(parts), 2):
        head = parts[i].lstrip("#").strip().lower()
        head = re.sub(r"\s*\(.*\)\s*$", "", head)   # `## Hard rules (from binding)`
        if head in CONTRACT_SECTIONS:
            out.append(parts[i + 1] if i + 1 < len(parts) else "")
    return "\n".join(out)


contract_l = _contract_text(body).lower()


def _word_hit_in(w, hay):
    pat = r"\s+".join(re.escape(part) for part in w.split())
    return re.search(r"(?<![a-z0-9_])%s(?:e?s)?(?![a-z0-9_])" % pat, hay)


hit = (any(_word_hit_in(w, contract_l) for w in VOCAB)
       or any(st in contract_l for st in STEMS))
if hit:
    fired.append("vocabulary")

# 5. constitution §B clause in binding_refs — anchored to a list-item token
# so a composite claim id (C-B-001) never false-fires (round code-10)
# (?m) without (?s) — same column-0 stop as tf_block above: under DOTALL a
# B-NNN list item in a LATER frontmatter key could false-fire this signal.
brefs = re.search(r"(?m)^binding_refs:[ \t]*\n((?:[ \t]+[^\n]*\n?)*)", fm)
if brefs and re.search(r"(?m)^[ \t]*-[ \t]+[\"']?B-\d{3}\b", brefs.group(1)):
    fired.append("constitution_b")

# 6. risk field — alone forces full
if risk in ("high", "critical"):
    fired.append("risk_field")

# ── Per-lens routing (v7.8, spec 2026-08-29 Fase 3) ─────────────────────────
# The pre-v7.8 predicate was `if fired: tier = "full"` — an OR over six
# predicates that measure completely different things. Measured on a live
# 30-unit vault it produced full 30/30 and minimal 0/30, because `file_count>=4`
# (a SIZE fact, not a risk fact) fired 22/30. With six loose OR-ed predicates,
# P(at least one fires) -> 1 on any real project, so the tier table's stated
# cost control ("routine bolts pay for one lens") controlled nothing.
#
# Each signal now buys the lens it actually JUSTIFIES:
#   file_count / risk        -> surface area to judge   -> quality
#   auth_globs / manifest /
#   constitution_b /
#   vocabulary / risk:critical -> a security surface    -> security
# spec is unconditional (the moat lens); standards is unconditional above
# minimal (sonnet, cheap, judges conventions on any new code). design is added
# by the CONTROLLER for UI-bearing units — this script never sees target_files
# content, only paths, and the design slice is resolved elsewhere.
SECURITY_SIGNALS = {"auth_globs", "manifest", "constitution_b", "vocabulary"}
security = bool(SECURITY_SIGNALS & set(fired)) or risk == "critical"
quality = n_files >= 3 or risk in ("high", "critical")

minimal_ok = (not fired) and (task_type == "verify"
                              or (1 <= n_files <= 2 and task_type != ""))
if parse_note or task_type == "":
    minimal_ok = False

if minimal_ok:
    lenses = ["spec"]
else:
    lenses = ["spec", "standards"]
    if quality:
        lenses.insert(1, "quality")
    if security:
        lenses.insert(2 if quality else 1, "security")

# `tier` is retained as the LABEL of that set — the --review-panel= flag, the
# config key and the bolt-report all still speak in tiers, and the model
# routing below keys on it. full = the security lens is in play.
if security and not minimal_ok:
    tier = "full"
elif minimal_ok:
    tier = "minimal"
else:
    tier = "standard"

if task_type == "" and not parse_note:
    # unparseable frontmatter (no task_type at all) — UNKNOWN, and unknown is
    # never a LOW tier (doctrine). minimal_ok already excluded it above.
    parse_note = "frontmatter_unparsed"

# v7.1 per-unit model routing — derived from the SAME verdict, no new inputs.
# haiku is verify-only (the catalog's own haiku rubric almost never fits
# code-writing units); a parse_note/unknown never lowers the model tier —
# the same doctrine as the panel tier above.
if tier == "full":
    implementer_model = "opus"
elif tier == "minimal" and task_type == "verify":
    implementer_model = "haiku"
else:
    implementer_model = "sonnet"
effort = "low" if implementer_model == "haiku" else "high"

# ── unit_tier (size-weighted spec 2026-08-23 §1a, A1 option i) ───────────────
# Size-proxy over structure already parsed here — a payload label for the
# dispatch builder, NEVER a routing input. The proxy can only shrink what a
# zero-signal unit LOADS, never raise a risk threshold; any absent/empty
# section or parse_note means no size evidence, and unknown never lowers.
# (?m) WITHOUT (?s): the block must stop at the next column-0 key —
# under DOTALL `[ \t]+.*` swallows the rest of the frontmatter and
# binding_refs items would inflate the count.
acc_m = re.search(r"(?m)^acceptance_test:[ \t]*\n((?:[ \t]+[^\n]*\n?)*)", fm)
n_accept = len(re.findall(r"(?m)^[ \t]+-[ \t]", acc_m.group(1))) if acc_m else 0


def _section_items(names, item_rx):
    # returns None when no named section exists; else the item count
    parts = re.split(r"(?m)^(##\s+.*)$", body)
    for i in range(1, len(parts), 2):
        head = parts[i].lstrip("#").strip().lower()
        head = re.sub(r"\s*\(.*\)\s*$", "", head)
        if head in names:
            sect = parts[i + 1] if i + 1 < len(parts) else ""
            return len(re.findall(item_rx, sect))
    return None


n_steps = _section_items({"implementation steps"}, r"(?m)^\s*\d+[.)]\s")
n_reqs = _section_items({"requirements"}, r"(?m)^\s*[-*]\s")
size_small = (1 <= n_accept <= 2
              and not (n_steps is None and n_reqs is None)
              and (n_steps is None or 1 <= n_steps <= 3)
              and (n_reqs is None or 1 <= n_reqs <= 3))
if tier == "minimal":
    unit_tier = "xs" if (size_small and not parse_note) else "s"
elif tier == "standard":
    unit_tier = "m"
else:
    unit_tier = "l"

out = {"tier": tier, "lenses": lenses, "signals_fired": fired,
       "signals_evaluated": signals_evaluated,
       "target_files": n_files, "task_type": task_type,
       "implementer_model": implementer_model, "effort": effort,
       "unit_tier": unit_tier}
if parse_note:
    out["parse_note"] = parse_note
if os.environ.get("V_WRITE") == "1":
    sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
    import plugin_meta
    ud = os.path.dirname(os.path.abspath(unit_path))
    # <vault>/units/U-X.md -> <vault>/bolts/U-X ; <vault>/units/U-X/unit.md -> same
    if os.path.basename(ud) == "units":
        uid = os.path.splitext(os.path.basename(unit_path))[0]
        vault_root = os.path.dirname(ud)
    else:
        uid = os.path.basename(ud)
        vault_root = os.path.dirname(os.path.dirname(ud))
    m_uid = re.search(r"(?m)^unit_id:\s*[\"']?(U-[A-Za-z0-9_-]+)", fm)
    if m_uid:
        uid = m_uid.group(1)
    bolt_dir = os.path.join(vault_root, "bolts", uid)
    rec = dict(out)
    rec["unit_id"] = uid
    rec["written_by"] = "resolve-review-tier.sh"
    rec.update(plugin_meta.stamp(os.environ["MEGA_SDD_LIB_DIR"]))
    try:
        os.makedirs(bolt_dir, exist_ok=True)
        tgt = os.path.join(bolt_dir, "review-tier.json")
        tmp = tgt + ".tmp.%d" % os.getpid()
        with open(tmp, "w") as fh:
            json.dump(rec, fh, indent=1)
        os.replace(tmp, tgt)
        out["review_tier_path"] = tgt
    except OSError as e:
        print("WARN: could not write review-tier.json: %s" % e, file=sys.stderr)
print(json.dumps(out, separators=(",", ":")))
sys.exit(0)
PYEOF
