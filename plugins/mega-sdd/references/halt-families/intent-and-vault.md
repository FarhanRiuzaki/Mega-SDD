# Halt guidance — intent-and-vault family

Per-type guidance for halts emitted by: plan · diff-vault · resolve-oq (vault birth + evolution).
Split from the canonical registry `plugins/mega-sdd/references/halt-protocol.md`
(spec 2026-08-17-halt-registry-family-split.md) — the registry keeps the envelope
schema, escalation discipline, subtype enums, and the per-type index that routes
here. Entries are VERBATIM relocations; edit them here, never re-inline them.

### oq_blocker

**`oq_blocker`** — emitted by AI consumers reading the vault non-interactively (per `_meta/ai-consumer-guide.md`, which plan copies in). plan never emits it: a P1 business OQ it leaves open stays `blocking` and its units stay blocked at bolts. The `tag` is the OQ identifier. `priority` is always `P1` (lower priorities don't halt).

### diff_conflict

**`diff_conflict`** — emitted by `diff-vault` Step 5 when a Resolved-OQ conflict or Decision conflict requires stakeholder input. `tag` is the OQ or ADR ID. `priority` is `n/a` (conflicts aren't priority-tagged). `conflict_old`, `conflict_new`, `options` are required.

Registry one-liner (absorbed, same type):

- `diff_conflict` — diff-vault: Resolved-OQ or Decision conflict requires stakeholder input. ALWAYS STOP (user resolves via diff-vault interactive walk). Emitted by `diff-vault`.

### delta_too_large

- `delta_too_large` — diff-vault (`--from-prompt` cap, Step 3): a chat-brief delta exceeds the ticket-scale cap (new entities+flows > 2, changed rows > 12, any new scope, or a major scope shift) — an epic may not masquerade as a delta. ALWAYS STOP; nothing applied, vault untouched. Keterangan: brief ini terlalu besar untuk delta lane — pilih `full_lane` (vault BARU via `plan` — brief ke file → `plan <file>` / `--guarded`, slug / `--vault=` sendiri — atau lane direct/assisted tanpa vault; tidak pernah `plan --regenerate` di vault yang ada), `split_ticket` (pecah jadi beberapa tiket kecil di bawah cap, jalankan delta lane per tiket), atau `cancel` (batal; vault tidak berubah). Emitted by `diff-vault`.

### oq_recommend_citation_invalid

- `oq_recommend_citation_invalid` — plan (`validate-vault-oqs.sh`; KB citations arise under `plan --kb`): OQ recommendation cites non-existent KB section. ALWAYS STOP.

### prd_path_missing

- `prd_path_missing` — diff-vault: `vault.json.prd_path_at_generation` points to non-existent PRD file. ALWAYS STOP. Resolution: user restores the PRD at the recorded path OR regenerates the vault with the current PRD.

### scope_not_declared_in_prd

- `scope_not_declared_in_prd` — plan (`plan --scope=<id>`; the scope-flag PreToolUse gate `validate-scope-flag.sh`): the `--scope=<id>` flag references a scope ID that's not in the PRD's `scopes:` frontmatter block. ALWAYS STOP. Resolution: user picks a valid scope from PRD's declared list OR cancels.

### oq_tech_missing_mode

- `oq_tech_missing_mode` — plan Step 5 (`validate-vault-oqs.sh` on `context.md`): a technical OQ has no `resolution_mode` field (can't classify as `tech / scan` vs `tech / recommend`). ALWAYS STOP. Resolution: add `resolution_mode: scan` or `resolution_mode: recommend` to the `context.md` OQ, then re-run `derive-vault-json.sh` + `validate-vault-oqs.sh --strict-tech` (never `plan --regenerate` — it rewrites `context.md` and every unit). Source skill: `plan`. *(Field grammar is the §Updated OQ schema — `resolution_mode`, not the pre-v-fix `mode`.)*

### oq_scan_missing_query

- `oq_scan_missing_query` — plan Step 5 (`validate-vault-oqs.sh`): an OQ marked `resolution_mode: scan` lacks the `scan_query` that tells plan's tech-OQ probe (manifest / `query-symbol-index.sh` / targeted Read) what to look up. ALWAYS STOP. Details `{oq_id}`. Resolution: add `scan_query: <file-pattern|symbol>` to the OQ entry. Source skill: `plan`.

### oq_tech_undecided

- `oq_tech_undecided` — plan: a `tech` OQ was left `open` or `deferred` in `recommend` / `blocking` mode (layout-3 and greenfield: also `scan` — no bind phase follows) instead of being DECIDED; also raised as an advisory for a resolved tech OQ with no `(AI decision …)` marker (translated / mangled marker). An OQ reaches a human only when the AI cannot answer it (`references/vault-core.md §AI technical decisions`). Hard at the authoring-time gate (`validate-vault-oqs.sh --strict-tech`); a soft advisory under `analyze`, so an existing vault never retro-fails. Details `{oq_id, resolution_mode}`. Resolution: decide it — pick reuse-first (codebase → pack → installed dependency → current docs → simplest option), write `[x]` + `→ **Resolved v<X.Y>** (AI decision, <date>): <pick>` with rationale + citation + `fallback_if_wrong`; if the answer is a FACT no source contains, re-tag it `[business]` with the reason. Source skill: `plan`.

### oq_decided_business_signal

- `oq_decided_business_signal` — plan: an OQ carrying `resolved_by: ai` is not `tech`, or its text / rationale reads as business (scope, limits, money, retention, regulation, edge-case behaviour, `[LOCKED]`) or as a source-vs-code contradiction ("the PRD names X but the repo is Y"). ALWAYS STOP. Details `{oq_id, matched_pattern}`. Resolution: re-open it (`[ ]`), drop the `(AI decision …)` annotation, tag it `[business]` — the stakeholder answers (it joins the batched ask when P1). Never widen the pattern to make it pass. Source skill: `plan`.

### oq_recommend_underspecified

- `oq_recommend_underspecified` — plan (`validate-vault-oqs.sh` on `context.md`): an OQ marked `resolution_mode: recommend` lacks one or more required fields (`recommendation`, `rationale`, `scan_citations` ≥1, `fallback_if_wrong`). ALWAYS STOP. Details `{oq_id, missing_fields}`. Resolution: user fills missing fields in OQ entry per `references/vault-core.md §Updated OQ schema in markdown body`. Source skill: `plan`.
