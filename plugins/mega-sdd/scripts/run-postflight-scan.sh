#!/usr/bin/env bash
# run-postflight-scan.sh — deterministic writer for <vault>/bolts/U-XXX/postflight.json (B1).
#
# S6 EB-GATE-4: the postflight evidence artifact used to be agent-written on
# trust — the gate's own remediation text coached "or write the postflight.json
# evidence". This wrapper is now the ONLY sanctioned write path (the artifact is
# Write/Edit-guarded by the PreToolUse hook): it EXECUTES the unit's Hard rules
# against real git/filesystem state and records per-rule verdicts itself.
#
# Rule execution:
#   v1 strict productions (machine-checked here):
#     - DO NOT modify <path>                → unit's bolt commits must not touch <path>
#                                             (preflight.json sha256 snapshot used when present)
#     - DO NOT add new <manifest> dependencies → dep-key set of <manifest> at HEAD vs
#                                             before the unit's first bolt commit
#     - <glob> MUST follow <case> naming    → files the bolt commits ADDED matching <glob>
#     - function <name> MUST preserve signature: <sig> → decl line still matches
#     - file <path> MUST exist after bolt   → existence probe
#   v2 ast-grep YAML fenced blocks          → `ast-grep scan` (match = VIOLATED);
#                                             ast-grep absent → verdict tool_missing (non-pass)
#   generic directives (MUST/DO NOT prose — not machine-checkable by construction)
#     → verdict `attested` ONLY with --attest-directives="<who/why>" (recorded);
#       otherwise `directive_unverified` (non-pass). See hard-rule-scan.md §directive rules.
#
# Usage:
#   run-postflight-scan.sh --cwd=<project-root> --unit=U-XXX \
#       [--attest-directives="<reason>"] [--quiet]
# Exit: 0 = all verdicts pass/attested (artifact written, gate state refreshed)
#       1 = ≥1 non-pass verdict (artifact written — B1 stays closed until the code is fixed)
#       2 = cannot run (unit not found / not a git repo)
set -uo pipefail

CWD=""
UNIT=""
ATTEST=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --unit=*) UNIT="${arg#*=}" ;;
    --attest-directives=*) ATTEST="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR" ] && [ -n "${CWD:-}" ]; then . "$_RPR"; CWD=$(resolve_project_root "$CWD"); fi
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then echo "ERROR: --cwd=<project-root> required" >&2; exit 2; fi
if [ -z "$UNIT" ]; then echo "ERROR: --unit=U-XXX required" >&2; exit 2; fi
git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: not a git repo" >&2; exit 2; }
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

CWD="$CWD" UNIT="$UNIT" ATTEST="$ATTEST" QUIET="$QUIET" python3 <<'PYEOF'
import fnmatch, glob, hashlib, json, os, re, shutil, subprocess, sys, tempfile
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_layouts

cwd = os.environ["CWD"]
unit_id = os.environ["UNIT"]
attest = os.environ.get("ATTEST", "")
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def git(*a):
    return subprocess.run(["git", "-C", cwd, *a], capture_output=True, text=True)

PREFIX = git("rev-parse", "--show-prefix").stdout.strip()

uf = vault_layouts.find_unit_file(cwd, unit_id)
if not uf:
    print("ERROR: unit %s not found under any vault layout" % unit_id, file=sys.stderr)
    sys.exit(2)
# vault root: <vault>/units/U-X.md → up 2; <vault>/units/U-X/unit.md → up 3
d = os.path.dirname(uf)
vault_root = os.path.dirname(d) if os.path.basename(d) == "units" else os.path.dirname(os.path.dirname(d))
bolt_dir = os.path.join(vault_root, "bolts", unit_id)

text = open(uf).read()
m = re.search(r"(?ims)^##[ \t]+Hard[ \t]+rules\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)", text)
hr_block = m.group(1) if m else ""

# ── Split fenced v2 YAML blocks from v1/directive dash lines ─────────────────
v2_rules = re.findall(r"```ya?ml\s*\n(.*?)```", hr_block, re.DOTALL)
lines = []
in_fence = False
for ln in hr_block.splitlines():
    s = ln.strip()
    if s.startswith("```"):
        in_fence = not in_fence
        continue
    if in_fence or not s or s.startswith("#") or s.startswith("<"):
        continue
    if re.match(r"^(?:Citation|Source|Ref(?:erence)?|From)\s*:", s, re.IGNORECASE):
        continue
    if s.startswith("- "):
        lines.append(s[2:].strip())

