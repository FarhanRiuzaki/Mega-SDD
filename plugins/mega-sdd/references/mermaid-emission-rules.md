# Mermaid Emission Rules — KB Flow + State-Machine

> Anti-hallucination + parser-safety contract for any skill that emits Mermaid diagrams into KB output (`extract-intelligence` §3 Flow / §8 State Machine, `generate-intent` vault §3 Flow, any future flow-emitting skill).
>
> **Introduced:** v3.64.0 (Iter 72) — driven by TF Import production run that emitted parser-failing Mermaid (`PRE([LC has flag_amend IN (2.2, 4)])` — unquoted `(2.2, 4)` broke node spec).

---

## Contents

- Why this exists
- Rule 1 — Always wrap node text in double quotes
- Rule 2 — Newline in node text = `<br/>`, NEVER a literal line break
- Rule 3 — Escape special characters inside quoted text
- Rule 4 — Edge labels follow the same quoting discipline
- Rule 5 — Avoid raw code expressions in node text; paraphrase
- Rule 6 — `classDef` and `style` go at end of block; verify spelling
- Reference patterns — known-good examples
- Anti-pattern catalog (validator-detected)
- Cross-references
- Deferred to Iter 73+ (Fork-B-future candidates)

## Why this exists

Mermaid is the canonical diagram format for mega-sdd KB outputs. Skills that emit Mermaid are responsible for producing **parser-valid** syntax. The historical failure mode: model writes natural-language node text (often verbatim from legacy code references), Mermaid parser hits an unquoted comma / parenthesis / colon inside `[...]` shape, fails to render. Downstream consumers (PDF, vault, generate-intent) see a fenced ` ```mermaid ` block that LOOKS valid but renders as an error message. `validate-kb-flows.sh` v1 (pre-Iter 72) only checked fence presence; it did not parse syntax.

This document is the producer-side contract. `validate-kb-flows.sh` v2 enforces a subset of these rules at the validator layer.

---

## Rule 1 — Always wrap node text in double quotes

Regardless of shape — `[...]`, `(...)`, `{...}`, `[(...)]`, `[[...]]`, `[\...\]`, `[(...)]`. Default to quoted text. The quote is part of the Mermaid spec for any text containing special characters; defaulting to "always quote" eliminates the per-case judgment.

| ❌ Wrong | ✅ Right |
|---|---|
| `PRE([LC has flag_amend IN (2.2, 4)])` | `PRE(["LC has flag_amend IN (2.2, 4)"])` |
| `A[Reverse Amend Maker]` | `A["Reverse Amend Maker"]` |
| `D{Has amend?}` | `D{"Has amend?"}` |
| `S1((Idle))` | `S1(("Idle"))` |

The `(2.2, 4)` in the TF Import example is the exact failure shape: comma + parens inside `[...]` without surrounding quotes confuses the Mermaid lexer.

## Rule 2 — Newline in node text = `<br/>`, NEVER a literal line break

Mermaid does not parse literal `\n` or actual newlines inside node text reliably. Multi-line node text MUST use `<br/>` for line breaks.

| ❌ Wrong | ✅ Right |
|---|---|
| `M1["Reverse Amend Maker\ninput/import_reverse_amends.php"]` | `M1["Reverse Amend Maker<br/>input/import_reverse_amends.php"]` |
| `M1["line1`<br>(actual newline)`line2"]` | `M1["line1<br/>line2"]` |

## Rule 3 — Escape special characters inside quoted text

If the text content itself contains characters Mermaid would interpret structurally, HTML-escape them:

| Char in text | Escape |
|---|---|
| `"` (double-quote within text) | `&quot;` (HTML entity) or `#quot;` (Mermaid-native) |
| `<` | `&lt;` |
| `>` | `&gt;` |
| `&` | `&amp;` |

Backticks for inline code-like text are fine and recommended: `A["call \`amendFlag()\`"]`.

| ❌ Wrong | ✅ Right |
|---|---|
| `A["he said "hi""]` | `A["he said &quot;hi&quot;"]` |
| `A["x < y && z > 0"]` | `A["x &lt; y &amp;&amp; z &gt; 0"]` |

## Rule 4 — Edge labels follow the same quoting discipline

Edge label syntax `A --|label|--> B` or `A -- "label" --> B`. If the label contains parens, commas, colons, or other special chars, wrap in double quotes.

| ❌ Wrong | ✅ Right |
|---|---|
| `A -- if (x > 0) --> B` | `A -- "if (x > 0)" --> B` |
| `A -->|step 1: validate| B` | `A -->|"step 1: validate"| B` |

## Rule 5 — Avoid raw code expressions in node text; paraphrase

Even with quoting, raw code expressions inside diagrams are hostile to readers and brittle. Paraphrase to natural language abstractions where possible.

