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
            st, _, rest = l.partition("\t")
            seg = rest.split("\t")
            if st[:1] == "R" and len(seg) == 2:
                # S7-HARDRULES-6: a rename VACATES the old path — record it as a
                # deletion so DO_NOT_MODIFY's touched-set sees `git mv locked new`
                # (the old single-path form kept only the new name → rename dodge).
                # Copies (C) leave the original intact: new path only.
                old, new = seg
                for pp, ss in ((old, "D"), (new, "R")):
                    if prefix and pp.startswith(prefix):
                        pp = pp[len(prefix):]
                    files.append((ss, pp))
                continue
            p = seg[-1]
            if prefix and p.startswith(prefix):
                p = p[len(prefix):]
            files.append((st[:1], p))
        out.setdefault(uid, []).append((sha, files))  # newest-first (git log order)
    return out


_BULLET = re.compile(r"^(?:[-*+]|\d+[.)])\s+(.*)$")
_RULEISH = re.compile(r"\b(?:MUST|DO NOT|NEVER|ALWAYS)\b")
_KEYWORD_LEAD = re.compile(r"^(?:MUST NOT|MUST|DO NOT|NEVER|ALWAYS)\b", re.IGNORECASE)


def extract_hard_rules(unit_text):
    """(rule_lines, v2_yaml_rules) from the unit's `## Hard rules` section.

    S7-HARDRULES-4: the old lexer accepted ONLY `- ` bullets — `*`/`+` bullets and
    numbered items were silently dropped, so a unit could incur the B1 obligation
    (the gate's obligation detector counts them) while the scan executed NOTHING and
    recorded "section empty". Now: `- ` bullets always lex as rules; `*`/`+`/numbered
    bullets lex as rules when they carry a rule keyword (MUST/DO NOT/NEVER/ALWAYS);
    indented continuation lines join the OPEN bullet (standard list semantics); a
    non-bullet keyword-LEADING line lexes verbatim (the bullet-evasion shape — it
    executes if STRICT-parseable, else fails downstream). Everything else — intro
    prose, decorative non-dash bullets, bold labels — is tolerated, mirroring
    validate-unit-spec.sh's Hard-rule net EXACTLY: the unit-stage validator
    documents "other non-dash prose stays tolerated", and a stricter engine here
    retroactively hard-failed units that lint had passed (S7 review, r1-4)."""
    m = re.search(r"(?ims)^##[ \t]+Hard[ \t]+rules\b[^\n]*\n(.*?)(?=^##[ \t]|\Z)", unit_text)
    hr_block = m.group(1) if m else ""
    v2_rules = re.findall(r"```ya?ml\s*\n(.*?)```", hr_block, re.DOTALL)
    lines = []
    in_fence = False
    open_rule = False
    for ln in hr_block.splitlines():
        s = ln.strip()
        if s.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence or not s or s.startswith("#") or s.startswith("<"):
            continue
        if re.match(r"^(?:Citation|Source|Ref(?:erence)?|From)\s*:", s, re.IGNORECASE):
            continue
        bm = _BULLET.match(s)
        if bm:
            body = bm.group(1).strip()
            if s.startswith("-") or _RULEISH.search(body):
                lines.append(body)
                open_rule = True
            else:
                open_rule = False  # decorative non-dash bullet — tolerated (lint parity)
            continue
        if ln[:1] in (" ", "\t") and open_rule:
            # indented continuation of the OPEN bullet — join, never a new rule
            lines[-1] = lines[-1] + " " + s
            continue
        if _KEYWORD_LEAD.match(s):
            # bullet-evasion shape: rule-like line outside a bullet — never skip
            lines.append(s)
            open_rule = True
        else:
            open_rule = False  # non-rule prose (intro lines, labels) — tolerated
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
    # S7-HARDRULES-7: modal-verb synonyms are the SAME mechanical intent — without
    # them "MUST NOT modify X" classified as an attestable directive, so a
    # machine-checkable lock could be waved through on trust. The captured object
    # must be PATH-SHAPED (contains . or /): a bare `\S+` captured the next WORD,
    # so prose like "MUST NOT modify existing API contracts" became a mechanical
    # lock on the path "existing" → vacuous auto-PASS. Non-path objects fall
    # through to the directive tier (human attestation), same as before HR-7.
    ("DO_NOT_MODIFY", re.compile(r"^(?:DO NOT|MUST NOT|NEVER) modify\s+(\S*[./]\S*)")),
    ("DO_NOT_ADD_DEPS", re.compile(r"^(?:DO NOT|MUST NOT|NEVER) add new\s+(\S*\.\S+)\s+dependencies")),
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