# ── The unit's bolt commits (same identity grammar as validate-bolt-artifacts) ─
UNIT_LEGACY = re.compile(r"\(bolt\):\s*(U-[A-Za-z0-9_-]+)")
UNIT_SCOPE = re.compile(r"^[A-Za-z]+!?\((U-[A-Za-z0-9_-]+)\)!?:")
UNIT_ANY = re.compile(r"(U-[A-Za-z0-9_-]+)")
fmt = "%x01%H%x02%s%x02%(trailers:key=Unit,valueonly,separator=%x2C)"
args = ["log", "--format=" + fmt, "--name-status", "-300"]
if PREFIX:
    args += ["--", PREFIX.rstrip("/")]
r = git(*args)
unit_commits = []   # newest-first [(sha, [(status, relpath)])]
for chunk in r.stdout.split("\x01"):
    if not chunk.strip():
        continue
    head, _, tail = chunk.partition("\n")
    parts = head.split("\x02")
    sha = parts[0].strip()
    subj = parts[1] if len(parts) > 1 else ""
    trailers = parts[2] if len(parts) > 2 else ""
    mm = UNIT_LEGACY.search(subj) or UNIT_SCOPE.match(subj)
    uid = mm.group(1) if mm else (UNIT_ANY.search(trailers).group(1) if trailers and UNIT_ANY.search(trailers) else None)
    if uid != unit_id:
        continue
    files = []
    for l in tail.splitlines():
        l = l.strip()
        if not l or "\t" not in l:
            continue
        st, _, p = l.partition("\t")
        p = p.split("\t")[-1]  # renames: old\tnew — take new
        if PREFIX and p.startswith(PREFIX):
            p = p[len(PREFIX):]
        files.append((st[:1], p))
    unit_commits.append((sha, files))

touched = {p for _, fl in unit_commits for _, p in fl}
added = {p for _, fl in unit_commits for st, p in fl if st == "A"}
oldest_sha = unit_commits[-1][0] if unit_commits else None

# preflight snapshot (written by the skill's pre-flight step, when present)
preflight = {}
pf_path = os.path.join(bolt_dir, "preflight.json")
if os.path.isfile(pf_path):
    try:
        preflight = json.load(open(pf_path))
    except (OSError, ValueError):
        preflight = {}

def sha256_of(path):
    try:
        h = hashlib.sha256()
        with open(path, "rb") as f:
            for blk in iter(lambda: f.read(65536), b""):
                h.update(blk)
        return h.hexdigest()
    except OSError:
        return None

results = []

STRICT = [
    ("DO_NOT_MODIFY", re.compile(r"^DO NOT modify\s+(\S+)")),
    ("DO_NOT_ADD_DEPS", re.compile(r"^DO NOT add new\s+(\S+)\s+dependencies")),
    ("NAMING_RULE", re.compile(r"^(\S+)\s+MUST follow\s+(kebab-case|camelCase|snake_case|PascalCase)\s+naming")),
    ("SIGNATURE_RULE", re.compile(r"^function\s+(\S+)\s+MUST preserve signature:\s+(.*)$")),
    ("FILE_PRESENCE_RULE", re.compile(r"^file\s+(\S+)\s+MUST exist after bolt")),
]
CASE_RE = {
    "kebab-case": re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$"),
    "camelCase": re.compile(r"^[a-z][a-zA-Z0-9]*$"),
    "snake_case": re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)*$"),
    "PascalCase": re.compile(r"^[A-Z][a-zA-Z0-9]*$"),
}
DIRECTIVE = re.compile(r"^(?:MUST NOT|MUST|DO NOT|NEVER|ALWAYS)\b")

DEP_KEYS = {
    "composer.json": ("require", "require-dev"),
    "package.json": ("dependencies", "devDependencies"),
}

