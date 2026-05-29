# Iter 76 — §patterns + controller code-slice T2 injection

Fixture for logic-proving execute-bolts Step 4.5.b-starterkit.build + .build.code-slice + .inject (v3.67.0+, Iter 76).

## Bug fixed

Pre-Iter-76 regression: scan-codebase v3.0 (Iter 68) produced a `patterns:` block in `starterkit-context.yaml`, but execute-bolts never injected it into T2 — bolt subagents got "follow starterkit conventions" without ever being told what those conventions are. Cross-skill producer/consumer split.

## Fix shape

1. Wire `patterns:` to T2 slice via location-prefix match on `unit.target_files` (location-primary; naming-fallback only when `pattern.location` is null — avoids cross-category false-positives like data_model `{Model}<ext>` greedily matching controller basenames).
2. Walking-skeleton few-shot: embed the FIRST `_source` file of the matched controller pattern verbatim (truncated at 100 lines if >3KB).
3. T2 budget bump: cap_t2 5KB → 10KB; cap_hard 10KB → 12KB (Option A — context reach over tight cap; monitor Iter 77 telemetry).

## Walking-skeleton scope

Iter 76 ships controller category ONLY for code-slice. data_model / request_validator / business_logic / test / schema_migration / route categories are deferred to Iter 77+ pending real-run validation that the controller injection lands cleanly + budget stays manageable.

## Logic-proof scenarios

```bash
# Run inside this directory:
/opt/homebrew/bin/python3.11 simulate-build.py A_match
/opt/homebrew/bin/python3.11 simulate-build.py B_no_match
/opt/homebrew/bin/python3.11 simulate-build.py C_missing_src
```

| Scenario | What it tests | Expected verdict |
|---|---|---|
| A_match | unit `target_files: [app/Http/Controllers/SampleController.php]` matches `patterns.controller.location` → slice.patterns.controller filled AND code_examples.controller filled with ExampleController.php content AND T2.3 render has both sections | **PASS** ✓ |
| B_no_match | unit `target_files: [resources/views/random.blade.php]` matches no pattern.location → slice.patterns empty AND no code patterns/example rendered | **PASS** ✓ (no false-positive injection) |
| C_missing_src | `patterns.controller._source[0]` points to nonexistent file → slice.patterns.controller still filled (metadata preserved) BUT code_examples empty (no halt) | **PASS** ✓ (graceful degradation) |

## Layout

```
project/
├── app/Http/Controllers/ExampleController.php    # the few-shot source
└── .mega-sdd/
    ├── codebase/starterkit-context.yaml          # v3.0 with §patterns block
    └── vaults/test-vault/units/U-001.md          # target_files matches controller location
simulate-build.py                                 # implements algorithm verbatim from SKILL.md
```
