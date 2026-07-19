# /mega-sdd:emit-prd Trigger + Behavior Test

P5 — PRD emitter on the shared emission engine (`--doc=prd`): forward (vault → PRD) + REVERSE (KB, no vault → marker-preserving PRD draft). Marker preservation is deterministic (`scripts/check-prd-markers.sh`).

## Trigger cases

### EP1: Reverse mode from a knowledge base
- **Setup:** `.mega-sdd/knowledge-base/` exists (extract-intelligence ran); NO vault
- **Prompt:** `/mega-sdd:emit-prd` (or "buat PRD dari knowledge base" / "reverse PRD")
- **Expect:** mode=reverse announced; PRD.md at `<project>/.mega-sdd/prd/`; every KB-derived claim line carries its `[VERIFIED]/[INFERRED]/[OPEN]` marker VERBATIM + KB citation; marker legend emitted at top

### EP2: Marker stripped → deterministic halt
- **Setup:** emitted PRD line cites `knowledge-base/…:L<n>` whose KB line is `[INFERRED]` but the PRD line lost the marker (or claims `[VERIFIED]`)
- **Expect:** Step 4.7 `check-prd-markers.sh` exits 1 (`MARKER_STRIPPED`/`MARKER_UPGRADED` + keterangan); halt `quality_gate_failed:marker_stripped`; NEVER shipped — an inferred claim may not be presented as fact

### EP3: Forward mode from a vault
- **Setup:** vault present (any binding/units state)
- **Prompt:** "generate PRD"
- **Expect:** mode=forward; sections from vault sources (01-overview, 02-functional, 04-flows, 03-open-questions); missing source → `[Pending — X not yet generated]`

### EP4: User journeys are Mermaid
- **Setup:** vault flows / KB workflows with Mermaid bodies
- **Expect:** §4 journeys carry source diagrams VERBATIM; a KB workflow without a diagram gets a NEW Mermaid drawn strictly from its recorded steps (cited); no prose-only or ASCII journey ever

### EP5: Open Items are read-only
- **Setup:** unresolved OQs exist
- **Expect:** §6 lists them as a view; the skill NEVER prompts to resolve them (docs are outputs — resolution stays in resolve-oq / generate-intent Q&A)

### EP6: Maturity rungs are human-gated
- **Expect:** Step 6 stamps `draft-from-legacy` via `refresh-doc-stamps.sh`; the model NEVER stamps `reviewed`/`final` on its own — those bumps happen only on the user's explicit word

### EP7: Reverse lane is a mention, never auto-chained
- **Setup:** chain/routing sees `knowledge_base: present` + no vault
- **Expect:** routing MENTIONS `/mega-sdd:emit-prd` (one line); the proposed pipeline chain stays `generate-intent --kb=<kb>`

## Pass criteria

All EP1–EP7 per `skills/emit-prd/SKILL.md` Procedure. Citations script-stamped (`--doc=prd`); markers preserved verbatim end-to-end.

## Anti-halu rail verification

- Marker preservation enforced by `check-prd-markers.sh` (exit 1 = halt), not by prose
- Missing source → `[Pending — X]`, never fabricated content
- Quoted terse notation rides in code spans with Indonesian gloss — never translated in place (decision 4); fenced content is not a claim surface
- sha256 stamps script-computed; the model writes only `(sha256: pending)`
