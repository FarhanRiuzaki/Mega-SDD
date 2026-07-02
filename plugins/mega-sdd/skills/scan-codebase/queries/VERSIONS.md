# Tree-sitter Grammar Versions (tested compatibility)

The query files in this directory are tested against these tree-sitter grammar versions. If your installed grammars differ significantly, expect parse warnings or fallback to regex.

## Tested combinations

| Language | Grammar repo | Tested version | Query file | Notes |
|---|---|---|---|---|
| TypeScript | tree-sitter/tree-sitter-typescript | v0.21.x | `tags-typescript.scm` | Covers .ts + .tsx |
| JavaScript | tree-sitter/tree-sitter-javascript | v0.21.x | `tags-javascript.scm` | Covers .js + .jsx + .mjs + .cjs |
| PHP | tree-sitter/tree-sitter-php | v0.22.x | `tags-php.scm` | Covers .php only (not Blade) |
| Python | tree-sitter/tree-sitter-python | v0.21.x | `tags-python.scm` | Covers .py |
| Rust | tree-sitter/tree-sitter-rust | v0.21.x | `tags-rust.scm` | Covers .rs |
| Go | tree-sitter/tree-sitter-go | v0.21.x | `tags-go.scm` | Covers .go |
| Ruby | tree-sitter/tree-sitter-ruby | v0.21.x | `tags-ruby.scm` | Covers .rb (not .erb templates) |
| Java | tree-sitter/tree-sitter-java | v0.21.x | `tags-java.scm` | Covers .java (not Kotlin) |
| C# | tree-sitter/tree-sitter-c-sharp | v0.21.x | `tags-csharp.scm` | Covers .cs (not .fsx/.fs — F# extracts via regex) |

## Installation

```bash
# Install tree-sitter CLI
brew install tree-sitter        # macOS
cargo install tree-sitter-cli   # Cross-platform
npm install -g tree-sitter-cli  # Cross-platform alternative

# Grammars must be available to the CLI:
tree-sitter init-config         # create ~/.config/tree-sitter/config.json
# then clone the grammar repos listed above into a directory named in
# the config's "parser-directories" list (the CLI does NOT auto-download).
```

If a needed grammar is not installed, that language falls back to regex extraction — the scan never breaks, but precision drops to `regex` tier.

## Coverage gaps

These inputs fall back to regex extraction regardless of grammar availability:
- Blade templates (.blade.php), ERB templates (.erb)
- Kotlin (.kt) and F# (.fs) — extract via the dedicated Kotlin/F# regex rows in `references/scan-procedure.md` Step 5
- Vue / Svelte single-file components
- Bleeding-edge TypeScript syntax (when the grammar lags the language)
- Configuration files (YAML / TOML — parsed as text)

## Reporting issues

If your project hits grammar drift (parses fail for valid code), report:
1. Language + tree-sitter grammar version
2. Sample failing snippet
3. Plugin version (from `plugin.json`)

Scan falls back to regex gracefully — the pipeline never breaks on grammar issues, but precision suffers.
