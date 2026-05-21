# Tree-sitter Grammar Versions (tested compatibility)

Mega-sdd v3.0+ tested against these tree-sitter grammar versions. If your installed grammars differ significantly, expect parse warnings or fallback to regex.

## Tested combinations

| Language | Grammar repo | Tested version | Notes |
|---|---|---|---|
| TypeScript | tree-sitter/tree-sitter-typescript | v0.21.x | Covers .ts + .tsx |
| JavaScript | tree-sitter/tree-sitter-javascript | v0.21.x | Covers .js + .jsx + .mjs |
| PHP | tree-sitter/tree-sitter-php | v0.22.x | Covers .php only (not Blade) |
| Python | tree-sitter/tree-sitter-python | v0.21.x | Covers .py |
| Rust | tree-sitter/tree-sitter-rust | v0.21.x | Covers .rs |
| Go | tree-sitter/tree-sitter-go | v0.21.x | Covers .go |

## Installation

```bash
# Install tree-sitter CLI
brew install tree-sitter        # macOS
cargo install tree-sitter-cli   # Cross-platform
npm install -g tree-sitter-cli  # Cross-platform alternative

# Grammars auto-install on first use via:
tree-sitter init-config         # create ~/.config/tree-sitter/config.json
# Grammars then download lazily when scan-codebase invokes queries
```

## Coverage gaps (v3.0)

These languages will fall back to regex extraction:
- Blade templates (.blade.php)
- Vue / Svelte single-file components
- Bleeding-edge TypeScript (e.g., new decorators if grammar lags)
- Configuration files (YAML / TOML — parsed as text)

Future iters may add grammars for these as they stabilize.

## Reporting issues

If your project hits grammar drift (parses fail for valid code), report:
1. Language + tree-sitter grammar version
2. Sample failing snippet
3. Mega-sdd version (currently 3.0.0+)

Mega-sdd falls back to regex gracefully — pipeline never breaks on grammar issues. But precision suffers.
