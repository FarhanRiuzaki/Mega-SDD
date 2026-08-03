# ast-grep language glossary — the tsx fix + full built-in coverage

**Date:** 2026-08-03
**Status:** SHIPPED v5.33.0 (b3caa2f, CI green) — round-folded
**Trigger:** field finding on `training-nextjs` (operator's live test): the map header disclosed `tsx:no_astgrep_pack -> regex` — **182 `.tsx` files (the majority of a Next.js app's surface) extracted at regex tier** while only 131 `.ts` files got AST tier. Secondary symptom: the s2 `const` bucket hit its 200-row anti-halu cap because regex-tier extraction dumps every arrow-component into `const`.

## Root cause (not a missing rule — a routing blind spot)

The tsx rules EXISTED — parked inside `typescript.yml`. But `probe-scan-engine.sh` derives its lane set from pack **filenames** (`ASTGREP_LANGS = {basename(*.yml)}`), and the scan skill passes `tsx` as its own detected-language key (ast-grep treats tsx as its own language; `typescript`-tagged rules never match `.tsx` — verified live, 0 matches). So `tsx ∉ {filenames}` → `no_astgrep_pack` → regex, with the working rules sitting invisible one file over. A comment in the probe even asserted the wrong assumption ("the typescript pack also carries the tsx rules").

## The lane law (the durable contract)

> **One pack file per ast-grep language; filename == language key == every rule's `language:` field.** Rules parked in another file are invisible to routing.

Enforced by test, not prose: `tests/scan/test-astgrep-pack-glossary.sh` structurally asserts every rule's `language:` equals its pack basename, and the ladder test pins "tsx rules live in tsx.yml only".

**The one exception is an alias, not a pack.** ast-grep's `javascript` grammar parses JSX, so `.jsx` files already match javascript-tagged rules (verified live). A `jsx.yml` would therefore **double-count every `.jsx` symbol** in the symbol index (dedupe keys on ruleId — two ruleIds survive). Instead the probe carries `ASTGREP_ALIASES = {"jsx": "javascript"}`: the detected key `jsx` routes to the ast lane without new rules. Pinned both ways: "no jsx.yml exists" + "a .jsx function yields exactly 1 row across the concatenated glossary".

## The glossary (verified, not assumed)

Every kind name was verified **live against ast-grep 0.42.3** (scratchpad lab: sample source per language × candidate kinds; unknown kinds fail rule-parse, so acceptance = the rule fired). Registry: `queries/VERSIONS.md`.

