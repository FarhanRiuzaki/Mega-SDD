#!/usr/bin/env bash
# kb-leak-scan.sh — [HOOK-VALIDATE] tech-agnostic KB tech-leak detector.
#
# Replaces the old hardcoded `grep 'varchar\|int(11)\|MySQL\|MSSQL\|composer'`
# inline gate in extract-intelligence wave-dispatch-templates.md. That grep only
# knew PHP/SQL tokens, so a C# domain file leaking `DbContext` / `IServiceCollection`
# / `[HttpGet]`, a Java file leaking `@Entity` / `@Autowired`, a Go file leaking
# `go.mod` / `gorm`, etc., passed the leak check entirely.
#
# A knowledge-base domain body MUST be tech-agnostic (no language / framework / DB
# names) EXCEPT in `## 11. Source References` sections and under `50-integrations/`.
# This script scans 10-domains/ 20-workflows/ 30-data-model/ for any supported
# stack's leak tokens, section-aware (skips §11 bodies) and dir-aware (skips
# 50-integrations/).
#
# Stack selection:
#   --stack=auto  (default) — read <kb-dir>/.scan-meta.json language breakdown;
#                 if absent/unknown, fall back to the UNION of every stack's tokens
#                 (strictly more correct for a tech-agnostic check — no stack's
#                 idioms should appear regardless of which the legacy used).
#   --stack=php|js|ts|python|csharp|java|go|ruby|rust|all — force one set (or all).
#
# Wiring stance: ADVISORY (mirrors the inline grep it replaces) — prints hits +
# count, exits 0. Pass --strict to exit 1 when hits are found.
#
# Usage: kb-leak-scan.sh --kb-dir=<knowledge-base dir> [--stack=auto] [--strict] [--quiet]
# Exit: 0=clean/advisory, 1=hits-found-and-strict, 2=error

set -uo pipefail

KB_DIR=""
STACK="auto"
STRICT=0
QUIET=0

for arg in "$@"; do
  case "$arg" in
    --kb-dir=*) KB_DIR="${arg#--kb-dir=}" ;;
    --stack=*)  STACK="${arg#--stack=}" ;;
    --strict)   STRICT=1 ;;
    --quiet)    QUIET=1 ;;
  esac
done

if [ -z "$KB_DIR" ]; then KB_DIR="$(pwd)"; fi

# The kb-dir may be passed as the project root OR the knowledge-base dir itself.
# Normalise: if a `knowledge-base/` child exists, descend into it.
if [ -d "${KB_DIR}/knowledge-base" ]; then KB_DIR="${KB_DIR}/knowledge-base"; fi