def dep_set(raw, manifest):
    try:
        d = json.loads(raw)
    except (ValueError, TypeError):
        return None
    keys = DEP_KEYS.get(os.path.basename(manifest))
    if not keys:
        return None
    out = set()
    for k in keys:
        out |= set((d.get(k) or {}).keys())
    return out

def find_decl_line(name):
    """First function/method declaration line for `name` in tracked source.
    Uses POSIX [[:space:]] not \\s: git grep runs the platform regex engine (BSD on
    macOS) which does NOT honor \\s — S6 writers-lens fix: \\s matched NOTHING, so every
    SIGNATURE_RULE emitted a false 'not found' FAIL that permanently blocked B1. Also
    broadened past the C-style `function NAME(` shape to arrow/expr and method decls."""
    n = re.escape(name)
    for pat in (r"(function|def|fn|func)[[:space:]]+%s[[:space:]]*\(" % n,   # function/def/fn/func NAME(
                r"(const|let|var)[[:space:]]+%s[[:space:]]*=" % n,            # const NAME = (arrow/expr)
                r"%s[[:space:]]*[:=][[:space:]]*(async[[:space:]]*)?\(" % n,  # NAME: (…) => / NAME = (…) =>
                r"%s[[:space:]]*\([^)]*\)[[:space:]]*\{" % n):                # method NAME(...) {
        r = git("grep", "-nE", pat)
        for l in r.stdout.splitlines():
            parts = l.split(":", 2)
            if len(parts) != 3:
                continue
            fpath = parts[0]
            # Match only REAL source — never the unit spec / vault docs, which contain
            # the rule's own `function NAME MUST preserve signature: function NAME(...)`
            # text and would otherwise self-match (the \s bug had masked this).
            if (fpath.startswith(".mega-sdd/") or fpath.startswith("docs/mega-sdd/")
                    or fpath.lower().endswith((".md", ".markdown"))):
                continue
            return parts[2].strip(), "%s:%s" % (parts[0], parts[1])
    return None, None

def _glob_match(p, pat):
    """Glob match honoring `**` (any dirs incl zero) and stripping the documented
    `file:` prefix. S6 writers-lens fix: fnmatch never stripped `file:` (schema-conformant
    rules silently PASSED) and had no `**` recursion (app/**/*.php missed a file directly
    under app/). `*`/`?` are segment-scoped ([^/]) — proper glob, not fnmatch's '/'-eating."""
    pat = pat[5:] if pat.startswith("file:") else pat
    rx, i = [], 0
    while i < len(pat):
        if pat[i:i+3] == "**/":
            rx.append(r"(?:.*/)?"); i += 3
        elif pat[i:i+2] == "**":
            rx.append(r".*"); i += 2
        elif pat[i] == "*":
            rx.append(r"[^/]*"); i += 1
        elif pat[i] == "?":
            rx.append(r"[^/]"); i += 1
        else:
            rx.append(re.escape(pat[i])); i += 1
    cre = re.compile("^(?:%s)$" % "".join(rx))
    return bool(cre.match(p)) or bool(cre.match(os.path.basename(p)))

