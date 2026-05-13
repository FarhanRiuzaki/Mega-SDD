# detect-drift Trigger + Behavior Test

Manual-run fixture for `detect-drift` skill.

## Trigger cases

### DD1: Explicit slash command
- **Prompt:** `/mega-sdd:detect-drift`
- **Expect:** Skill invocation; reads `./vault.json` or auto-detects vault dir

### DD2: Natural English
- **Prompt:** `check code vs vault for drift`
- **Expect:** Skill invocation

### DD3: Natural Indonesian
- **Prompt:** `cek code vs vault`
- **Expect:** Skill invocation

### DD4: Auto-route from orchestrate-flow (post-bolt)
- **Setup:** vault exists with mode=existing, bolts/ dir has reports, no recent DRIFT-REPORT.md
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes detect-drift as next step

## Behavior checks

### B1: Mode requirement
- **Setup:** vault.json has `mode: new`
- **Expect:** halt with mode-migration prompt — detect-drift only runs against `mode=existing` vaults

### B2: Output presence
- After invocation against a valid mode=existing vault: `DRIFT-REPORT.md` exists in vault root.

### B3: Confidence-rated findings
- DRIFT-REPORT.md must categorize findings with confidence levels (high/medium/low).
- Each finding cites both the vault claim AND the code evidence (file:line).

### B4: No silent skip
- Even when zero drift detected, DRIFT-REPORT.md is produced with "No drift detected" summary.
- Skill never returns nothing — always writes a report.

### B5: Interactive resolution offered
- After report, skill offers interactive walk-through of findings (or `--auto` skips this).

## Pass criteria

All trigger cases (DD1-DD4) invoke the skill. Behavior checks confirm: mode gate enforced, output always present, confidence-rated, no silent skips.