# The 4 declaration patterns, in PRIORITY order (find_decl_line's contract).
# %s is the escaped function name. Kept module-level so the batched lookup
# (find_decl_lines, spec §4f-i) and the solo lookup share ONE source of truth.
_DECL_PATTERNS = (
    r"(function|def|fn|func)[[:space:]]+%s[[:space:]]*\(",   # function/def/fn/func NAME(
    r"(const|let|var)[[:space:]]+%s[[:space:]]*=",            # const NAME = (arrow/expr)
    r"%s[[:space:]]*[:=][[:space:]]*(async[[:space:]]*)?\(",  # NAME: (…) => / NAME = (…) =>
    r"%s[[:space:]]*\([^)]*\)[[:space:]]*\{",                 # method NAME(...) {
)


def _decl_line_usable(fpath):
    """The .md/vault self-match filter — shared verbatim by both lookups."""
    return not (fpath.startswith(".mega-sdd/") or fpath.startswith("docs/mega-sdd/")
                or fpath.lower().endswith((".md", ".markdown")))


def _posix_to_py(pat):
    """POSIX ERE → python re for LINE-content tests: within one grep output line no
    newline can appear, so [[:space:]] narrows to [ \\t\\f\\v\\r] with identical
    semantics. Used only to re-attribute batched alternation matches per name."""
    return pat.replace("[[:space:]]", "[ \\t\\f\\v\\r]")


def find_decl_lines(git, names):
    """Batched find_decl_line (spec §4f-i): ≤4 `git grep` calls TOTAL for all names
    (one alternation per pattern round), not one per name. Byte-identical per-name
    semantics: a name resolves at the FIRST pattern round (priority order) that
    yields a usable line, and within a round takes its FIRST usable line in git
    grep's output order — exactly the solo loop. Returns {name: (decl, loc)} with
    (None, None) for unresolved names. Ground truth is re-derived on EVERY call —
    this is batching, never memoization (the §4f trust analysis)."""
    out = {}
    pending = [n for n in dict.fromkeys(names) if n]
    for pat in _DECL_PATTERNS:
        if not pending:
            break
        # Chunked alternation (ADV-004): an over-long argv or one regcomp-hostile
        # name must never take down the round for EVERY name — <=100 names per
        # grep bounds both the argv and the O(lines x names) re-attribution.
        for ci in range(0, len(pending), 100):
            chunk = pending[ci:ci + 100]
            alt = "(" + "|".join(re.escape(n) for n in chunk) + ")"
            r = git("grep", "-nE", pat % alt)
            if r.returncode >= 2:
                continue  # regcomp/arg error — NO information; chunk stays pending
            if not r.stdout:
                continue
            py_rx = {n: re.compile(_posix_to_py(pat % re.escape(n))) for n in chunk}
            resolved_this_round = set()
            for l in r.stdout.splitlines():
                parts = l.split(":", 2)
                if len(parts) != 3:
                    continue
                if not _decl_line_usable(parts[0]):
                    continue
                content = parts[2]
                for n in chunk:
                    if n in resolved_this_round or n in out:
                        continue
                    if py_rx[n].search(content):
                        out[n] = (content.strip(), "%s:%s" % (parts[0], parts[1]))
                        resolved_this_round.add(n)
        pending = [n for n in pending if n not in out]
    # A name this lookup could NOT resolve is deliberately OMITTED — absent means
    # MISS, and scan_unit re-checks it with the solo find_decl_line before ever
    # writing a "not found" verdict (ADV-003: an unresolved name must get the
    # solo second opinion, or the byte-identical claim is false).
    return out


