#!/usr/bin/env bash
# validate-flow-coverage.sh — code-delivery sharpening, Task A (decomposition).
#
# Per docs/superpowers/specs/2026-06-01-sharpen-code-delivery-uiux-design.md §3 Slice A
# and plan docs/superpowers/plans/2026-06-01-sharpen-code-delivery-uiux.md §Task A.
#
# Flow-step -> artifact derivation + scaffold-filter gate.
#
# TECH-AGNOSTIC: this validator hardcodes NO stack signature. It reads the active
# framework-convention pack via resolve-framework-pack.sh:
#   - `## Flow-artifact derivation`   (endpoint_kinds)  — REQUIRED; absent => SKIP
#   - `## Conditional scaffold artifacts`               — optional (dead-stub check)
#   - `## Entity source globs`        (entity_sources)  — optional; how to recover a
#       unit's entity name from its target-files paths (Controller/view-dir/Model
#       capture regexes). Absent => degrade to frontmatter+title-only matching.
#   - `## Entity matching tokens`     (stop_tokens / compound_aliases) — optional;
#       DOMAIN-specific stopwords + compound aliases. The validator core carries only
#       generic + vault-FORMAT vocabulary; domain jargon lives in the pack/fork.
# No pack declaring the REQUIRED Flow-artifact derivation => status: SKIP (graceful,
# never errors). Adding a stack = adding a pack; never editing this validator.
# Laravel is only the example + fixture.
#
# WHAT IT CHECKS (operating on UNIT SPECS, not generated code — this is the
# decomposition-stage gate; the post-flight code scan is slice C):
#   1. Coverage: parse each flow in 04-flows.md into per-step BLOCKS (a numbered
#      `N.` line + its indented sub-bullets). A step block matching an
#      endpoint_kinds.flow_signal is an input-accepting transition step requiring
#      one `required_artifact`. Group flow steps + units by MODULE; for each module
#      assert the count of input-accepting steps <= count of path_glob-matching
#      artifacts listed in the module unit(s)' `## Target files`. Shortfall =>
#      missing_artifacts[].
#   2. Dead scaffold: for each Conditional scaffold entry, find units listing a path
#      matching artifact_glob in `## Target files` whose module has NO flow step
#      matching requires_flow_endpoint => dead_scaffold[] (de-duped by artifact path).
#
# Usage:
#   validate-flow-coverage.sh --cwd=<project-root> [--quiet]
#
# Output:
#   stdout: JSON report (suppressed with --quiet)
#   side-effect: OVERWRITE-writes <cwd>/.mega-sdd/.flow-coverage-state.json (current truth)
#   exit 0 = PASS or SKIP; exit 1 = FAIL; exit 2 = error

set -uo pipefail

CWD=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# Resolve project root (walk UP to outermost .mega-sdd/ parent).
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR_HELPER="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERROR: --cwd=<project-root> required and must exist" >&2
  exit 2
fi

STATE_FILE="${CWD}/.mega-sdd/.flow-coverage-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || {
  echo "ERROR: cannot create $(dirname "$STATE_FILE")" >&2; exit 2;
}

# Pull the two pack sections via the shared resolver (tech-agnostic chokepoint).
# Exit 3 from the resolver = section absent in every pack of the chain (=> SKIP).
PACK_RESOLVER="${SCRIPT_DIR}/_lib/resolve-framework-pack.sh"
FLOW_SECTION=""
SCAFFOLD_SECTION=""
ENTITY_SOURCE_SECTION=""
ENTITY_TOKEN_SECTION=""
if [ -x "$PACK_RESOLVER" ]; then
  FLOW_SECTION=$(bash "$PACK_RESOLVER" --cwd="$CWD" --section="Flow-artifact derivation" --quiet 2>/dev/null) || FLOW_SECTION=""
  SCAFFOLD_SECTION=$(bash "$PACK_RESOLVER" --cwd="$CWD" --section="Conditional scaffold artifacts" --quiet 2>/dev/null) || SCAFFOLD_SECTION=""
  # Module-matching enrichment (Iter — tech-agnostic fix): entity-source capture
  # patterns + domain token tuning are now PACK-DECLARED, never hardcoded. Both
  # are OPTIONAL — absent => the validator degrades to title-only matching with
  # the universal stopword set (graceful, never errors).
  ENTITY_SOURCE_SECTION=$(bash "$PACK_RESOLVER" --cwd="$CWD" --section="Entity source globs" --quiet 2>/dev/null) || ENTITY_SOURCE_SECTION=""
  ENTITY_TOKEN_SECTION=$(bash "$PACK_RESOLVER" --cwd="$CWD" --section="Entity matching tokens" --quiet 2>/dev/null) || ENTITY_TOKEN_SECTION=""
fi

CWD="$CWD" STATE_FILE="$STATE_FILE" QUIET="$QUIET" \
FLOW_SECTION="$FLOW_SECTION" SCAFFOLD_SECTION="$SCAFFOLD_SECTION" \
ENTITY_SOURCE_SECTION="$ENTITY_SOURCE_SECTION" ENTITY_TOKEN_SECTION="$ENTITY_TOKEN_SECTION" \
python3 <<'PYEOF'
import json
import os
import re
import sys
import glob
import fnmatch
from datetime import datetime, timezone

