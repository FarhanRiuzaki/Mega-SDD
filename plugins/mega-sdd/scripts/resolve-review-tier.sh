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
# "target_files":N,"task_type":...}. The override chain (--review-panel= >
# config review_panel: > auto) is applied by the CALLER — this script always
# reports the auto verdict. Exit 0 = verdict printed; 2 = usage/unreadable
# unit (caller falls back to `standard`, never minimal — unknown rc != low).
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

# frontmatter block
fm = ""
if text.startswith("---"):
    end = text.find("\n---", 3)
    if end > 0:
        fm = text[3:end]
body = text[len(fm):]

task_type = (re.search(r"(?m)^task_type:\s*(\S+)", fm) or [None, ""])[1] if fm else ""
m = re.search(r"(?m)^task_type:\s*[\"']?(\w+)", fm)
task_type = m.group(1) if m else ""
m = re.search(r"(?m)^risk:\s*[\"']?(\w+)", fm)
risk = (m.group(1).lower() if m else "")

# target_files paths (list items with `path:` under target_files, plus simple
# `- path` bullets) — tolerant of both mapping and scalar-list shapes
tf_block = ""
m = re.search(r"(?ms)^target_files:\s*\n((?:[ \t]+.*\n?)*)", fm)
if m:
    tf_block = m.group(1)
paths = re.findall(r"(?m)^[ \t]*-?[ \t]*path:\s*[\"']?([^\s\"'#]+)", tf_block)
if not paths:
    paths = re.findall(r"(?m)^[ \t]*-[ \t]+[\"']?([^\s\"'#:]+)[\"']?\s*$", tf_block)
n_files = len(paths)

signals_evaluated = ["auth_globs", "manifest", "file_count", "vocabulary",
                    "constitution_b", "risk_field"]
fired = []

# 1. pack auth/authz globs
globs = []
if pack_path and os.path.isfile(pack_path):
    ptxt = open(pack_path, encoding="utf-8", errors="replace").read()
    for key in ("auth_hints", "authz_hints"):
        gm = re.search(r"(?ms)^%s:\s*\n((?:[ \t]+-[ \t]+.*\n?)*)" % key, ptxt)
        if gm:
            globs += re.findall(r"(?m)^[ \t]+-[ \t]+[\"']?([^\s\"'#]+)", gm.group(1))
if any(fnmatch.fnmatch(p, g) or fnmatch.fnmatch(os.path.basename(p), g)
       for p in paths for g in globs):
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

# 4. body vocabulary — whole words; approv- is the sole deliberate prefix
VOCAB = ("auth", "session", "token", "crypto", "password", "payment",
         "upload", "role", "permission", "access", "admin", "acl",
         # Indonesian equivalents (review-panel.md signal 4)
         "otentikasi", "otorisasi", "kata sandi", "pembayaran", "unggah",
         "peran", "izin", "akses", "persetujuan")
body_l = body.lower()
hit = any(re.search(r"(?<![a-z0-9_])%s(?![a-z0-9_])" % re.escape(w), body_l)
          for w in VOCAB) or re.search(r"(?<![a-z0-9_])approv", body_l)
if hit:
    fired.append("vocabulary")

# 5. constitution §B clause in binding_refs
brefs = re.search(r"(?ms)^binding_refs:\s*\n((?:[ \t]+.*\n?)*)", fm)
if brefs and re.search(r"\bB-\d{3}\b", brefs.group(1)):
    fired.append("constitution_b")

# 6. risk field — alone forces full
if risk in ("high", "critical"):
    fired.append("risk_field")

if fired:
    tier = "full"
elif task_type == "verify" or n_files <= 2:
    tier = "minimal"
else:
    tier = "standard"

print(json.dumps({"tier": tier, "signals_fired": fired,
                  "signals_evaluated": signals_evaluated,
                  "target_files": n_files, "task_type": task_type},
                 separators=(",", ":")))
sys.exit(0)
PYEOF