def batch_cat(cwd, requests, timeout=20):
    """ONE single-shot `git cat-file --batch` serving every (rev[:path]) request
    (spec §4f-ii): the full request list is written as stdin to a bounded
    subprocess.run — no interactive pipe management (Windows-safe; honors the
    repo's bounded-subprocess law). Returns {request: bytes | None} (None =
    missing/unresolvable). Deduplicates requests; EVERY anomaly — timeout,
    non-zero rc, undecodable path, a request that would smuggle extra input
    lines, a truncated or over/under-consumed reply stream — returns {} (or
    drops the request) so every consumer falls back to its solo per-call git
    read: fail toward the unbatched ground-truth path, never toward a blob that
    might belong to a different request (ADV-001/ADV-002, round-1 4f). The 20 s
    bound is deliberately LOWER than the solo git() 60 s: a batch failure is
    cheap (solo fallback), so a wedged git costs one short ceiling here, not an
    additive full one."""
    # A request containing a newline would become TWO cat-file input lines and
    # shift every later reply by one — desync, the fail-open direction. Drop it
    # to the solo path instead (attacker-creatable via a crafted dir name).
    reqs = [r for r in dict.fromkeys(requests) if r and "\n" not in r and "\r" not in r]
    if not reqs:
        return {}
    try:
        pr = subprocess.run(["git", "-C", cwd, "cat-file", "--batch"],
                            input=("\n".join(reqs) + "\n").encode("utf-8", "surrogateescape"),
                            capture_output=True, timeout=timeout)
    except Exception:
        return {}
    if pr.returncode != 0:
        return {}  # a real cat-file error; "missing" objects reply in-stream at rc 0
    out, buf, pos = {}, pr.stdout, 0
    for req in reqs:
        nl = buf.find(b"\n", pos)
        if nl < 0:
            return {}  # fewer replies than requests — never trust a partial stream
        header = buf[pos:nl]
        pos = nl + 1
        parts = header.split()
        if len(parts) == 3 and parts[2].isdigit():
            size = int(parts[2])
            if pos + size + 1 > len(buf):
                return {}  # truncated blob — a short slice is not this blob
            out[req] = buf[pos:pos + size]
            pos += size + 1  # trailing newline after the blob body
        else:
            out[req] = None  # "<obj> missing" / "<obj> ambiguous" — no body follows
    if pos != len(buf):
        return {}  # trailing unconsumed output — the stream did not match the requests
    return out


def find_decl_line(git, name):
    """First function/method declaration line for `name` in tracked source.
    Uses POSIX [[:space:]] not \\s: git grep runs the platform regex engine (BSD on
    macOS) which does NOT honor \\s — S6 writers-lens fix: \\s matched NOTHING, so every
    SIGNATURE_RULE emitted a false 'not found' FAIL that permanently blocked B1. Also
    broadened past the C-style `function NAME(` shape to arrow/expr and method decls."""
    n = re.escape(name)
    for pat in (p % n for p in _DECL_PATTERNS):
        r = git("grep", "-nE", pat)
        for l in r.stdout.splitlines():
            parts = l.split(":", 2)
            if len(parts) != 3:
                continue
            # Match only REAL source — never the unit spec / vault docs, which contain
            # the rule's own `function NAME MUST preserve signature: function NAME(...)`
            # text and would otherwise self-match (the \s bug had masked this).
            if not _decl_line_usable(parts[0]):
                continue
            return parts[2].strip(), "%s:%s" % (parts[0], parts[1])
    return None, None


def _glob_match(p, pat, basename_fallback=True):
    """Glob match honoring `**` (any dirs incl zero) and stripping the documented
    `file:` prefix. S6 writers-lens fix: fnmatch never stripped `file:` (schema-conformant
    rules silently PASSED) and had no `**` recursion (app/**/*.php missed a file directly
    under app/). `*`/`?` are segment-scoped ([^/]) — proper glob, not fnmatch's '/'-eating.

    basename_fallback=False anchors the match to the FULL path only — required by the
    B3 whitelist observer (S7-B3-1): a bare-filename pattern must never sanction a
    same-named file in a different directory (the NAMING_RULE consumer keeps the
    fallback; its patterns describe file names, not scopes)."""
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
    if cre.match(p):
        return True
    return basename_fallback and bool(cre.match(os.path.basename(p)))


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
            ev = str(r.get("evidence", ""))
            # Idempotent carry: strip every prior "attested (carried …): " /
            # "attested: " prefix so a recompute never stacks them (the field
            # artifacts carried a depth-2 "attested (carried from prior scan):
            # attested (carried from prior scan): attested: …").
            while True:
                m = re.match(r"^attested(?: \(carried from prior scan\))?:\s*", ev)
                if not m:
                    break
                ev = ev[m.end():]
            out[r.get("rule", "")] = ev
    return out