- **Split:** `tsx.yml` (out of typescript.yml — function/class/interface/type-alias/enum/method + arrow & function-expr bindings).
- **New lanes (10):** `kotlin` (function/class/object/property — the jvm row of the Step-2 manifest table; the docs' own fallback example was literally `kotlin:no_astgrep_pack`), `swift` (function/class[=struct/enum/actor/extension]/protocol/init), `scala` (function_definition + abstract function_declaration/class/object/trait), `c`, `cpp`, `dart` (function_signature/method_signature/class/enum/mixin/extension), `elixir` (def-form calls via target regex — a bare `{kind: call}` matches every call site), `lua`, `bash`, `haskell` (function/signature/data/newtype/class).
- **Deliberately NOT shipped:** `jsx` (alias, above); css/html/json/yaml (not symbol-bearing app languages); fortran keeps the ladder test's live no-pack arm honest.
- `build-symbol-index.sh` EXTS gains the new extensions (membership-only enumeration gate; ast-grep assigns each file's language by its own ext mapping).

## Proof on the trigger repo

Post-fix, read-only against `training-nextjs`: probe digest routes `tsx` (and `jsx`) into `astgrep_langs` with `fallbacks: []`, and the tsx pack extracts **350 symbols at AST tier** from the same `.tsx` files that were regex-tier in the operator's scan.

## Round disclosure (dual-blind, 2026-08-03 — written after the round, all findings folded pre-ship)

Two blind reviewers (code lane with mktemp execution rights vs spec/doc lane), both against ast-grep 0.42.3 live.

**Code lane — the noise class (all fixed with reviewer-verified fix-forms):**
- **SB-1:** `c-struct`/`c-enum` bare kinds matched every USAGE site (params, locals, sizeof — 6 bogus rows per definition in a toy file; orders of magnitude in real C). Fixed: body-guards (`has: field_declaration_list/enumerator_list, field: body`); same guard applied to cpp class/struct/enum (forward-declaration noise).
- **SB-2:** `kotlin-property` fired on every LOCAL `val`/`var` (locals ARE `property_declaration` in tree-sitter-kotlin) — recreating the const-bucket flood at AST tier. Fixed: `not: {inside: {kind: function_body, stopBy: end}}`.
- **SB-3:** Haskell — (a) `function` is ALSO the arrow-TYPE node, so every `a -> b` in a signature minted a match (fixed: `not inside signature`); (b) the generic name regex named every binding after its LAST PARAMETER (`add x y = …` → "y") — fixed in the deriver.
- **IM-1:** Dart `method_signature` WRAPS `function_signature` → every method double-rowed. Fixed: `dart-function` excludes method-wrapped nodes; constructors added.
- **IM-2:** the name deriver was never taught the new languages (typedef→"struct", enum class→"class", scala object→"?", protocol name stolen by its member, lua table-fns collapsed to the module name, out-of-line C++ members named by class). Fixed: per-ruleId branches in `parse_name` (NAME_RE stays the fallback — the original 9 languages byte-identical); end-to-end fixture now yields **0 `name:"?"` rows** across 9 languages.
- **IM-3 (accepted, disclosed):** ast-grep assigns `.h` → C; C++-in-`.h` headers extract poorly. Disclosed in VERSIONS.md + c.yml header; real fix = sgconfig languageGlobs remap (future).
- **IM-4:** Scala 3 `enum_definition`/`given_definition` missed → added. Minors: elixir regex gained `defguard/defguardp/defdelegate`; kotlin gained `companion_object`/`type_alias`; lua assignment-form fns deliberately unmatched (anonymous node = nameless row; disclosed in the pack header).
- Clean under attack: router (all four alias arms), dup guards (.jsx/.tsx/.ts each exactly 1 row), fortran genuinely unsupported (the ladder arm is honest), kind typos hard-fail rule parse.

**Doc lane:**
- **F1–F3 ("doc still asserts the pre-fix world"):** scan-procedure's canonical downgrade example was `kotlin:no_astgrep_pack` (now impossible output) → fortran; VERSIONS.md's own coverage-gaps section contradicted its new glossary table (Kotlin "always regex") → rewritten; tree-sitter-integration still taught "typescript incl. tsx" (the refuted root-cause assumption) + the 9-pack list → rewritten with lane law + alias + the correct `(file, line, ruleId)` dedupe key.
- **F4 (reachability):** 8 of 10 new lanes had no Step-2 manifest detection row, and the tsx/jsx language-KEY derivation was prose-undefined (the exact seam that regressed). Added: Package.swift/pubspec.yaml/mix.exs/build.sbt/cabal/CMake rows + an explicit "language KEYS for the Step-0 probe" contract (keys = ast-grep language ids from manifest rows ∪ per-extension walk; jvm expands to java AND kotlin).
- **F5/F7:** SKILL.md's queries/ router line modernized (astgrep/ packs are the tier-1 content); the stale "Tier-2" label retired from all pack headers + VERSIONS.md.
- **F6/F8 + code-lane test gap:** swift sample gained actor/extension; elixir gained guard/delegate forms; the test header's coverage claim made honest; and a new **exact-set arm** pins (ruleId, line) sets for c/kotlin/haskell/dart/swift — the "fires ≥1" arm alone is structurally blind to the noise class.
- **F9/F10:** registry kind-name precision; CHANGELOG/bump landed with the tranche.

**Recurring-class note:** the noise class (SB-1/SB-2/SB-3a) is a new entry in the catalog — "rule fires on the happy sample" ≠ "rule fires ONLY on definitions". Countermeasure now pinned: exact-set assertions, not existence assertions, for grammar-driven extraction.