RESULT=$(python3 -W ignore::DeprecationWarning - "$KB_DIR" "$STACK" <<'PYEOF'
import json, os, re, sys

kb_dir = sys.argv[1]
stack_arg = sys.argv[2].lower()

# --- token sets: chosen to be distinctive tech-leak signals (avoid generic English) ---
UNIVERSAL = [  # SQL/DB engine + physical-type leaks — apply to every stack
    "varchar", "nvarchar", "int(11)", "tinyint", "bigint", "AUTO_INCREMENT",
    "MySQL", "MSSQL", "PostgreSQL", "Postgres", "MongoDB", "SQLite",
    # Oracle / DB2 / MariaDB physical-type + engine leaks. Kept DISTINCTIVE — bare
    # "Oracle" (price oracle) and "NUMBER(" (ACCOUNT_NUMBER() substring-match business
    # content, so they are intentionally excluded; VARCHAR2/NCLOB/DB2 are Oracle/DB2-
    # exclusive and unambiguous.
    "VARCHAR2", "NCLOB", "DB2", "MariaDB",
]
STACKS = {
    "php":    ["composer", "$_GET", "$_POST", "<?php", "namespace ", "Eloquent", "Laravel", "Symfony"],
    "js":     ["package.json", "node_modules", "useState", "useEffect", "tsconfig", "npm install"],
    "ts":     ["package.json", "node_modules", "useState", "useEffect", "tsconfig", "npm install"],
    "python": ["requirements.txt", "__init__", "Django", "Flask", "SQLAlchemy", "@app.route", "pip install"],
    "csharp": ["DbContext", "IServiceCollection", "[HttpGet]", "[HttpPost]", "[Authorize]",
               "async Task", "IEnumerable", "NuGet", "appsettings.json", ".csproj", "Entity Framework"],
    "java":   ["@Entity", "@Autowired", "@RestController", "@RequestMapping", "@Service",
               "Hibernate", "Spring Boot", "pom.xml", "Maven", "Gradle"],
    "go":     ["go.mod", "gorm", "goroutine", "package main", "chan "],
    "ruby":   ["Gemfile", "ActiveRecord", "attr_accessor", "ApplicationRecord", "Rails"],
    "rust":   ["Cargo.toml", "#[derive", "impl ", "pub fn", "tokio"],
}

# Map .scan-meta.json language names → stack keys.
LANG_MAP = {
    "php": "php",
    "javascript": "js", "js": "js", "node": "js", "nodejs": "js",
    "typescript": "ts", "ts": "ts",
    "python": "python", "py": "python",
    "c#": "csharp", "csharp": "csharp", "cs": "csharp", ".net": "csharp", "dotnet": "csharp",
    "vb": "csharp", "vb.net": "csharp", "vbnet": "csharp",
    "java": "java", "kotlin": "java",
    "go": "go", "golang": "go",
    "ruby": "ruby", "rb": "ruby",
    "rust": "rust", "rs": "rust",
}

def detect_stacks():
    """Return (list-of-stack-keys, source-label)."""
    if stack_arg and stack_arg != "auto":
        if stack_arg == "all":
            return sorted(set(STACKS)), "forced:all"
        if stack_arg in STACKS:
            return [stack_arg], f"forced:{stack_arg}"
        return sorted(set(STACKS)), f"unknown-stack({stack_arg})→all"
    # auto: read .scan-meta.json
    meta = os.path.join(kb_dir, ".scan-meta.json")
    if os.path.isfile(meta):
        try:
            with open(meta, "r", errors="replace") as f:
                m = json.load(f)
            found = set()
            blob = json.dumps(m).lower()
            # Match each language as a quoted JSON token ("c#", "java", …) — robust for
            # both array form ["C#"] and key form {"C#": 12}, and avoids substring false
            # positives ("go" inside "django", "java" inside "javascript").
            for lang, key in LANG_MAP.items():
                if ('"' + lang + '"') in blob:
                    found.add(key)
            if found:
                return sorted(found), "scan-meta"
        except Exception:
            pass
    return sorted(set(STACKS)), "auto→all(no scan-meta)"

stacks, src = detect_stacks()
tokens = list(UNIVERSAL)
for s in stacks:
    tokens.extend(STACKS.get(s, []))
# de-dup, longest-first so the reported token is the most specific match
tokens = sorted(set(tokens), key=len, reverse=True)

# M6: the whole KB body is in scope EXCEPT §11 and 50-integrations/ — so scan
# 00-overview, 40-business-rules, and 99-rebuild-architecture too (a DbContext /
# @Entity / Eloquent / gorm leak in a business-rule or rebuild-architecture file
# used to pass clean). The additions are SECTION-AWARE to avoid the legitimate
# framework names in `## Departures from Legacy` and the legacy PATHS cited in a
# table's Source / Mandated-by column.
SCAN_DIRS = ["00-overview", "10-domains", "20-workflows", "30-data-model",
             "40-business-rules", "99-rebuild-architecture"]

_SRC_COL_RE = re.compile(r"\bsource\b|\bmandated by\b|\bcitation\b", re.IGNORECASE)
_TABLE_SEP_RE = re.compile(r"^\s*\|?[\s:|-]+\|?\s*$")

def scannable_lines(text):
    """Yield (0-based line index, text-to-scan) for lines that carry tech-agnostic
    KB prose. Skips whole `## 11.` (Source References) and `## Departures from
    Legacy` sections (both legitimately name legacy tech), and blanks a markdown
    table's Source / Mandated-by / Citation column cell (it cites legacy PATHS)."""
    lines = text.splitlines()
    skip_section = False
    source_col = None
    for i, line in enumerate(lines):
        if re.match(r"^##\s", line):
            low = line.lower()
            skip_section = (bool(re.match(r"^##\s*11[\.\s]", line))
                            or ("source reference" in low)
                            or ("departures from legacy" in low))
            source_col = None
        if skip_section:
            continue
        if not line.strip():
            source_col = None
        # Learn the Source column index ONLY from a GENUINE header row: it names a
        # Source-like column AND the NEXT line is the table separator (`|---|---|`).
        # A DATA row that merely contains "source of funds" / "source system" (common
        # in banking content) is NOT a header — without the separator check it would
        # hijack source_col and blank a CONTENT column in later rows, hiding real leaks.
        nxt = lines[i + 1] if i + 1 < len(lines) else ""
        if ("|" in line and _SRC_COL_RE.search(line)
                and not _TABLE_SEP_RE.match(line) and _TABLE_SEP_RE.match(nxt)):
            cells = line.split("|")
            for ci, h in enumerate(cells):
                if _SRC_COL_RE.search(h):
                    source_col = ci
                    break
        scan = line
        if source_col is not None and "|" in line and not _TABLE_SEP_RE.match(line):
            cells = line.split("|")
            if source_col < len(cells):
                cells[source_col] = ""   # blank the Source cell (legacy paths, not leaks)
                scan = "|".join(cells)
        yield i, scan

hits = []
files_scanned = 0
if os.path.isdir(kb_dir):
    for d in SCAN_DIRS:
        base = os.path.join(kb_dir, d)
        if not os.path.isdir(base):
            continue
        for root, _dirs, files in os.walk(base):
            for fn in files:
                if not fn.endswith(".md"):
                    continue
                fp = os.path.join(root, fn)
                files_scanned += 1
                try:
                    with open(fp, "r", errors="replace") as fh:
                        text = fh.read()
                except Exception:
                    continue
                rel = os.path.relpath(fp, kb_dir)
                orig = text.splitlines()
                for i, scan in scannable_lines(text):
                    for tok in tokens:
                        if tok in scan:
                            hits.append({"file": rel, "line": i + 1, "token": tok,
                                         "text": orig[i].strip()[:120]})
                            break  # one hit per line is enough

print(json.dumps({
    "kb_dir": kb_dir,
    "stack_source": src,
    "stacks": stacks,
    "files_scanned": files_scanned,
    "hit_count": len(hits),
    "hits": hits[:50],
}))
PYEOF
)

