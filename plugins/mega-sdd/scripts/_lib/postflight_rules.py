# postflight_rules.py — the SHARED B1 Hard-rule execution engine.
#
# ONE implementation of the post-flight Hard-rule scan, imported by BOTH:
#   - scripts/run-postflight-scan.sh   (the sanctioned single-unit WRITER; a human
#     invokes it, optionally with --attest-directives, and it writes postflight.json)
#   - scripts/validate-bolt-artifacts.sh --postflight-scan --recompute  (the GATE:
#     recomputes every committed Hard-rule bolt from git/fs ground truth at gate time,
#     reusing ONE walk, then evaluates — a forged/stale postflight.json is overwritten)
#
# Factoring the engine here (not copy-pasted) is a hard requirement: if the gate's
# recompute diverged from the writer's logic, an honest artifact would false-block on
# engine drift. Both call scan_unit(); run-postflight-scan.sh output stays byte-identical.
#
# Rule execution (unchanged contract — see run-postflight-scan.sh header / hard-rule-scan.md):
#   v1 strict productions   → machine-checked against git/fs
#   v2 ast-grep YAML fences → `ast-grep scan` (match = VIOLATED; absent → tool_missing)
#   generic directives      → verdict `attested` ONLY with an attest reason; else
#                             `directive_unverified`. At the GATE the attest reason is
#                             carried forward from the prior artifact (see scan_unit).
import fnmatch, glob, hashlib, json, os, re, shutil, subprocess, tempfile

# ── Commit identity (mirrors validate-bolt-artifacts.sh PY_COMMON) ───────────
UNIT_LEGACY = re.compile(r"\(bolt\):\s*(U-[A-Za-z0-9_-]+)")
UNIT_SCOPE = re.compile(r"^[A-Za-z]+!?\((U-[A-Za-z0-9_-]+)\)!?:")
UNIT_ANY = re.compile(r"(U-[A-Za-z0-9_-]+)")


def unit_of(subj, trailers):
    m = UNIT_LEGACY.search(subj) or UNIT_SCOPE.match(subj)
    if m:
        return m.group(1)
    if trailers:
        m = UNIT_ANY.search(trailers)
        if m:
            return m.group(1)
    return None


def walk_unit_commits(git, prefix, n=300):
    """{unit_id: newest-first [(sha, [(status, relpath)])]} in ONE git call.

    Pathspec-scoped to THIS project subtree via `-- .` (relative to git's -C cwd),
    the EB-VAL-5-correct form: a repo-root-relative `-- <prefix>` pathspec is resolved
    as prefix/prefix under a subproject and matches nothing (silently disabling B1).
    Renames (old\\tnew) take the new path; the project prefix is stripped from names."""
    fmt = "%x01%H%x02%s%x02%(trailers:key=Unit,valueonly,separator=%x2C)"
    args = ["log", "--format=" + fmt, "--name-status", "-%d" % n]
    if prefix:
        args += ["--", "."]
    r = git(*args)
    out = {}
    for chunk in r.stdout.split("\x01"):
        if not chunk.strip():
            continue
        head, _, tail = chunk.partition("\n")
        parts = head.split("\x02")
        sha = parts[0].strip()
        subj = parts[1] if len(parts) > 1 else ""
        trailers = parts[2] if len(parts) > 2 else ""
        uid = unit_of(subj, trailers)
        if not uid:
            continue
        files = []
        for l in tail.splitlines():
            l = l.strip()
            if not l or "\t" not in l:
                continue
            st, _, p = l.partition("\t")
            p = p.split("\t")[-1]  # renames: old\tnew — take new
            if prefix and p.startswith(prefix):
                p = p[len(prefix):]
            files.append((st[:1], p))
        out.setdefault(uid, []).append((sha, files))  # newest-first (git log order)
    return out


def extract_hard_rules(unit_text):
    """(dash_lines, v2_yaml_rules) from the unit's `## Hard rules` section."""
    m = re.search(r"(?ims)^##[ \t]+Hard[ \t]+rules\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)", unit_text)
    hr_block = m.group(1) if m else ""
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
    return lines, v2_rules


