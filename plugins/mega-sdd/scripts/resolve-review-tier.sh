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
#   6. unit frontmatter risk: high|critical (alone forces full)
# Tier predicate (P3 rewrite — makes `minimal` reachable):
#   minimal  = task_type verify OR (<=2 target files AND zero signals)
#   full     = ANY signal fired
#   standard = everything else
# Output: one JSON line {"tier","signals_fired":[],"signals_evaluated":[],
# "target_files":N,"task_type":...,"implementer_model","effort"}. The two
# v7.1 fields are DERIVED from the SAME signals (per-unit model routing spec
# 2026-08-22 — rail A5: deterministic evidence, never model self-assessment):
#   implementer_model: opus  <- tier full (any risk signal)
#                      haiku <- tier minimal AND task_type verify ONLY
#                      sonnet<- everything else (unknown never lowers a tier)
#   effort:            low for haiku, high otherwise (recorded for telemetry;
#                      no per-dispatch effort mechanism exists today — honest)
# The override chain (--review-panel= / --model-tier= > config > auto) is
# applied by the CALLER — this script always reports the auto verdict.
# Exit 0 = verdict printed; 2 = usage/unreadable unit (caller falls back to
# `standard`/`sonnet`, never minimal/haiku — unknown rc != low).
set -u
UNIT=""
PACK_FILE=""
while [ $# -gt 0 ]; do case "$1" in
  --unit) UNIT="$2"; shift 2;;
  --unit=*) UNIT="${1#*=}"; shift;;
  --pack) PACK_FILE="$2"; shift 2;;
  --pack=*) PACK_FILE="${1#*=}"; shift;;
  *) echo "usage: resolve-review-tier.sh --unit <U-*.md> [--pack <resolved-pack.md>]" >&2; exit 2;;
esac; done
[ -n "$UNIT" ] && [ -f "$UNIT" ] || { echo "usage: resolve-review-tier.sh --unit <U-*.md> [--pack <pack.md>]" >&2; exit 2; }

V_UNIT="$UNIT" V_PACK="${PACK_FILE:-}" python3 <<'PYEOF'
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
m = re.search(r"(?ms)^target_files:\s*\n((?:[ \t]+.*\n?)*)", fm)
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
body_l = body.lower()

def _word_hit(w):
    pat = r"\s+".join(re.escape(part) for part in w.split())
    return re.search(r"(?<![a-z0-9_])%s(?:e?s)?(?![a-z0-9_])" % pat, body_l)

hit = any(_word_hit(w) for w in VOCAB) or any(st in body_l for st in STEMS)
if hit:
    fired.append("vocabulary")

# 5. constitution §B clause in binding_refs — anchored to a list-item token
# so a composite claim id (C-B-001) never false-fires (round code-10)
brefs = re.search(r"(?ms)^binding_refs:\s*\n((?:[ \t]+.*\n?)*)", fm)
if brefs and re.search(r"(?m)^[ \t]*-[ \t]+[\"']?B-\d{3}\b", brefs.group(1)):
    fired.append("constitution_b")

# 6. risk field — alone forces full
if risk in ("high", "critical"):
    fired.append("risk_field")

if fired:
    tier = "full"
elif parse_note:
    # a parse-miss is UNKNOWN, and unknown is never a LOW tier (doctrine) —
    # zero-parsed target_files on a non-verify unit lands standard, marked
    tier = "standard"
elif task_type == "verify" or (1 <= n_files <= 2 and task_type != ""):
    # zero DECLARED files on a non-verify unit is unknown scope, not a small
    # unit (round code-2) — only verify may be minimal file-less
    tier = "minimal"
elif task_type == "":
    # unparseable frontmatter (no task_type at all) — same unknown rule
    tier = "standard"
    parse_note = parse_note or "frontmatter_unparsed"
else:
    tier = "standard"

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

out = {"tier": tier, "signals_fired": fired,
       "signals_evaluated": signals_evaluated,
       "target_files": n_files, "task_type": task_type,
       "implementer_model": implementer_model, "effort": effort}
if parse_note:
    out["parse_note"] = parse_note
print(json.dumps(out, separators=(",", ":")))
sys.exit(0)
PYEOF