if [ -z "$RESULT" ]; then
  [ "$QUIET" -eq 0 ] && echo "kb-leak-scan: error (no result)"
  exit 2
fi

HIT_COUNT=$(echo "$RESULT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('hit_count',0))" 2>/dev/null || echo 0)

if [ "$QUIET" -eq 0 ]; then
  # Pass RESULT via env var (NOT a pipe): `python3 - <<heredoc` reads the program from
  # the heredoc, so stdin is unavailable for the JSON payload.
  KB_LEAK_RESULT="$RESULT" python3 - <<'PYOUT'
import json, os
d = json.loads(os.environ.get("KB_LEAK_RESULT", "{}"))
print(f"kb-leak-scan: {d.get('hit_count',0)} tech-leak hit(s) across {d.get('files_scanned',0)} domain file(s) "
      f"(stacks={','.join(d.get('stacks',[]))} via {d.get('stack_source','?')})")
for h in d.get("hits", []):
    print(f"  LEAK {h['file']}:{h['line']}  «{h['token']}»  {h['text']}")
if d.get("hit_count", 0) > len(d.get("hits", [])):
    print(f"  … {d['hit_count'] - len(d['hits'])} more (capped)")
if d.get("hit_count", 0) == 0:
    print("  (clean — no stack-specific tokens leaked outside §11 / 50-integrations/)")
PYOUT
fi

if [ "$STRICT" -eq 1 ] && [ "${HIT_COUNT:-0}" -gt 0 ]; then
  exit 1
fi
exit 0
