# diff-vault Trigger + Behavior Test

Manual-run fixture for `diff-vault` skill.

## Trigger cases

### DV1: Explicit with new PRD path
- **Prompt:** `/mega-sdd:diff-vault ./new-prd.md`
- **Expect:** Skill invocation; compares against existing vault in CWD

### DV2: Natural English
- **Prompt:** `PRD updated, regenerate vault from new PRD`
- **Expect:** Skill invocation

### DV3: Natural Indonesian
- **Prompt:** `PRD versi baru, update vault dong`
- **Expect:** Skill invocation

### DV4: Auto-route from orchestrate-flow (PRD newer than vault)
- **Setup:** existing vault, `prd.md` mtime newer than `vault.json` mtime
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes diff-vault as first step (overrides other proposals)

## Behavior checks

### B1: Structured diff produced
- Output: `DIFF.md` (or similar) at vault parent dir
- Lists added / changed / removed sections
- Each entry cites old vault line + new PRD section

### B2: Resolved-OQ preservation
- **Setup:** vault has resolved OQ (OQ-001 with stakeholder answer in changelog), new PRD contradicts it
- **Expect:** Skill emits `blocker` (type=`diff_conflict`) — does NOT silently overwrite resolved decision

### B3: ADR vs new PRD conflict surfacing
- **Setup:** vault has ADR explicitly choosing approach X, new PRD suggests approach Y
- **Expect:** Skill emits `blocker` (type=`diff_conflict`), pauses for user resolution

### B4: --auto flag respects blockers
- Even with `--auto`, conflict blockers ALWAYS pause and surface to user
- Logistical prompts (e.g., "apply this addition?") are auto-confirmed

### B5: Vault version bump on apply
- After approved diff: `vault.json` version increments, changelog entry added, OQ identity preserved

## Pass criteria

All trigger cases invoke skill. Conflict blockers surface (never silent), version bump and changelog on apply.