for raw in lines:
    matched = None
    for rtype, rx in STRICT:
        mm = rx.match(raw)
        if mm:
            matched = (rtype, mm)
            break
    if matched:
        rtype, mm = matched
        if rtype == "DO_NOT_MODIFY":
            path = mm.group(1)
            snap = None
            for pr in (preflight.get("rules") or []):
                if pr.get("type") == "DO_NOT_MODIFY" and pr.get("path") == path:
                    snap = pr.get("sha256")
            if snap is not None:
                cur = sha256_of(os.path.join(cwd, path))
                ok = (cur == snap) or (snap == "absent" and cur is None)
                ev = "sha256 %s (preflight snapshot)" % ("unchanged" if ok else "MISMATCH — pre: %s, post: %s" % (snap, cur))
            elif unit_commits:
                ok = path not in touched
                ev = ("bolt commits did not touch %s" % path) if ok else \
                     ("bolt commit touched %s" % path)
            else:
                ok = False
                ev = "no bolt commit found for %s and no preflight snapshot — cannot verify" % unit_id
            results.append({"type": rtype, "rule": raw, "verdict": "pass" if ok else "fail", "evidence": ev})
        elif rtype == "DO_NOT_ADD_DEPS":
            manifest = mm.group(1)
            if not unit_commits:
                results.append({"type": rtype, "rule": raw, "verdict": "fail",
                                "evidence": "no bolt commit found for %s — cannot diff %s" % (unit_id, manifest)})
                continue
            mrel = (PREFIX + manifest) if PREFIX else manifest
            # Root/initial-commit safety (S6 writers-lens fix): `git show <sha>^:...`
            # and `git diff <sha>^..HEAD` both fail on a parentless commit → empty
            # before → a dep-adding FIRST bolt used to pass OPEN. Diff against the
            # empty-tree object so a brand-new manifest's whole dep set is 'added'.
            EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
            has_parent = git("rev-parse", "--verify", "-q", "%s^" % oldest_sha).returncode == 0
            if has_parent:
                base_ref = "%s^" % oldest_sha
                before = git("show", "%s:%s" % (base_ref, mrel)).stdout
            else:
                base_ref = EMPTY_TREE
                before = ""   # root commit: the manifest is brand-new, no prior deps
            cur = ""
            try:
                cur = open(os.path.join(cwd, manifest)).read()
            except OSError:
                pass
            b, a = dep_set(before, manifest), dep_set(cur, manifest)
            if b is None and not has_parent and a is not None:
                b = set()     # parseable new manifest at a root commit → 0 prior deps
            if b is not None and a is not None:
                new = sorted(a - b)
                ok = not new
                ev = "dep keys unchanged" if ok else "NEW dependencies: %s" % ", ".join(new)
            else:
                # non-JSON manifest: added dep-looking lines in the unit's diff
                dr = git("diff", "%s..HEAD" % base_ref, "--", mrel)
                new_lines = [l[1:].strip() for l in dr.stdout.splitlines()
                             if l.startswith("+") and not l.startswith("+++") and l[1:].strip()
                             and not l[1:].strip().startswith(("#", "//"))]
                ok = not new_lines
                ev = "no added lines in %s" % manifest if ok else \
                     "added lines in %s: %s" % (manifest, "; ".join(new_lines[:5]))
            results.append({"type": rtype, "rule": raw, "verdict": "pass" if ok else "fail", "evidence": ev})
        elif rtype == "NAMING_RULE":
            pat, style = mm.group(1), mm.group(2)
            rx2 = CASE_RE[style]
            matched_files = [p for p in sorted(added) if _glob_match(p, pat)]
            bad = []
            for p in matched_files:
                # First dot, not last: user-profile.blade.php / x.test.js -> stem
                # 'user-profile' / 'x' (splitext left the inner '.' → false FAIL).
                stem = os.path.basename(p).split(".", 1)[0]
                if stem and not rx2.match(stem):
                    bad.append(p)
            ok = not bad
            ev = ("all %d new file(s) matching %s follow %s" % (len(matched_files), pat, style)) if ok \
                 else "violations: %s" % ", ".join(bad[:5])
            results.append({"type": rtype, "rule": raw, "verdict": "pass" if ok else "fail", "evidence": ev})
        elif rtype == "SIGNATURE_RULE":
            name, sig = mm.group(1), mm.group(2).strip()
            decl, loc = find_decl_line(name)
            snap = None
            for pr in (preflight.get("rules") or []):
                if pr.get("type") == "SIGNATURE_RULE" and pr.get("function") == name:
                    snap = pr.get("signature_at_preflight")
            if decl is None:
                results.append({"type": rtype, "rule": raw, "verdict": "fail",
                                "evidence": "function %s not found in tracked source" % name})
            elif snap:
                norm = lambda s: re.sub(r"\s+", "", s)
                ok = norm(snap) in norm(decl) or norm(decl.split("{")[0]) == norm(snap)
                results.append({"type": rtype, "rule": raw, "verdict": "pass" if ok else "fail",
                                "evidence": "decl at %s: %s (preflight: %s)" % (loc, decl[:120], snap[:120])})
            else:
                # no snapshot: param-token containment against the rule's declared sig
                toks = [t.strip() for t in re.split(r"[(),]", sig) if t.strip() and "=>" not in t]
                norm_decl = re.sub(r"\s+", " ", decl)
                missing = [t for t in toks if re.sub(r"\s+", " ", t) not in norm_decl]
                ok = not missing
                results.append({"type": rtype, "rule": raw, "verdict": "pass" if ok else "fail",
                                "evidence": "decl at %s: %s%s" % (loc, decl[:120],
                                            "" if ok else " — missing sig token(s): %s" % ", ".join(missing[:3]))})
        elif rtype == "FILE_PRESENCE_RULE":
            path = mm.group(1)
            ok = os.path.exists(os.path.join(cwd, path))
            results.append({"type": rtype, "rule": raw, "verdict": "pass" if ok else "fail",
                            "evidence": "%s %s" % (path, "exists" if ok else "MISSING")})
        continue
    if DIRECTIVE.match(raw):
        if attest:
            results.append({"type": "directive", "rule": raw, "verdict": "attested",
                            "evidence": "attested: %s" % attest})
        else:
            results.append({"type": "directive", "rule": raw, "verdict": "directive_unverified",
                            "evidence": "generic directive — not machine-checkable; re-run with "
                                        "--attest-directives=\"<who/why>\" after controller/panel review"})
        continue
    results.append({"type": "unparseable", "rule": raw, "verdict": "fail",
                    "evidence": "line matches no v1 production and is not a directive — fix the unit's ## Hard rules"})