# Column-0 anchor: `files:` is a TOP-LEVEL ast-grep rule key. An indented
# `files:`-looking line (e.g. inside a block-scalar `message: |`) is document
# text, not a rule key — rewriting it corrupted the message and contaminated
# the glob list (S7 review r1-7).
_V2_FILES_INLINE = re.compile(r"^(files:\s*\[)(.*)(\])[ \t]*$", re.MULTILINE)
_V2_FILES_BLOCK = re.compile(r"^(files:\s*\n)((?:[ \t]+-\s+[^\n]+\n?)+)", re.MULTILINE)


def _split_globs(s):
    """Split an inline files: list on commas OUTSIDE quotes/braces/brackets —
    a naive split corrupted brace globs (`app/{Models,Entities}/x.php`) and
    char-classes into unparseable globset patterns → permanent false-FAIL
    with an "ast-grep error" evidence (S7 review r1-1)."""
    items, buf, depth, q = [], [], 0, None
    for ch in s:
        if q:
            buf.append(ch)
            if ch == q:
                q = None
        elif ch in "'\"":
            q = ch
            buf.append(ch)
        elif ch in "{[":
            depth += 1
            buf.append(ch)
        elif ch in "}]":
            depth -= 1
            buf.append(ch)
        elif ch == "," and depth == 0:
            items.append("".join(buf))
            buf = []
        else:
            buf.append(ch)
    if buf:
        items.append("".join(buf))
    return [x for x in items if x.strip()]


def _norm_v2_glob(g):
    g = g.strip().strip("'\"")
    while g.startswith("./"):  # literal ./ prefixes only — lstrip("./") ate the
        g = g[2:]              # leading dot of hidden paths (.env → env)
    if not g or g.startswith(("**", "/")):
        return g
    return "**/" + g


def normalize_v2_files(rule_yaml):
    """(normalized_yaml, glob_list). S7-HARDRULES-1 (CRITICAL): `ast-grep scan --rule`
    matches a bare relative files: glob (`src/x.php`) against NOTHING — verified
    empirically on 0.42.3 for both relative and absolute scan paths — so every rule
    authored in the grammar ref's documented shape was silently INERT (zero files
    scanned → zero matches → verdict pass while the lock never executed). Prefix
    `**/` to every relative glob before the rule is written to the temp file;
    already-`**/`-prefixed and absolute globs pass through untouched."""
    globs = []

    def _inline(m):
        items = [_norm_v2_glob(x) for x in _split_globs(m.group(2))]
        globs.extend(items)
        return m.group(1) + ", ".join('"%s"' % x for x in items) + m.group(3)

    def _block(m):
        out = []
        for ln in m.group(2).splitlines():
            im = re.match(r"^([ \t]+-\s+)(.*)$", ln)
            if im:
                g = _norm_v2_glob(im.group(2))
                globs.append(g)
                out.append('%s"%s"' % (im.group(1), g))
            else:
                out.append(ln)
        return m.group(1) + "\n".join(out) + "\n"

    y = _V2_FILES_INLINE.sub(_inline, rule_yaml)
    y = _V2_FILES_BLOCK.sub(_block, y)
    return y, globs