| ⚠ Brittle (works but bad) | ✅ Better |
|---|---|
| `PRE(["IN (2.2, 4)"])` | `PRE(["amend flag in (2.2 OR 4)"])` |
| `D{"if x == NULL && y > 0"}` | `D{"x is null AND y positive"}` |

Fewer special chars = fewer ways for a future reader (or downstream renderer) to mis-handle the diagram.

## Rule 6 — `classDef` and `style` go at end of block; verify spelling

Mermaid styling directives are valid Mermaid syntax but easy to typo. Place them AFTER all nodes and edges (at the bottom of the `flowchart` block) and verify spelling against the [Mermaid Style spec](https://mermaid.js.org/syntax/flowchart.html#styling-and-classes).

Common typos:

| ❌ Wrong | ✅ Right |
|---|---|
| `style A stroke-dash-array:5` | `style A stroke-dasharray:5` |
| `style A fill:red` (no quotes for color word) | `style A fill:#ff0000` (hex or `style A fill:red` is OK; both valid) |
| `classDef important: fill:red` (colon after name) | `classDef important fill:red` (no colon between class name and props) |

---

## Reference patterns — known-good examples

### Pattern A — Sequential flow (extract-intelligence §3 Flow)

```mermaid
flowchart TD
    Start(["LC import received"]) --> Validate{"Has amend flag?"}
    Validate -- "yes" --> Amend["Reverse Amend Maker<br/>input/import_reverse_amends.php"]
    Validate -- "no" --> Skip(["No amend processing"])
    Amend --> Persist[("Save to amend_log table")]
    Persist --> End(["End"])
```

### Pattern B — State machine (extract-intelligence §8 State Machine)

```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Submitted: "user submits"
    Submitted --> Approved: "approver clicks approve"
    Submitted --> Rejected: "approver clicks reject"
    Approved --> [*]
    Rejected --> Draft: "user edits"
```

State-machine syntax uses `:` for transition labels — wrap label in double-quotes if it contains commas/parens/special chars.

### Pattern C — Decision with multiple branches

```mermaid
flowchart LR
    Input(["Document received"]) --> Type{"Document type?"}
    Type -- "LC" --> LCFlow["Process LC<br/>(see §3.1)"]
    Type -- "BG" --> BGFlow["Process BG<br/>(see §3.2)"]
    Type -- "other" --> Reject(["Reject: unsupported type"])
```

---

## Anti-pattern catalog (validator-detected)

`validate-kb-flows.sh` v2 (Iter 72+) detects these heuristic anti-patterns:

| Anti-pattern | Detection regex (approximate) | Failure mode |
|---|---|---|
| Unquoted text with special chars inside shape | `[A-Z_][A-Z0-9_]*[(\[{][^"]*[(),:|][^"]*[)\]}]` | Mermaid lexer fails on the special char |
| Literal `\n` in node text | `[(\["][^"]*\\n[^"]*[)\]"]` | Mermaid renders `\n` as literal text, not line break |
| Actual newline within `[...]` or `(...)` shape | (multi-line regex within shape) | Parser breaks at end-of-line |
| Multiple unescaped `"` in node text | `["][^"]*["][^"]*["]` between shape brackets | Inner `"` ends the text early |

When detected, the validator emits:
- `halt_type: mermaid_syntax_invalid`
- `line_number`: where the offending node sits
- `node_id`: the leading identifier (e.g., `PRE`)
- `excerpt`: the raw offending line (truncated to ~120 chars)
- `rule_violated`: which Rule above (1, 2, 3, etc.)
- `suggested_fix`: a one-line corrective rewrite

Tier classification: **C2** (producer must fix). NOT C1 — auto-rewriting Mermaid would risk semantic change (e.g., paraphrasing a condition incorrectly). Producer-side responsibility.

---

## Cross-references

- Producer skills: `plugins/mega-sdd/skills/extract-intelligence/SKILL.md` §3 Flow + §8 State Machine emission steps
- Producer skills: `plugins/mega-sdd/skills/generate-intent/SKILL.md` §Flow vault file emission
- Validator: `plugins/mega-sdd/scripts/validate-kb-flows.sh` (Iter 72+ heuristic syntax checks)
- KB schema: `plugins/mega-sdd/skills/extract-intelligence/references/knowledge-base-schema.md` §3 Flow + §8 State Machine

## Deferred to Iter 73+ (Fork-B-future candidates)

- **v2 full-parser via `mmdc`**: invoke `npx -y @mermaid-js/mermaid-cli` to render each block to `/tmp/`, capture stderr for ground-truth syntax errors. Tradeoff vs heuristic: catches all real issues but adds npx/node dependency, slow first-invocation, offline-flaky. Decision: defer unless heuristic v1 misses ≥3 real failures in soak window.
- **Auto-fix for the most common pattern** (unquoted shape text): risk-graded fix tool that adds quotes only when text is unambiguous (no nested quotes, no HTML entities). Opt-in via `--auto-fix` flag.