def sha256_of(path):
    try:
        h = hashlib.sha256()
        with open(path, "rb") as f:
            for blk in iter(lambda: f.read(65536), b""):
                h.update(blk)
        return h.hexdigest()
    except OSError:
        return None


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


def find_decl_line(git, name):
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


def _attested_directives(prior_artifact):
    """rule-text set that `prior_artifact` recorded as an attested directive.

    Carry-forward at the GATE: the gate recomputes without an attest reason, and must
    NOT wipe a human's prior `--attest-directives` review by downgrading directives to
    directive_unverified (a false-block on every attested directive). SECURITY: this only
    carries forward rules whose CURRENT text still classifies as a directive — scan_unit
    reclassifies every rule from its TEXT (STRICT productions first), so an attacker
    cannot relabel a mechanical rule as a directive to dodge recompute. Carrying `attested`
    forward from a forgeable file is no weaker than today, because directives were always
    trust-based (not machine-checkable by construction)."""
    out = {}
    if not isinstance(prior_artifact, dict):
        return out
    for r in (prior_artifact.get("rules") or []):
        if not isinstance(r, dict):
            continue
        if (str(r.get("verdict", "")).lower() == "attested"
                and str(r.get("type", "")).lower() in ("directive", "directive_prose")):
            out[r.get("rule", "")] = r.get("evidence", "")
    return out


def scan_unit(cwd, git, unit_id, unit_text, unit_commits, preflight, attest, prior_artifact=None):
    """Execute a unit's Hard rules against real git/fs → (results, ok_all).

    unit_commits: newest-first [(sha, [(status, relpath)])] for THIS unit (from
                  walk_unit_commits). preflight: parsed preflight.json (or {}).
    attest:       the --attest-directives reason (empty at the gate).
    prior_artifact: parsed prior postflight.json (or None). Provided by the GATE only,
                  to carry forward attested directives; run-postflight-scan.sh passes
                  None (→ byte-identical: attest ? attested : directive_unverified)."""
    lines, v2_rules = extract_hard_rules(unit_text)

    touched = {p for _, fl in unit_commits for _, p in fl}
    added = {p for _, fl in unit_commits for st, p in fl if st == "A"}
    oldest_sha = unit_commits[-1][0] if unit_commits else None
    prior_attested = _attested_directives(prior_artifact)

    results = []
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
                # NOTE: manifests are read relative to cwd; the walk already stripped the
                # project prefix from committed paths, and the writer passes the same cwd.
                EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
                has_parent = git("rev-parse", "--verify", "-q", "%s^" % oldest_sha).returncode == 0
                if has_parent:
                    base_ref = "%s^" % oldest_sha
                    before = git("show", "%s:%s" % (base_ref, manifest)).stdout
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
                    dr = git("diff", "%s..HEAD" % base_ref, "--", manifest)
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
                    stem = os.path.basename(p).split(".", 1)[0]
                    if stem and not rx2.match(stem):
                        bad.append(p)
                ok = not bad
                ev = ("all %d new file(s) matching %s follow %s" % (len(matched_files), pat, style)) if ok \
                     else "violations: %s" % ", ".join(bad[:5])
                results.append({"type": rtype, "rule": raw, "verdict": "pass" if ok else "fail", "evidence": ev})
            elif rtype == "SIGNATURE_RULE":
                name, sig = mm.group(1), mm.group(2).strip()
                decl, loc = find_decl_line(git, name)
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
            elif raw in prior_attested:
                results.append({"type": "directive", "rule": raw, "verdict": "attested",
                                "evidence": "attested (carried from prior scan): %s" % prior_attested[raw]})
            else:
                results.append({"type": "directive", "rule": raw, "verdict": "directive_unverified",
                                "evidence": "generic directive — not machine-checkable; re-run with "
                                            "--attest-directives=\"<who/why>\" after controller/panel review"})
            continue
        results.append({"type": "unparseable", "rule": raw, "verdict": "fail",
                        "evidence": "line matches no v1 production and is not a directive — fix the unit's ## Hard rules"})

    # ── v2 ast-grep rules ────────────────────────────────────────────────────
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
    return results, ok_all
