# extras slice Trigger + Containment Test

Manual-run fixture for the `/mega-sdd-extras:slice` → `mega-sdd-extras:slice-design` lane (plugin `mega-sdd-extras`, spec 2026-09-06). Requires both plugins installed from the same marketplace.

## Trigger cases

### XS1: Figma URL with a node-id (primary lane)
- **Prompt:** `/mega-sdd-extras:slice --figma=https://www.figma.com/design/<fileKey>/App?node-id=12-345`
- **Expect:** skill invocation; announce carries `mega-sdd-trace:slice-design`; `figma-design-to-code` guidance loaded BEFORE the first `get_design_context`; ladder `get_metadata` → per-section `get_design_context` → `get_variable_defs`; report at `.mega-sdd/slices/<slug>/slice-report.md` with the component → file → nodeId table and `tokens: figma variables …`

### XS2: Figma URL WITHOUT a node-id
- **Prompt:** `/mega-sdd-extras:slice --figma=https://www.figma.com/design/<fileKey>/App`
- **Expect:** `get_metadata(fileKey)` lists the pages; ONE `AskUserQuestion` (keterangan per page); then ONE page is sliced — never all of them

### XS3: Batch request
- **Prompt:** `/mega-sdd-extras:slice --figma=<url node A> and also pages B, C, D`
- **Expect:** refusal line "satu page per jalan — jalankan lagi untuk page berikutnya"; slices node A only (or asks which ONE)

### XS4: Image fallback
- **Prompt:** `/mega-sdd-extras:slice --image=./design/dashboard.png`
- **Expect:** skill invocation; image read directly; ≤3 clarifying questions with keterangan; report carries `tokens: NOT AVAILABLE (image fallback) — values inferred`

### XS5: No reference argument
- **Prompt:** `/mega-sdd-extras:slice`
- **Expect:** ONE ask for a reference (figma URL / image / web URL) with keterangan — then proceeds

## Containment cases (MUST NOT auto-route)

### XS6: Free-text slicing request (Indonesian)
- **Prompt:** `tolong slicing figma ini jadi komponen React`
- **Expect:** NO automatic slice-design invocation — no census keyword; normal assistant behavior (it MAY mention `/mega-sdd-extras:slice` as an offer, never silently invoke)

### XS7: Free-text slicing request (English)
- **Prompt:** `please slice this design into components`
- **Expect:** NO automatic invocation (same rule as XS6)

### XS8: Bound project — pipeline state untouched
- **Setup:** project with a BOUND vault
- **Prompt:** `/mega-sdd-extras:slice --image=./ref.png`
- **Expect:** skill invocation; vault `design_system` MAY be read as enrichment; NOTHING under `<vault>/` or any gate-state file is written; only `.mega-sdd/slices/<slug>/` appears

### XS9: No dev server
- **Setup:** `preview_url` unset or unreachable
- **Prompt:** `/mega-sdd-extras:slice --figma=<url with node-id>`
- **Expect:** code generated; compare rounds = 0; report literally states the render was NOT verified; the skill does NOT start any server

### XS10: Core plugin not installed
- **Setup:** `mega-sdd` absent from `installed_plugins.json`
- **Prompt:** `/mega-sdd-extras:slice --figma=<url with node-id>`
- **Expect:** skill still runs; report carries `core corpus: NOT READ (<reason>)`; no halt
