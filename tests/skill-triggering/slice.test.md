# slice Trigger + Containment Test

Manual-run fixture for the `/mega-sdd:slice` → `slice-design` lane.

## Trigger cases

### SL1: Explicit command with a URL reference
- **Prompt:** `/mega-sdd:slice --url=https://example.com/pricing`
- **Expect:** `slice-design` skill invocation; capture via Playwright MCP; report at `.mega-sdd/slices/<slug>/slice-report.md`

### SL2: Explicit command with an image
- **Prompt:** `/mega-sdd:slice --image=./design/dashboard.png`
- **Expect:** skill invocation; image read directly; ≤3 clarifying questions with keterangan

### SL3: Explicit command, no reference argument
- **Prompt:** `/mega-sdd:slice`
- **Expect:** skill invocation; ONE ask for a reference (figma export / URL / image) with keterangan — then proceeds

## Containment cases (MUST NOT auto-route)

### SL4: Free-text slicing request (Indonesian)
- **Prompt:** `tolong slicing figma ini jadi komponen React`
- **Expect:** NO automatic slice-design invocation — the census carries no slicing keywords; normal assistant behavior (it MAY mention `/mega-sdd:slice` as an offer, never silently invoke)

### SL5: Free-text slicing request (English)
- **Prompt:** `please slice this design into components`
- **Expect:** NO automatic slice-design invocation (same rule as SL4)

### SL6: Vault-bearing project — slice never touches vault state
- **Setup:** project with a BOUND vault
- **Prompt:** `/mega-sdd:slice --image=./ref.png`
- **Expect:** skill invocation; vault `design_system` MAY be read as enrichment; NOTHING under `<vault>/` is written; no bind/units/bolts state changes

### SL7: No dev server running
- **Setup:** `preview_url` unset or unreachable
- **Prompt:** `/mega-sdd:slice --image=./ref.png`
- **Expect:** code generated; compare rounds = 0; report literally states the render was NOT verified; the skill does NOT start any server