cwd = os.environ["CWD"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
flow_section = os.environ.get("FLOW_SECTION", "")
scaffold_section = os.environ.get("SCAFFOLD_SECTION", "")
entity_source_section = os.environ.get("ENTITY_SOURCE_SECTION", "")
entity_token_section = os.environ.get("ENTITY_TOKEN_SECTION", "")

ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


# ── Recursive glob matcher (pack path_globs use `**` for any-depth) ───────────
# Python's fnmatch treats `**` as a single `*` that still requires the literal
# `/` around it, so `app/Http/Requests/**/*.php` would NOT match a file directly
# in `app/Http/Requests/` (no subdir). We translate the pack glob ourselves so
# `**` matches zero-or-more path segments and a path is matched against both its
# full form and a `*/`-prefixed form (units list project-relative paths).
def _glob_to_regex(pat):
    i = 0
    out = ["(?s:"]
    n = len(pat)
    while i < n:
        c = pat[i]
        if c == "*":
            if pat[i:i + 3] == "**/":
                out.append("(?:.*/)?")   # ** + slash => any depth incl. zero
                i += 3
                continue
            if pat[i:i + 2] == "**":
                out.append(".*")
                i += 2
                continue
            out.append("[^/]*")
            i += 1
            continue
        if c == "?":
            out.append("[^/]")
        else:
            out.append(re.escape(c))
        i += 1
    out.append(r")\Z")
    return re.compile("".join(out))


_GLOB_CACHE = {}


def glob_match(path, pattern):
    rx = _GLOB_CACHE.get(pattern)
    if rx is None:
        rx = _glob_to_regex(pattern)
        _GLOB_CACHE[pattern] = rx
    if rx.match(path):
        return True
    # also try suffix match (path may carry leading dirs the glob omits).
    # S6 EB-VAL-6 audit: SAFE here (unlike the ui-quality walker) — `path` is a
    # DECLARED unit target_files entry, never a filesystem walk result, so a
    # backup/… wrapper dir can never reach this matcher.
    return rx.match(path.split("/", 1)[-1]) is not None if "/" in path else False


def write_and_exit(report, code):
    _tmp = state_file + ".tmp.%d" % os.getpid()  # AUDIT L4: atomic write (tmp + os.replace) — no torn read under concurrent bolts
    with open(_tmp, "w") as f:
        json.dump(report, f, indent=2)
    os.replace(_tmp, state_file)
    if not quiet:
        print(json.dumps(report, indent=2))
    sys.exit(code)


def skip(reason):
    write_and_exit({
        "status": "SKIP",
        "validator": "flow-coverage",
        "ts": ts,
        "reason": reason,
        "missing_artifacts": [],
        "dead_scaffold": [],
        "summary": f"SKIP — {reason}",
        "next_action": "No action — this check does not apply to the current project/pack.",
    }, 0)


# ── Graceful SKIPs ───────────────────────────────────────────────────────────
vault_root = os.path.join(cwd, ".mega-sdd", "vaults")
if not os.path.isdir(vault_root):
    skip("no_vault (.mega-sdd/vaults/ absent)")

# The whole gate is pack-declared. No Flow-artifact derivation section => SKIP.
if not flow_section.strip():
    skip("pack declares no '## Flow-artifact derivation' section (endpoint_kinds)")


# ── Parse pack sections (FIRST yaml fence per section = most-specific pack) ────
def first_yaml_block(section_text):
    """Return the body of the first ```yaml ...``` fence in a resolver section dump.
    The resolver concatenates packs most-specific-first, so the first fence is the
    winning (most-specific) declaration."""
    m = re.search(r"```ya?ml\s*\n(.*?)```", section_text, re.DOTALL)
    if m:
        return m.group(1)
    # tolerate a bare (unfenced) yaml-ish block
    return section_text


def parse_endpoint_kinds(text):
    """Parse endpoint_kinds list items. Each item = {flow_signal, required_artifact,
    path_glob, naming?}. Minimal YAML-ish parser keyed off the field names so we do
    not need a YAML dep (matches existing validators' convention)."""
    body = first_yaml_block(text)
    kinds = []
    cur = None

    def flush():
        nonlocal cur
        if cur and cur.get("flow_signal") and cur.get("path_glob"):
            kinds.append(cur)
        cur = None

    for raw in body.splitlines():
        line = raw.rstrip()
        if not line.strip():
            continue
        # A new list item starts with '- ' (possibly indented) and may carry the
        # first key inline (e.g. "- flow_signal: '...'").
        stripped = line.strip()
        if stripped.startswith("- "):
            flush()
            cur = {}
            stripped = stripped[2:].strip()
            if not stripped:
                continue
        if cur is None:
            continue
        m = re.match(r"([a-z_]+)\s*:\s*(.*)$", stripped)
        if not m:
            continue
        key, val = m.group(1), m.group(2).strip()
        val = val.strip().strip('"').strip("'")
        if key in ("flow_signal", "required_artifact", "path_glob", "naming"):
            cur[key] = val
    flush()
    return kinds


def parse_scaffold_entries(text):
    """Parse Conditional scaffold artifacts list: [{artifact_glob, requires_flow_endpoint}]."""
    if not text.strip():
        return []
    body = first_yaml_block(text)
    entries = []
    cur = None

    def flush():
        nonlocal cur
        if cur and cur.get("artifact_glob") and cur.get("requires_flow_endpoint"):
            entries.append(cur)
        cur = None

    for raw in body.splitlines():
        line = raw.rstrip()
        if not line.strip():
            continue
        stripped = line.strip()
        if stripped.startswith("- "):
            flush()
            cur = {}
            stripped = stripped[2:].strip()
            if not stripped:
                continue
        if cur is None:
            continue
        m = re.match(r"([a-z_]+)\s*:\s*(.*)$", stripped)
        if not m:
            continue
        key, val = m.group(1), m.group(2).strip().strip('"').strip("'")
        if key in ("artifact_glob", "requires_flow_endpoint"):
            cur[key] = val
    flush()
    return entries


endpoint_kinds = parse_endpoint_kinds(flow_section)
scaffold_entries = parse_scaffold_entries(scaffold_section)

if not endpoint_kinds:
    skip("'## Flow-artifact derivation' present but no parseable endpoint_kinds (with flow_signal + path_glob)")


# ── Compile flow_signal / requires_flow_endpoint regexes (tolerate (?i) inline) ─
def compile_re(pat):
    flags = 0
    # honor a leading (?i) inline flag explicitly (re supports it but normalize)
    if pat.startswith("(?i)"):
        flags |= re.IGNORECASE
        pat_body = pat[4:]
    else:
        pat_body = pat
    try:
        return re.compile(pat_body, flags)
    except re.error:
        # last resort: escape literally
        return re.compile(re.escape(pat), flags)


for k in endpoint_kinds:
    k["_re"] = compile_re(k["flow_signal"])
for e in scaffold_entries:
    e["_re"] = compile_re(e["requires_flow_endpoint"])


# ── Locate the active vault: a vault dir holding the flows doc AND a units/ dir ──
# Support both layouts: <vault>/units/ and <vault>-bound/units/. Prefer the vault
# that has BOTH a flows doc and units. If a -bound sibling holds the units, pair
# it with the base vault's flows doc. v7 Fase 3 dual-layout read (one minor
# cycle): probe the layout-2 `flows.md` FIRST, fall back to legacy `04-flows.md`.
def _flows_path(d):
    p2 = os.path.join(d, "flows.md")
    return p2 if os.path.isfile(p2) else os.path.join(d, "04-flows.md")

def find_flows_and_units():
    candidates = []
    for d in sorted(glob.glob(os.path.join(vault_root, "*"))):
        if not os.path.isdir(d):
            continue
        # S5 round-2 (ATK-1): a legacy `<vault>-bound/` sibling is an AMENDED COPY
        # of its base vault (own flows doc + units/). Treating it as its own
        # candidate while the base ALSO absorbs its units via the sibling probe
        # double-counted every artifact and mis-tagged the vault — flipping a real
        # shortfall to PASS at the execute-bolts gate. The base candidate owns the
        # pair; skip the sibling as a standalone candidate.
        base_name = os.path.basename(d)
        if base_name.endswith("-bound") and os.path.isdir(os.path.join(vault_root, base_name[:-6])):
            continue
        flows = _flows_path(d)
        if not os.path.isfile(flows):
            continue
        # units may live in this dir or in a -bound sibling
        unit_dirs = [os.path.join(d, "units")]
        base = os.path.basename(d)
        unit_dirs.append(os.path.join(vault_root, base + "-bound", "units"))
        units = []
        for ud in unit_dirs:
            units += sorted(
                glob.glob(os.path.join(ud, "U-*.md")) +
                glob.glob(os.path.join(ud, "U-*", "unit.md"))
            )
        if units:
            candidates.append((flows, units, base))
    return candidates


candidates = find_flows_and_units()
if not candidates:
    skip("no active vault with both 04-flows.md and units/U-*.md found")

# S5 GU-HOOK-5: analyze ALL vaults — the old most-units heuristic silently
# un-gated every smaller vault (a phased rebuild's vault-B violations were
# invisible to the execute-bolts block). Flows and units are vault-tagged and
# matching is vault-scoped, so cross-vault token collisions cannot pair them.
all_candidates = sorted(candidates, key=lambda c: -len(c[1]))
vault_name = ", ".join(c[2] for c in all_candidates)
flows_path = all_candidates[0][0]           # primary (most units) — report label
_seen_up = set()
unit_paths = []
for c in all_candidates:
    for p in c[1]:
        rp = os.path.realpath(p)
        if rp not in _seen_up:
            _seen_up.add(rp)
            unit_paths.append(p)


# ── Module derivation (load-bearing; TF units lack `module:` frontmatter) ─────
# Modules are matched by TOKEN-SET OVERLAP, never exact-string equality: a flow
# titled "Widget Approval" must associate with a unit whose module/controller is
# "widget"; a flow "Letter of Credit Issuance" with a "LetterOfCredit" unit.
# Exact compound keys ("widgetapproval" vs "widget") would never match — that was
# the landmine the advisor flagged. We reduce each side to a SET of singularized
# significant entity tokens and intersect.
#
# TECH-AGNOSTIC (Iter fix): the validator core carries ONLY generic structural
# stopwords (articles, prepositions) + mega-sdd vault-FORMAT vocabulary (the
# workflow/ceremony nouns that appear in EVERY vault regardless of stack —
# `module`, `flow`, `approve`, `maker`, …). DOMAIN-specific jargon (e.g. a trade-
# finance `lc`/`swift`/`settlement`) and compound aliases are NOT baked in here;
# they are read from the active pack's `## Entity matching tokens` section
# (stop_tokens / compound_aliases). Likewise the entity-source CAPTURE patterns
# (Controller/view-dir/Model regexes) are read from the pack's `## Entity source
# globs` section — never hardcoded. Adding a stack = adding a pack.
STOP_CORE = {
    # generic structural words
    "the", "a", "an", "of", "and", "or", "to", "for", "with", "per", "from",
    "into", "via", "new",
    # mega-sdd vault-FORMAT vocabulary (stack-neutral ceremony/workflow nouns)
    "import", "create", "manage", "management", "module", "flow", "phase",
    "rebuild", "approval", "approve", "review", "intake", "entry", "issuance",
    "process", "processing", "maker", "checker", "confirmer", "ops", "stage",
    "step", "path", "lane", "system",
}


# ── Pack-declared entity-source globs + token tuning (parsed from sections) ───
def parse_entity_sources(text):
    """Parse `## Entity source globs` -> list of {pattern, exclude:set, _re}.
    Each pattern is a Python regex with a `(?P<entity>...)` (or first) group whose
    capture is tokenized into a unit's entity set. Absent/unparseable => []."""
    if not text or not text.strip():
        return []
    body = first_yaml_block(text)
    sources = []
    cur = None

    def flush():
        nonlocal cur
        if cur and cur.get("pattern"):
            try:
                cur["_re"] = re.compile(cur["pattern"])
                cur.setdefault("exclude", set())
                sources.append(cur)
            except re.error:
                pass
        cur = None

    for raw in body.splitlines():
        line = raw.rstrip()
        if not line.strip():
            continue
        stripped = line.strip()
        # strip trailing `# comment`
        if "#" in stripped:
            # keep '#' that is inside quotes? patterns are quoted, so a bare ' #'
            # after the closing quote is a comment — split on the LAST unquoted #.
            hashpos = stripped.find("#")
            # only treat as comment if not inside the quoted value
            q = stripped.find("'")
            q2 = stripped.find('"')
            firstq = min([p for p in (q, q2) if p != -1], default=-1)
            if firstq == -1 or hashpos < firstq:
                stripped = stripped[:hashpos].rstrip()
            else:
                # find closing quote, then a # after it
                quote = stripped[firstq]
                close = stripped.find(quote, firstq + 1)
                if close != -1:
                    after = stripped.find("#", close + 1)
                    if after != -1:
                        stripped = stripped[:after].rstrip()
            if not stripped:
                continue
        if stripped.startswith("- "):
            flush()
            cur = {}
            stripped = stripped[2:].strip()
            if not stripped:
                continue
        if cur is None:
            continue
        m = re.match(r"([a-z_]+)\s*:\s*(.*)$", stripped)
        if not m:
            continue
        key, val = m.group(1), m.group(2).strip()
        if key == "pattern":
            cur["pattern"] = val.strip().strip('"').strip("'")
        elif key == "exclude":
            # inline list `['a', 'b']`
            items = re.findall(r"[A-Za-z0-9_\-]+", val)
            cur["exclude"] = set(items)
    flush()
    return sources


def parse_token_tuning(text):
    """Parse `## Entity matching tokens` -> (stop_tokens:set, compound_aliases:dict).
    YAML-ish: `stop_tokens: ['a','b']` and a `compound_aliases:` mapping of
    `key: [t1, t2]`. Absent => ([], {}). Merged across the pack chain (the resolver
    concatenates most-specific-first; we union, which is order-independent)."""
    stop = set()
    aliases = {}
    if not text or not text.strip():
        return stop, aliases
    # The resolver may emit one yaml fence per pack (most-specific-first). Union ALL.
    blocks = re.findall(r"```ya?ml\s*\n(.*?)```", text, re.DOTALL)
    if not blocks:
        blocks = [text]
    for body in blocks:
        lines = body.splitlines()
        in_aliases = False
        alias_indent = None
        for raw in lines:
            line = raw.rstrip()
            if not line.strip():
                continue
            stripped = line.strip()
            # strip trailing comment outside quotes (simple heuristic)
            if stripped.startswith("#"):
                continue
            m_stop = re.match(r"stop_tokens\s*:\s*(.*)$", stripped)
            if m_stop:
                in_aliases = False
                for t in re.findall(r"[A-Za-z0-9_\-]+", m_stop.group(1)):
                    stop.add(t.lower())
                continue
            m_ali = re.match(r"compound_aliases\s*:\s*(.*)$", stripped)
            if m_ali:
                rest = m_ali.group(1).strip()
                if rest and rest not in ("{}", "{ }"):
                    # inline form `{ key: [a,b], ... }` — parse loosely below too
                    for km in re.finditer(r"([A-Za-z0-9_\-]+)\s*:\s*\[([^\]]*)\]", rest):
                        key = km.group(1).lower()
                        vals = {v.lower() for v in re.findall(r"[A-Za-z0-9_\-]+", km.group(2))}
                        vals.add(key)
                        aliases[key] = aliases.get(key, set()) | vals
                    in_aliases = False
                else:
                    in_aliases = True
                    alias_indent = None
                continue
            if in_aliases:
                # nested mapping line: `  key: [a, b]`
                indent = len(raw) - len(raw.lstrip())
                if alias_indent is None:
                    alias_indent = indent
                if indent < alias_indent or indent == 0:
                    in_aliases = False
                    # fall through to re-evaluate as top-level? cheap: just stop.
                    continue
                km = re.match(r"([A-Za-z0-9_\-]+)\s*:\s*\[([^\]]*)\]", stripped)
                if km:
                    key = km.group(1).lower()
                    vals = {v.lower() for v in re.findall(r"[A-Za-z0-9_\-]+", km.group(2))}
                    vals.add(key)
                    aliases[key] = aliases.get(key, set()) | vals
    return stop, aliases


ENTITY_SOURCES = parse_entity_sources(entity_source_section)
PACK_STOP, COMPOUND_ALIASES = parse_token_tuning(entity_token_section)
STOP = STOP_CORE | PACK_STOP


def tokenize_entity(s):
    """Return a set of singularized significant tokens from an entity-ish string.
    Splits camelCase, snake_case, kebab-case, and whitespace; drops STOP words."""
    if not s:
        return set()
    # split camelCase: LetterOfCredit -> Letter Of Credit
    s = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", s)
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", " ", s)
    toks = set()
    compact = re.sub(r"[^a-z0-9]+", "", s)
    if compact in COMPOUND_ALIASES:
        toks |= COMPOUND_ALIASES[compact]
    for w in s.split():
        w = re.sub(r"s$", "", w)         # crude singular
        if w and w not in STOP and len(w) > 2:
            toks.add(w)
    return toks


def normalize_token(s):
    """Compact stable key for display/dedupe (singularized, alnum-only)."""
    toks = tokenize_entity(s)
    return "".join(sorted(toks)) if toks else re.sub(r"[^a-z0-9]+", "", (s or "").lower())


FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---", re.DOTALL)


def parse_unit(path):
    with open(path, errors="replace") as f:
        text = f.read()
    fm = {}
    fm_text = ""
    m = FRONTMATTER_RE.match(text)
    if m:
        fm_text = m.group(1)
        for line in fm_text.splitlines():
            mm = re.match(r"^([a-zA-Z_]+)\s*:\s*(.*)$", line)
            if mm:
                fm[mm.group(1)] = mm.group(2).strip().strip('"').strip("'")
    target_files = []
    # S5 GU-FC-FRONTMATTER: the canonical schema puts target_files in FRONTMATTER
    # (`- path:` items) — reading only the body block false-FAILed every
    # schema-conformant unit (artifacts_listed always 0 → permanent block).
    # Union BOTH sources, mirroring validate-unit-spec.sh's _collect_target_files.
    fm_tf = re.search(r"^target_files[ \t]*:[ \t]*(.*)$", fm_text, re.MULTILINE)
    if fm_tf:
        inline = fm_tf.group(1).strip()
        if inline.startswith("["):
            for item in re.findall(r"[^\[\],\s'\"][^\[\],]*", inline):
                target_files.append(item.strip().strip('"').strip("'"))
        after = fm_text[fm_tf.end():]
        for ln in after.splitlines():
            if re.match(r"^[A-Za-z_]", ln):  # next top-level key ends the list
                break
            mm = re.match(r"^\s*-\s*(?:path\s*:\s*)?(.+?)\s*$", ln)
            if mm:
                val = mm.group(1).strip().strip('"').strip("'")
                if val and not re.match(r"^(?:operation|op|kind)\s*:", val):
                    target_files.append(val)
    # ## Target files fenced block
    tm = re.search(r"^##\s+Target files\s*\n(.*?)(?:\n##\s|\Z)", text, re.DOTALL | re.MULTILINE)
    if tm:
        block = tm.group(1)
        # take fenced content if present, else the raw block lines
        fence = re.search(r"```[^\n]*\n(.*?)```", block, re.DOTALL)
        body = fence.group(1) if fence else block
        for line in body.splitlines():
            line = line.strip().lstrip("-").strip()
            if not line:
                continue
            # drop trailing annotations like " (edit)" / " (new — ...)"
            path_only = re.split(r"\s+\(", line, maxsplit=1)[0].strip()
            if path_only:
                target_files.append(path_only)
    return fm, sorted(set(target_files)), text


def expand_braces(p):
    """Expand a single {a,b,c} brace group (Laravel views often use
    `views/widgets/{index,create,show,edit}.blade.php`)."""
    m = re.search(r"\{([^{}]*)\}", p)
    if not m:
        return [p]
    pre, post = p[:m.start()], p[m.end():]
    out = []
    for opt in m.group(1).split(","):
        out.extend(expand_braces(pre + opt.strip() + post))
    return out


def _capture_entity(rx, tf):
    """Return the entity capture from a regex match against a target-files path:
    the named group `entity` if present, else the first group, else None."""
    m = rx.search(tf)
    if not m:
        return None
    gd = m.groupdict()
    if "entity" in gd and gd["entity"]:
        return gd["entity"]
    if m.groups():
        return m.group(1)
    return None


def unit_entity_tokens(fm, target_files):
    """Best-effort entity TOKEN SET for a unit, accumulating evidence from
    (in priority order) frontmatter module:, then the PACK-DECLARED entity-source
    capture patterns applied to target_files, and finally the title. The
    Controller/view-dir/Model capture patterns are NO LONGER hardcoded — they come
    from the active pack's `## Entity source globs` (ENTITY_SOURCES). When the pack
    declares none, this degrades to frontmatter + title-only matching (graceful)."""
    toks = set()
    if fm.get("module"):
        toks |= tokenize_entity(fm["module"])
    for src in ENTITY_SOURCES:
        rx = src["_re"]
        excl = src.get("exclude", set())
        for tf in target_files:
            ent = _capture_entity(rx, tf)
            if ent and ent not in excl:
                toks |= tokenize_entity(ent)
    # title is weakest evidence — only add if we still have nothing
    if not toks:
        toks |= tokenize_entity(fm.get("title", ""))
    return toks


# ── Parse EVERY vault's 04-flows.md into per-flow, per-step blocks (S5: all
# vaults, vault-tagged) ───────────────────────────────────────────────────────
flow_sections = []  # (vault, header_text, body_text)
for _fpath, _upaths, _vname in all_candidates:
    try:
        with open(_fpath, errors="replace") as f:
            flows_text = f.read()
    except Exception:
        continue
    parts = re.split(r"^(###\s+.*)$", flows_text, flags=re.MULTILINE)
    # parts: [pre, header1, body1, header2, body2, ...]
    i = 1
    while i < len(parts):
        header = parts[i].strip()
        body = parts[i + 1] if i + 1 < len(parts) else ""
        flow_sections.append((_vname, header, body))
        i += 2


NUMBERED_STEP_RE = re.compile(r"^\s*\d+[.)]\s+\S")                 # N. | N) (any indent)
TOPLEVEL_BULLET_RE = re.compile(r"^[-*+]\s+\S")                    # top-level bullet (col 0)
MERMAID_EDGE_RE = re.compile(r"--+>|==+>|-\.->|→")                 # mermaid/flowchart edges


def _mermaid_fence_lines(body):
    """Edge lines INSIDE ```mermaid fences (the canonical v4.53.0+ flow body)."""
    out = []
    for fence in re.findall(r"```mermaid[^\n]*\n(.*?)```", body, re.DOTALL | re.IGNORECASE):
        out.extend(ln for ln in fence.splitlines() if MERMAID_EDGE_RE.search(ln))
    return out


def split_step_blocks(body):
    """Split a flow body into per-step blocks, FORMAT-AWARE (ADV-02). A flow uses ONE primary
    step format; we detect it and never mix.
    S5 GU-FLOWCOV-1 — MERMAID FIRST: since the v4.53.0 mermaid mandate, the flow's
    transitions live in the ```mermaid fence while the mandated col-0 `- [ ]` DoD
    checklist ALSO matches TOPLEVEL_BULLET_RE — so the old bullet-first order made
    the mermaid branch dead code on every canonical vault (DoD prose reported as
    "steps": false-FAILs on per-transition units, false-PASSes on signal-free DoD).
    A mermaid fence whose edges carry input signals is now authoritative; when the
    fence yields ZERO signal edges the legacy detection still runs (belt-and-braces
    for sloppy edge labels — the DoD checklist keeps its fallback duty).
      - mermaid fence edges (signal-bearing) -> each edge line is a step;
      - else numbered `N.`/`N)` -> numbered steps (top-level bullets stay continuations);
      - else top-level `-`/`*`/`+` bullets -> bullet steps;
      - else bare mermaid/flowchart edge lines -> each edge line is a step."""
    lines = body.splitlines()
    fence_edges = _mermaid_fence_lines(body)
    if fence_edges and any(k["_re"].search(ln) for k in endpoint_kinds for ln in fence_edges):
        # S5 round-2 (ATK-FC-2): "any signal edge => authoritative" let ONE
        # coarse summary edge suppress 5 signal-bearing NUMBERED steps. Numbered
        # steps are an explicit transition enumeration — when they carry MORE
        # signals than the mermaid fence, they win (the gate must never
        # under-count). The DoD `- [ ]` checklist does NOT override mermaid:
        # checkboxes are outcomes, not transitions (they naturally outnumber
        # real input steps — that over-count was the original false-FAIL).
        mer_n = sum(1 for ln in fence_edges if any(k["_re"].search(ln) for k in endpoint_kinds))
        if any(NUMBERED_STEP_RE.match(ln) for ln in lines):
            legacy_blocks = _legacy_step_blocks(lines)
            leg_n = sum(1 for b in legacy_blocks if any(k["_re"].search(b) for k in endpoint_kinds))
            if leg_n > mer_n:
                return legacy_blocks
        return fence_edges
    return _legacy_step_blocks(lines)


def _legacy_step_blocks(lines):
    if any(NUMBERED_STEP_RE.match(ln) for ln in lines):
        step_re = NUMBERED_STEP_RE
    elif any(TOPLEVEL_BULLET_RE.match(ln) for ln in lines):
        step_re = TOPLEVEL_BULLET_RE
    elif any(MERMAID_EDGE_RE.search(ln) for ln in lines):
        return [ln for ln in lines if MERMAID_EDGE_RE.search(ln)]
    else:
        return []
    blocks = []
    cur = None
    for line in lines:
        if step_re.match(line):
            if cur is not None:
                blocks.append("\n".join(cur))
            cur = [line]
        elif cur is not None:
            # continuation: indented line, sub-bullet, or blank inside the step
            if line.strip() == "" or re.match(r"^\s+\S", line):
                cur.append(line)
            elif re.match(r"^\*\*", line.strip()) or line.startswith("**"):
                # e.g. **Post-conditions**: ends the step list
                blocks.append("\n".join(cur))
                cur = None
            else:
                cur.append(line)
    if cur is not None:
        blocks.append("\n".join(cur))
    return blocks


def flow_entity_tokens(header):
    """Entity TOKEN SET for a flow header like
    '### F-U-001 — Widget Approval (Maker -> Checker -> Confirmer)'.
    The header shape is `### <FLOW-ID> <sep> <Title> (<actors / notes>)` where
    <sep> is an em-dash or hyphen separating the id from the title — so we strip
    the id + its trailing separator FIRST, then drop a trailing parenthetical."""
    h = re.sub(r"^###\s+", "", header)
    h = re.sub(r"\bF-[A-Z]-?\d+\b", "", h)        # strip the F-x-NNN id
    h = re.sub(r"^\s*[—–-]\s*", "", h)            # strip the leading id<->title separator
    h = re.split(r"\(", h)[0]                      # drop trailing "(actors …)" note
    return tokenize_entity(h)


# ── Per-flow: count input-accepting step blocks + remember tokens & flow text ──
from collections import defaultdict

# Flow taxonomy is a documented mega-sdd vault-FORMAT convention (NOT a stack
# signature) — generate-intent/references/vault-contract.md §Flow ID prefixes:
#   F-U- = user-facing (accepts external input — needs input-validation artifacts)
#   F-S- = system / backend (internal service method — no HTTP input boundary)
#   F-C- = cross-cutting (multi-layer concern, not an entity CRUD/workflow surface)
#   F-X- = custom (project-specific)
# The flow-artifact derivation gate is about INPUT-ACCEPTING (i.e. user-facing)
# transition steps, so we EXCLUDE the known-internal classes (F-S-/F-C-/F-X-) and
# DEFAULT-INCLUDE everything else (an unrecognized / prefix-less flow is still
# checked — missing a real defect is worse than a rare false positive).
SYSTEM_FLOW_RE = re.compile(r"\bF-[SCX]-?\d+\b", re.IGNORECASE)

flows = []  # list of dicts: {vault, header, tokens, n_input_steps, step_detail[], body}
for fvault, header, body in flow_sections:
    if SYSTEM_FLOW_RE.search(header):
        continue  # system / cross-cutting / custom flow — no external input boundary
    tokens = flow_entity_tokens(header)
    if not tokens:
        continue
    blocks = split_step_blocks(body)
    n_input = 0
    detail = []
    hdr1 = header.splitlines()[0].strip()
    for bi, block in enumerate(blocks, 1):
        if any(k["_re"].search(block) for k in endpoint_kinds):
            n_input += 1
            first_line = block.strip().splitlines()[0].strip() if block.strip() else ""
            detail.append(f"{hdr1} step {bi}: {first_line[:80]}")
    flows.append({
        "vault": fvault, "header": hdr1, "tokens": tokens, "n_input_steps": n_input,
        "step_detail": detail, "body": body,
    })

# ── Parse units: tokens, artifact count, target list (vault-tagged) ──────────
_unit_vault = {}
for _fp, _ups, _vn in all_candidates:
    for _u in _ups:
        _unit_vault.setdefault(_u, _vn)  # S5 round-2: first (base-vault) tag wins

units = []  # list of dicts: {vault, uid, tokens, n_artifacts, targets[]}
for up in unit_paths:
    fm, target_files, text = parse_unit(up)
    tokens = unit_entity_tokens(fm, target_files)
    uid = fm.get("unit_id") or os.path.splitext(os.path.basename(up))[0]
    expanded = []
    for tf in target_files:
        expanded.extend(expand_braces(tf))
    n_art = 0
    for tf in expanded:
        if any(glob_match(tf, k["path_glob"]) for k in endpoint_kinds):
            n_art += 1
    units.append({"vault": _unit_vault.get(up, ""), "uid": uid, "tokens": tokens,
                  "n_artifacts": n_art, "targets": expanded})


def tokens_match(a, b):
    """A flow and a unit are the same module iff their entity token sets share at
    least one significant token."""
    return bool(a & b)


def same_scope(fl, u):
    """S5 GU-HOOK-5: flow<->unit pairing is vault-scoped — cross-vault token
    collisions must never satisfy (or pollute) another vault's coverage."""
    return fl["vault"] == u["vault"] and tokens_match(fl["tokens"], u["tokens"])


# ── Coverage misses: per flow that some unit builds, sum its module's artifacts ─
# A flow's "module" = the set of units whose tokens overlap the flow's tokens.
# Aggregate input steps per flow vs the artifacts those matched units collectively
# list (de-dup units that match multiple flows is fine — coverage is per-flow demand).
missing_artifacts = []
for fl in flows:
    if fl["n_input_steps"] == 0:
        continue
    matched = [u for u in units if same_scope(fl, u)]
    if not matched:
        # flow has no implementing unit in this set => out-of-scope flow, not a miss
        continue
    n_art = sum(u["n_artifacts"] for u in matched)
    if fl["n_input_steps"] > n_art:
        missing_artifacts.append({
            "vault": fl["vault"],
            "module": "".join(sorted(fl["tokens"])),
            "flow": fl["header"],
            "flow_steps_accepting_input": fl["n_input_steps"],
            "artifacts_listed": n_art,
            "shortfall": fl["n_input_steps"] - n_art,
            "expected": f"{fl['n_input_steps']} artifact(s) matching {endpoint_kinds[0]['path_glob']} across unit(s) {sorted(set(u['uid'] for u in matched))}",
            "steps": fl["step_detail"][:fl["n_input_steps"]],
        })

# ── Dead scaffold: artifact listed by a unit but its module's flows have no ────
# gating endpoint. Module flow text = concatenation of all flows whose tokens
# overlap the unit's tokens. De-dup by resolved artifact path.
dead_seen = set()
dead_scaffold = []
for u in units:
    matched_flow_text = "\n".join(fl["body"] for fl in flows if same_scope(fl, u))
    for tf in u["targets"]:
        for e in scaffold_entries:
            if glob_match(tf, e["artifact_glob"]):
                gated = bool(matched_flow_text) and bool(e["_re"].search(matched_flow_text))
                if not gated and tf not in dead_seen:
                    dead_seen.add(tf)
                    dead_scaffold.append({
                        "artifact": tf,
                        "unit": u["uid"],
                        "module": "".join(sorted(u["tokens"])),
                        "reason": f"no flow step matching {e['requires_flow_endpoint']} in this module's flow(s) — dead scaffold stub",
                    })

# ── Decomposition altitude (Iter-79 A1, ADVISORY) ─────────────────────────────
# A whole N-step flow absorbed by a SINGLE unit is module-altitude decomposition (the
# 6-stage F-U-008 owned by one unit in the tradefinance run). Signal computed from data
# already parsed: one matched unit + a flow with n_input_steps ≥ K. ADVISORY ONLY — it does
# NOT flip status (the symptom gates above already neutralize the damage; the per-stage
# under-coverage shows up as missing_artifacts). Surfaced as telemetry so a coarse unit is
# visible without over-blocking a legitimately-single-unit flow that DOES cover every step.
ALTITUDE_K = 4
altitude_concentration = []
for fl in flows:
    if fl["n_input_steps"] < ALTITUDE_K:
        continue
    matched = [u for u in units if same_scope(fl, u)]
    if len(matched) == 1:
        altitude_concentration.append({
            "halt_type": "decomposition_altitude_high",
            "flow": fl["header"],
            "n_input_steps": fl["n_input_steps"],
            "absorbing_unit": matched[0]["uid"],
            "detail": (
                f"flow '{fl['header']}' has {fl['n_input_steps']} input-accepting steps but is "
                f"absorbed by a SINGLE unit ({matched[0]['uid']}) — likely cut at module altitude "
                f"rather than stage altitude. Advisory: confirm per-stage artifacts + render test "
                f"+ sibling parity are all present on this coarse unit."
            ),
        })

# ── Verdict ──────────────────────────────────────────────────────────────────
status = "FAIL" if (missing_artifacts or dead_scaffold) else "PASS"
total_missing = sum(m["shortfall"] for m in missing_artifacts)
report = {
    "status": status,
    "validator": "flow-coverage",
    "ts": ts,
    "vault": vault_name,
    "flows_file": os.path.relpath(flows_path, cwd),
    "vaults_checked": [c[2] for c in all_candidates],
    "summary": {
        "units_checked": len(unit_paths),
        "flows_with_input_steps": sum(1 for fl in flows if fl["n_input_steps"] > 0),
        "missing_form_artifacts_total": total_missing,
        "dead_scaffold_stubs": len(dead_scaffold),
        "altitude_concentration_count": len(altitude_concentration),
    },
    "missing_artifacts": missing_artifacts,
    "dead_scaffold": dead_scaffold,
    "altitude_concentration": altitude_concentration,
    "next_action": (
        "Add the missing per-step input-validation artifacts (e.g. Form Requests) "
        "to the relevant module unit's `## Target files`, and remove any dead "
        "scaffold stub whose gating flow endpoint does not exist; then re-save the "
        "unit (PostToolUse will re-validate)."
    ) if status == "FAIL" else "No action — every input-accepting flow step maps to an artifact; no dead stubs.",
}

write_and_exit(report, 0 if status == "PASS" else 1)
PYEOF

EXIT_CODE=$?
exit $EXIT_CODE
