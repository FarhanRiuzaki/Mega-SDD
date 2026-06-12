# Scenario: binding false-CONFIRMED → advisor → CONFLICT-NNN → gate

A vault claim is marked CONFIRMED against a codebase anchor that does NOT actually match.

**Expected:** the binding phase-advisor emits a `false_confirmed` finding (confidence HIGH) → bind-codebase materializes a canonical `### CONFLICT-NNN` (tagged `source: advisor`) in `binding.md` BEFORE Step 3 → Step 5 decision gate sees `conflict > 0` → does NOT write `<vault>/bound/` → `validate-handoff-binding-units.sh` writes the blocker into `.validation-blockers.json` → execute-bolts PreToolUse hook fails closed.

This is a manual/behavioral scenario (the advisor is an LLM agent — not a deterministic bash assertion). Run it as a field test against a real vault+codebase with a planted false-CONFIRMED.
