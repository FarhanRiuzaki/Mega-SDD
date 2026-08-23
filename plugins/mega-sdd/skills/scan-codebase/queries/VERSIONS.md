# Query-pack registry — ast-grep glossary (tier 1; the tree-sitter grammar matrix was removed with its lane, v7.4.0)

## ast-grep rule packs (`astgrep/<lang>.yml` — the AUTO lane glossary)

Grammars are EMBEDDED in the ast-grep binary — nothing to install per language. Kind names verified live against **ast-grep 0.42.3** (glossary lab, 2026-08-03). **Lane law:** one pack per ast-grep language, filename == language key == every rule's `language:` field — the Step-0 router derives lanes from filenames, so rules parked in another file are invisible to routing (the tsx regression, fixed 2026-08-03).

| Language | Pack | Extensions | Definition kinds |
|---|---|---|---|
| TypeScript | `typescript.yml` | .ts | function/class/interface/type-alias/enum/method + arrow & function-expr bindings |
| TSX | `tsx.yml` | .tsx | same as TypeScript (tsx is its OWN ast-grep language) |
| JavaScript | `javascript.yml` | .js/.jsx/.mjs/.cjs | function/generator/class/method + arrow & function-expr bindings — .jsx parses under this grammar (router alias `jsx→javascript`; never add a jsx.yml) |
| PHP | `php.yml` | .php | per pack |
| Python | `python.yml` | .py | per pack |
| Rust | `rust.yml` | .rs | per pack |
| Go | `go.yml` | .go | per pack |
| Ruby | `ruby.yml` | .rb | per pack |
| Java | `java.yml` | .java | per pack |
| C# | `csharp.yml` | .cs | per pack |
| Kotlin | `kotlin.yml` | .kt/.kts | function/class (incl. interface + enum class)/object/companion_object/type_alias/property (guarded out of function bodies — locals are property_declaration nodes) |
| Swift | `swift.yml` | .swift | function/class (incl. struct/enum/actor/extension)/protocol/init — computed properties/subscript/typealias deliberately unmatched (accepted tradeoff) |
| Scala | `scala.yml` | .scala | function_definition + abstract function_declaration/class/object/trait/enum_definition/given_definition (Scala 3) |
| C | `c.yml` | .c/.h | function/struct+enum (BODY-guarded — bare specifiers match every usage site)/typedef. ⚠ .h always routes to C in ast-grep: C++-in-.h headers extract poorly (accepted, disclosed tradeoff — the real fix is an sgconfig languageGlobs remap) |
| C++ | `cpp.yml` | .cpp/.cc/.cxx/.hpp/.hh | function/class+struct+enum (BODY-guarded — forward declarations are noise)/template/namespace |
| Dart | `dart.yml` | .dart | function_signature (guarded out of method_signature — it WRAPS functions)/method_signature/constructor_signature/class/enum/mixin/extension |
| Elixir | `elixir.yml` | .ex/.exs | def-form calls only (`def/defp/defmacro/defmacrop/defguard/defguardp/defdelegate/defmodule/defimpl/defprotocol/defstruct` via target regex — a bare `call` kind matches every call) |
| Lua | `lua.yml` | .lua | function_declaration (global/local/table-method statement forms; assignment-form `M.f = function()` deliberately unmatched — anonymous node, nameless row) |
| Bash | `bash.yml` | .sh/.bash | function_definition |
| Haskell | `haskell.yml` | .hs | function (guarded out of signature nodes)/signature/data_type/newtype/class |

## ast-grep (tier 1 — `astgrep/<lang>.yml` rule packs)

The tier-1 AUTO-lane rule packs in `astgrep/` are tested against **ast-grep 0.42.3**. ast-grep embeds
its grammars in the static binary — there is nothing to configure or compile, which is the
point of the tier (the clang grammar-compile OOM class cannot occur).

```bash
brew install ast-grep            # macOS
scoop install ast-grep           # Windows (Git Bash boxes — no cargo/brew needed)
winget install ast-grep.ast-grep # Windows alternative
cargo install ast-grep           # Cross-platform
npm install -g @ast-grep/cli     # Cross-platform alternative
```

Kind names in the packs are grammar-version-sensitive the same way `.scm` queries are; if a
pack stops matching after an ast-grep upgrade, report it like a grammar-drift issue below.

## Coverage gaps

These inputs fall back to regex extraction regardless of grammar/rule-pack availability:
- Blade templates (.blade.php), ERB templates (.erb)
- F# (.fs) — extracts via the dedicated F# regex row in `references/scan-procedure.md` Step 5 (no ast-grep built-in). Kotlin extracts at AST tier since the v5.33.0 glossary (`kotlin.yml`); its regex row remains only as the `astgrep_absent` fallback.
- Vue / Svelte single-file components
- Bleeding-edge TypeScript syntax (when the grammar lags the language)
- Configuration files (YAML / TOML — parsed as text)

## Reporting issues

If your project hits grammar drift (parses fail for valid code), report:
1. Language + tree-sitter grammar version
2. Sample failing snippet
3. Plugin version (from `plugin.json`)

Scan falls back to regex gracefully — the pipeline never breaks on grammar issues, but precision suffers.
