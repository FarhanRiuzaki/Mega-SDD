# Tree-sitter Integration (owner of the engine ladder — D2: ast-grep leads, tree-sitter is the opt-in lane)

## Contents
- The ladder (D2 — ast-grep is tier 1)
- Detection (`scripts/probe-scan-engine.sh`)
- Installation guidance (`dep_missing` blocker)
- Query files (`queries/tags-<lang>.scm`) — schema + per-language coverage
- Tier-2 rule packs (`queries/astgrep/<lang>.yml`)
- Invocation
- Precision tier in codebase-map.md frontmatter
- Grammar pinning
- Fallback behavior
- Performance characteristics

`scan-codebase` uses AST-level symbol extraction (ast-grep in auto; tree-sitter via explicit opt-in); regex extraction is preserved as the loud last resort.

## The ladder (D2, v5.31.0 — ast-grep is tier 1)

```
AUTO    tier 1  ast-grep      queries/astgrep rule packs; ONE spawn total; grammars EMBEDDED — zero compilation
        tier 2  regex         v1 patterns; one spawn per LANGUAGE; loud warning; precision_tier: regex
OPT-IN  --engine=tree-sitter  .scm tag queries; one spawn per FILE; grammars compiled LOCALLY (clang);
                              grammar smoke tests run HERE ONLY — serial, bounded, kill-classified
```

Resolution is **per language**: a packed language extracts via ast-grep at
`precision_tier: ast`; a language with no rule pack falls to regex (`no_astgrep_pack`,
recorded). **tree-sitter is never probed in auto** — the clang grammar-compile OOM class
(`clang: … Killed: 9` on stderr at rc=1, live incident 2026-08-02, reproduced again at
the D2 flip) is structurally unreachable on any unattended run. The explicit
`--engine=tree-sitter` lane keeps full T1 behavior for hand-configured-grammar machines:
serial bounded smoke tests, `grammars_used`, per-language regex fallback with named
reasons — and never a silent detour to ast-grep (the caller chose tree-sitter).

Why ast-grep leads: default tree-sitter installs ship ZERO grammars (manual clone +
config nobody does); grammar compiles OOM the machine class this plugin actually runs on;
one-spawn-per-FILE is the Windows/EDR hang class — while ast-grep is a static binary,
embedded grammars, ONE spawn for the whole set, and `precision_tier` stays `ast` so
bind-codebase field-level diff is untouched (scan-procedure.md §Spawn-cost gate).

## Detection

Engine detection is a DETERMINISTIC SCRIPT, not prose: `scripts/probe-scan-engine.sh`
(scan-procedure.md §Step 0 has the invocation + digest schema). In AUTO it probes
`ast-grep` and resolves the ladder without ever invoking tree-sitter (both tree-sitter
binary names are still version-probed for provenance — a bounded `--version`, no
compile). Under `--engine=tree-sitter` it runs the per-language grammar smoke tests
**SERIALLY with a hard per-probe timeout** (the smoke test is also the clang compile
step — serializing it inside the script is what makes the opt-in lane safe), and emits
one JSON digest either way. Per-language fallback reasons
are first-class. Auto lane: `no_astgrep_pack` (language without a rule pack → regex),
`astgrep_absent` (no ast-grep → regex, loud warning). Opt-in tree-sitter lane:
`grammar_compile_killed` (the OOM class — retryable, NOT an install problem),
`grammar_compile_failed`, `grammar_missing`, `query_error`, `probe_timeout`,
`binary_unrunnable` (found on PATH but not executable — e.g. npm's sh shim under Windows
CreateProcess), `no_query_file`. Non-fallback record on every lane: `no_source_file`
(scaffold-only language — skipped, never failed; the primary ast-grep route is recorded
in `astgrep_langs`, never as a fallback — the map's downgrade field stays clean on the
happy path).

- Binary presence alone proves nothing — the CLI installs with zero grammars configured.
  Only languages that pass the smoke test extract at tier 1 and appear in `grammars_used`.
- User can force a tier via `--engine=tree-sitter|ast-grep|regex`; a forced engine whose
  binary is absent HALTS `dep_missing` (never a silent fall-through).

`precision_tier: ast` is therefore a **verified** claim: it is stamped only when at least one language actually extracted through a working grammar or a tier-2 rule pack, never from binary presence alone.

## Installation guidance

If a FORCED engine's binary is not on PATH (`--engine=tree-sitter` without tree-sitter, `--engine=ast-grep` without ast-grep) OR halt-strict mode active, emit `dep_missing` blocker (`required_binary` + `install_commands` name the forced binary — the ast-grep variant installs via `brew install ast-grep` / `scoop install ast-grep` / `cargo install ast-grep` / `npm install -g @ast-grep/cli`):

```yaml
blocker:
  type: dep_missing
  emitted_at: <ISO8601>
  emitted_by: scan-codebase
  details:
    required_binary: tree-sitter
    install_commands:
      macos: "brew install tree-sitter-cli"
      linux: "cargo install tree-sitter-cli"
      windows: "scoop install tree-sitter"
      universal: "npm install -g tree-sitter-cli"
  next_action: "Install tree-sitter then re-run, OR use --engine=regex for fallback (lower precision)"
```

Design decision: document the install, don't bundle binaries (keeps the plugin small and avoids per-OS binary maintenance).

