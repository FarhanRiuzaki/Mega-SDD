# Tree-sitter Integration

## Contents
- Detection
- Installation guidance (`dep_missing` blocker)
- Query files (`queries/tags-<lang>.scm`) — schema + per-language coverage
- Invocation
- Precision tier in codebase-map.md frontmatter
- Grammar pinning
- Fallback behavior
- Performance characteristics

`scan-codebase` uses tree-sitter for precise AST-level symbol extraction. Replaces regex-based extraction (which is preserved as fallback when tree-sitter is unavailable).

## Detection

At skill startup, probe for tree-sitter via BOTH binary names (package managers ship under different names — see SKILL.md Step 0):

```bash
command -v tree-sitter || command -v tree-sitter-cli
```

- Found (either) → use tree-sitter engine (precision tier: `ast`)
- Not found → fall back to regex engine (precision tier: `regex`); emit one-line warning in chat
- User can force engine via `--engine=tree-sitter` (halts if absent) or `--engine=regex` (skip detection)

## Installation guidance

If tree-sitter not on PATH and `--engine=tree-sitter` is set OR halt-strict mode active, emit `dep_missing` blocker:

```yaml
blocker:
  type: dep_missing
  emitted_at: <ISO8601>
  emitted_by: scan-codebase
  details:
    required_binary: tree-sitter
    install_commands:
      macos: "brew install tree-sitter"
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

Mega-sdd's scan-codebase consumes these to populate codebase-map.md §2 (public interfaces) + §3 (data models) + §4 (routes).

### Per-language coverage (shipped query files)

- `tags-typescript.scm` — TS classes, functions, interfaces, types
- `tags-javascript.scm` — JS classes, functions, exports
- `tags-php.scm` — PHP classes, methods, traits, interfaces
- `tags-python.scm` — Python classes, functions, decorators
- `tags-rust.scm` — Rust pub fn, struct, enum, trait, impl
- `tags-go.scm` — Go func, type, method
- `tags-ruby.scm` — Ruby classes, modules, methods
- `tags-java.scm` — Java classes, interfaces, enums, records, methods

Languages without `.scm` file → fall back to regex (graceful degradation).

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
engine: tree-sitter | regex
precision_tier: ast | regex
tree_sitter_version: <version>
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

When falling back to regex:

1. Emit chat line: "⚠️ scan-codebase using regex engine (tree-sitter not found). Precision tier: regex. Consider installing tree-sitter for AST-precise extraction."
2. Run v1 regex extraction (preserved unchanged from v1.2)
3. `precision_tier: regex` stamped in codebase-map.md frontmatter
4. Downstream skills (bind-codebase) treat as lower-confidence ground truth

Backward-compat: v1.2 codebase-map files (without `precision_tier` field) treated as `regex` by all downstream skills.

## Performance characteristics

| Engine | Time per 1000 files | Memory |
|---|---|---|
| Tree-sitter | ~2-5s (incremental, sub-ms per file) | ~50MB peak |
| Regex (v1) | ~5-15s (file traversal + multi-pattern match) | ~30MB peak |

Tree-sitter is FASTER on typical repos AND more precise. Trade-off is install step.