# ── v2 ast-grep rules ────────────────────────────────────────────────────────
if v2_rules:
    astgrep = shutil.which("ast-grep")
    for i, ry in enumerate(v2_rules):
        rid_m = re.search(r"^id:\s*(\S+)", ry, re.MULTILINE)
        rid = rid_m.group(1) if rid_m else "v2-rule-%d" % (i + 1)
        if not astgrep:
            results.append({"type": "v2_ast_grep", "rule": rid, "verdict": "tool_missing",
                            "evidence": "ast-grep not installed — cannot execute v2 rule (brew install ast-grep)"})
            continue
        with tempfile.NamedTemporaryFile("w", suffix=".yml", delete=False) as tf:
            tf.write(ry)
            tmp_rule = tf.name
        try:
            rr = subprocess.run([astgrep, "scan", "--rule", tmp_rule, "--json", cwd],
                                capture_output=True, text=True)
            if rr.returncode not in (0, 1):
                results.append({"type": "v2_ast_grep", "rule": rid, "verdict": "fail",
                                "evidence": "ast-grep error: %s" % rr.stderr.strip()[:200]})
                continue
            try:
                matches = json.loads(rr.stdout or "[]")
            except ValueError:
                matches = []
            ok = not matches
            ev = "zero matches" if ok else "%d match(es), first: %s:%s" % (
                len(matches), matches[0].get("file", "?"), (matches[0].get("range", {}).get("start", {}) or {}).get("line", "?"))
            results.append({"type": "v2_ast_grep", "rule": rid, "verdict": "pass" if ok else "fail", "evidence": ev})
        finally:
            os.unlink(tmp_rule)

if not results:
    results.append({"type": "none", "rule": "(no Hard rules found)", "verdict": "pass",
                    "evidence": "## Hard rules section empty or absent — nothing to post-validate"})

ok_all = all(r["verdict"] in ("pass", "attested") for r in results)
head_sha = git("rev-parse", "HEAD").stdout.strip()
artifact = {
    "unit_id": unit_id,
    "scanned_at": ts,
    "status": "pass" if ok_all else "fail",
    "head_sha": head_sha,
    "written_by": "run-postflight-scan.sh",
    "rules": results,
}
os.makedirs(bolt_dir, exist_ok=True)
target = os.path.join(bolt_dir, "postflight.json")
tmp = target + ".tmp.%d" % os.getpid()
with open(tmp, "w") as f:
    json.dump(artifact, f, indent=1)
os.replace(tmp, target)
if not quiet:
    print(json.dumps(artifact, indent=1))
sys.exit(0 if ok_all else 1)
PYEOF
PF_EXIT=$?

# Refresh the B1 gate state immediately so the fix is visible without waiting
# for the next Stop / gate-time re-derivation.
bash "${SCRIPT_DIR}/validate-bolt-artifacts.sh" --cwd="$CWD" --postflight-scan --quiet >/dev/null 2>&1 || true
exit $PF_EXIT