## Query files (`queries/tags-<lang>.scm`)

Tree-sitter queries written in S-expression syntax. Adapted from [Aider's tags.scm](https://github.com/Aider-AI/aider/tree/main/aider/queries).

### Schema

Each query file targets entity extraction:
- `@name.definition.<kind>` — symbol definition (function, class, method, etc.)
- `@name.reference.<kind>` — symbol reference (call site, import, etc.)

Mega-sdd's scan-codebase consumes these to populate codebase-map.md §2 (public interfaces) + §3 (routes) + §4 (data models).

### Per-language coverage (shipped query files)

- `tags-typescript.scm` — TS classes, functions, interfaces, types
- `tags-javascript.scm` — JS classes, functions, exports
- `tags-php.scm` — PHP classes, methods, traits, interfaces
- `tags-python.scm` — Python classes, functions, decorators
- `tags-rust.scm` — Rust pub fn, struct, enum, trait, impl
- `tags-go.scm` — Go func, type, method
- `tags-ruby.scm` — Ruby classes, modules, methods
- `tags-java.scm` — Java classes, interfaces, enums, records, methods
- `tags-csharp.scm` — C# classes, interfaces, records, structs, methods

Languages without a `.scm` file under the opt-in lane → fall to regex (never a silent ast-grep detour); in AUTO the `.scm` files are simply unused.

## Tier-1 AUTO-lane rule packs (`queries/astgrep/<lang>.yml`)

Kind-based ast-grep definition rules, ONE pack per ast-grep language — 20 packs since the
v5.33.0 glossary (ts, tsx, js, php, python, rust, go, ruby, java, csharp, kotlin, swift,
scala, c, cpp, dart, elixir, lua, bash, haskell), verified against ast-grep 0.42.3
(`queries/VERSIONS.md` — the glossary registry). **Lane law:** the Step-0 router derives
language lanes from pack FILENAMES, so every rule's `language:` must equal its pack's
basename (tsx once lived inside typescript.yml and was invisible to routing — 182 .tsx
files fell to regex). `jsx` is an ALIAS to the javascript lane (the js grammar parses JSX;
a jsx.yml would double-count every .jsx symbol). Only the original 9 languages have a
`.scm` mirror in the opt-in tree-sitter lane; the other 11 extract at AST tier in AUTO
only. The extraction invocation, the
verified JSON contract (0-based lines, `lines` = full node text, dedupe by
`(file, start.line)`), and the `---`-separator concatenation seam live in
scan-procedure.md §Step 5 "If `engine: ast-grep`". Reference captures
(`@name.reference.*`) do NOT exist at tier 2 — and since 5.29.0 nothing consumes them
(the generate-units PageRank pass was removed; reuse now rides the write-time
`symbol_slice` in execute-bolts dispatches).

## Invocation

For each detected language in the repo:

```bash
tree-sitter query queries/tags-<lang>.scm <file> --captures
```

Output is structured (line + column + capture name + symbol text). Skill parses this into codebase-map.md tables.

## Precision tier in codebase-map.md frontmatter

```yaml
---
generated_by: mega-sdd:scan-codebase
generated_at: <ISO8601>
engine: tree-sitter | ast-grep | regex
precision_tier: ast | regex
tree_sitter_version: <version>
astgrep_version: <version>
grammars_used: ["typescript", "php"]
---
```

`bind-codebase` reads `precision_tier`:
- `ast` → claim matches are anchor-precise; binding verdicts more reliable
- `regex` → binding adds note "scan engine: regex (lower precision); manual review of edge cases recommended"

## Grammar pinning

Tree-sitter grammars evolve; bleeding-edge syntax may not parse correctly. Mitigation:

- Plugin documents tested grammar versions in `scan-codebase/queries/VERSIONS.md`
- Skill emits warning if installed grammar version differs significantly
- User can pin grammar via tree-sitter config

## Fallback behavior

In AUTO the only fall is to regex (`no_astgrep_pack` per unpacked language, or
`astgrep_absent` for the whole run) — recorded in the Step-0 digest's `fallbacks[]`
and stamped into `precision_downgrade_reason`. Falling to regex:

1. Emit chat line: "⚠️ ast-grep not installed; using regex engine (lower precision). Install: brew install ast-grep / scoop install ast-grep — or run `/mega-sdd:install-deps`" (the Step-0 warning — one wording, owned there).
2. Run v1 regex extraction (preserved unchanged from v1.2)
3. `precision_tier: regex` stamped in codebase-map.md frontmatter
4. Downstream skills (bind-codebase) treat as lower-confidence ground truth

Backward-compat: v1.2 codebase-map files (without `precision_tier` field) treated as `regex` by all downstream skills.

## Performance characteristics

| Engine | Time per 1000 files | Memory |
|---|---|---|
| Tree-sitter | ~2-5s (incremental, sub-ms per file) | ~50MB peak (+ clang grammar compile on first use — the OOM point) |
| ast-grep | ~1-3s (ONE process, parallel in-process) | ~100MB peak; NO compile step ever |
| Regex (v1) | ~5-15s (file traversal + multi-pattern match) | ~30MB peak |

AST engines are FASTER on typical repos AND more precise. Trade-off is an install step —
and only the opt-in tree-sitter lane ever compiles anything locally; the auto path never does.