def scan_unit(cwd, git, unit_id, unit_text, unit_commits, preflight, attest, prior_artifact=None,
              prefetch=None):
    """Execute a unit's Hard rules against real git/fs → (results, ok_all).

    unit_commits: newest-first [(sha, [(status, relpath)])] for THIS unit (from
                  walk_unit_commits). preflight: parsed preflight.json (or {}).
    attest:       the --attest-directives reason (empty at the gate).
    prior_artifact: parsed prior postflight.json (or None). Provided by the GATE only,
                  to carry forward attested directives; run-postflight-scan.sh passes
                  None (→ byte-identical: attest ? attested : directive_unverified).
    prefetch:     optional batching backend (spec §4f): an object with
                  .decl(name) -> (decl, loc) | MISS, .blob(rev_path) -> str | MISS
                  (rev_path is the exact string a solo `git show` would take), and
                  .has_object(rev) -> bool | MISS. Every MISS falls back to the solo
                  per-call subprocess, so verdicts are byte-identical with or without
                  it. This is BATCHING of the same ground-truth reads, re-derived on
                  every call — never memoization across calls."""
    lines, v2_rules = extract_hard_rules(unit_text)

    touched = {p for _, fl in unit_commits for _, p in fl}
    added = {p for _, fl in unit_commits for st, p in fl if st == "A"}
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
                # F-06 (spec 2026-08-30 §1.2): the unit's OWN commit touched-set is
                # the PRIMARY predicate — "did THIS unit modify the locked path?"
                # The snapshot compare used to take precedence and answered a
                # different question ("did the path change since baseline, by
                # anyone?"): on the field run that fired 6 halts, all false
                # positives (sibling units changing a shared app.ts legitimately),
                # 0 true positives, and left 15 baselines latently stale. The
                # snapshot is now a NOTE on the evidence when commits exist, and
                # the verdict only in the pre-commit working-tree mode. Renames
                # stay visible (walk_unit_commits records `git mv locked new` as
                # `D old`); a commit laundered without unit identity is B2's
                # out-of-band anchor, not this rule's.
                cur = sha256_of(os.path.join(cwd, path)) if snap is not None else None
                if unit_commits:
                    ok = path not in touched
                    ev = ("bolt commits did not touch %s" % path) if ok else \
                         ("bolt commit touched %s" % path)
                    if snap is not None and not ((cur == snap) or (snap == "absent" and cur is None)):
                        ev += (" (note: sha256 differs from the preflight baseline — pre: %s, now: %s"
                               " — changed outside this unit's commits; not a violation of THIS unit)"
                               % (snap, cur))
                elif snap is not None:
                    ok = (cur == snap) or (snap == "absent" and cur is None)
                    ev = "sha256 %s (preflight snapshot, working-tree mode)" % ("unchanged" if ok else "MISMATCH — pre: %s, post: %s" % (snap, cur))
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
                # S7-HARDRULES-5 (per-commit form, S7 review r1-3): a single
                # oldest^..newest span re-widens across INTERLEAVED unrelated commits
                # the moment a later `fix(U-XXX):` commit exists — and the documented
                # remediation for a wrong rule GUARANTEES that shape. Diff each of the
                # unit's OWN commits (sha^..sha) and union the additions; commits the
                # unit does not own never enter any edge. Rev-paths use `:./` so git
                # resolves them against cwd, not the repo root (S7 review r2-1: in a
                # monorepo subproject a root-level same-named manifest was read at
                # BOTH edges → a dep added by this very commit passed, fail-open).
                EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
                new_keys, new_lines, saw_depset = set(), [], False
                for sha, fl in unit_commits:
                    if not any(p == manifest for _, p in fl):
                        continue  # this commit didn't touch the manifest
                    has_parent = None
                    if prefetch is not None:
                        has_parent = prefetch.has_object("%s^" % sha)
                    if has_parent is None:
                        has_parent = git("rev-parse", "--verify", "-q", "%s^" % sha).returncode == 0
                    base_ref = "%s^" % sha if has_parent else EMPTY_TREE
                    def _blob(rev_path):
                        if prefetch is not None:
                            b = prefetch.blob(rev_path)
                            if b is not None:
                                return b
                        return git("show", rev_path).stdout
                    before = _blob("%s:./%s" % (base_ref, manifest)) if has_parent else ""
                    cur = _blob("%s:./%s" % (sha, manifest))
                    b, a = dep_set(before, manifest), dep_set(cur, manifest)
                    if b is None and not has_parent and a is not None:
                        b = set()     # parseable new manifest at a root commit → 0 prior deps
                    if b is not None and a is not None:
                        saw_depset = True
                        new_keys |= (a - b)
                    else:
                        dr = git("diff", "%s..%s" % (base_ref, sha), "--", manifest)
                        new_lines += [l[1:].strip() for l in dr.stdout.splitlines()
                                      if l.startswith("+") and not l.startswith("+++") and l[1:].strip()
                                      and not l[1:].strip().startswith(("#", "//"))]
                if new_keys:
                    ok, ev = False, "NEW dependencies: %s" % ", ".join(sorted(new_keys))
                elif new_lines:
                    ok, ev = False, "added lines in %s: %s" % (manifest, "; ".join(new_lines[:5]))
                else:
                    ok = True
                    ev = "dep keys unchanged" if saw_depset else "no added lines in %s" % manifest
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
                dl = prefetch.decl(name) if prefetch is not None else None
                decl, loc = dl if dl is not None else find_decl_line(git, name)
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
                    # S7-HARDRULES-3: the old token-SUBSET check passed ADDED parameters
                    # (the docs' own canonical violation: twoFactor?: string appended) and
                    # dropped =>-return tokens. Compare the full parenthesized parameter
                    # list for EQUALITY; unextractable spans fail CLOSED (house style) —
                    # the sanctioned alternative is a preflight signature snapshot.
                    def _paren_span(s):
                        i = s.find("(")
                        if i < 0:
                            return None
                        depth = 0
                        for j in range(i, len(s)):
                            if s[j] == "(":
                                depth += 1
                            elif s[j] == ")":
                                depth -= 1
                                if depth == 0:
                                    return re.sub(r"\s+", "", s[i:j + 1])
                        return None
                    want, got = _paren_span(sig), _paren_span(decl)
                    if want is not None and got is not None:
                        ok = want == got
                        results.append({"type": rtype, "rule": raw, "verdict": "pass" if ok else "fail",
                                        "evidence": "decl at %s: %s%s" % (loc, decl[:120],
                                                    "" if ok else " — parameter list differs from required signature (required %s, found %s)" % (want[:80], got[:80]))})
                    else:
                        results.append({"type": rtype, "rule": raw, "verdict": "fail",
                                        "evidence": "decl at %s: %s — cannot mechanically extract the parameter list (multi-line or unparenthesized decl); record a preflight signature snapshot to verify this rule" % (loc, decl[:120])})
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
            # NO sha256-vs-preflight lock check here, by design: a v2 rule is a
            # PATTERN SCAN, not a file lock — lock semantics (DO_NOT_MODIFY) stay v1
            # per the grammar's mapping table. A sha compare against the working tree
            # made honest remediation unreachable (fixing the violation necessarily
            # changes the file → permanent MISMATCH fail) — S7 review r1-2.
            ry_norm, _rule_globs = normalize_v2_files(ry)
            with tempfile.NamedTemporaryFile("w", suffix=".yml", delete=False) as tf:
                tf.write(ry_norm)
                tmp_rule = tf.name
            try:
                # BOUNDED, and the bound is load-bearing. This is a repo-wide
                # ast-grep scan, and B1 postflight is RECOMPUTED at the execute-bolts
                # gate — i.e. this runs inside the BLOCKING PreToolUse hook. An
                # unbounded scan there is the same failure shape as the 2026-07-28
                # Windows hang: work with no ceiling in a path Claude Code waits on.
                # 120 s is generous for a large repo while still terminating.
                try:
                    rr = subprocess.run([astgrep, "scan", "--rule", tmp_rule, "--json", cwd],
                                        capture_output=True, text=True, timeout=120)
                except subprocess.TimeoutExpired:
                    # FAIL-CLOSED, deliberately. A Hard rule whose check did not
                    # complete has NOT been shown to hold, and this verdict feeds a
                    # blocking gate — treating "we ran out of time" as `pass` would
                    # let a timeout launder a violation. Same branch the tool-error
                    # case already takes below.
                    results.append({"type": "v2_ast_grep", "rule": rid, "verdict": "fail",
                                    "evidence": "ast-grep scan exceeded 120s — rule NOT verified "
                                                "(fail-closed; narrow the rule's files: globs or "
                                                "re-run outside the gate)"})
                    continue
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

    # F-01(a) (spec 2026-08-30 §2.2): the verdict is formed by MACHINE rules only.
    # A `directive` (generic MUST/DO NOT prose) is recorded — attested, carried,
    # or directive_unverified — but never gates: on the field run 256 of 278
    # postflight rules were directives, every one "attested" by a single
    # free-text paragraph per unit, 0 could ever fail, and the counterfactual
    # (directives advisory) lost zero detections. A tier that cannot fail is
    # a permission valve, not a detector; the panel reviews prose rules.
    ok_all = all(r["verdict"] in ("pass", "attested")
                 for r in results if r.get("type") != "directive")
    return results, ok_all
