# Property-Based Testing Integration

Optional unit-level extension. Per Anthropic NeurIPS 2025 paper "Property-Based Testing with Claude" — PBT catches 30-32% of partial-correctness gaps that example-tests miss.

Mega-sdd extends unit schema with `properties:` array alongside existing `acceptance_test:`. Each property = invariant statement. Generate-units emits PBT-style test stubs in the target language WHEN a PBT framework is detected; skip silently otherwise (anti-halu: never fabricate test infrastructure).

## Contents
- Schema extension
- Required fields per property
- Framework detection (auto)
- Emission example — PHP/Eris
- Emission example — TypeScript/fast-check
- Execute-bolts integration
- Properties vs acceptance_test — when to use which
- Multi-language story (open question)
- Anti-halu rails (mandatory)
- Backward compatibility
- References

## Schema extension

```yaml
---
id: U-001
title: Validate user nip + nama + password on login
task_type: extend
target_files: [...]
acceptance_test:                       # existing
  - type: test
    command: ./vendor/bin/phpunit --filter=LoginExtensionTest
    expects: ""                        # empty = exit-0 criterion (the matcher: rc==0 AND (expects empty OR literal substring in output))

# OPTIONAL property-based invariants
properties:
  - id: PROP-001
    description: For any valid nip+nama+password triple, login() is idempotent
    invariant: "login(nip, nama, password) == login(nip, nama, password)"
    cites: flows.md#F-U-001-login
    severity: error                    # error | warning
  - id: PROP-002
    description: nama is case-insensitive
    invariant: "login(nip, 'Budi', pw) == login(nip, 'BUDI', pw) == login(nip, 'budi', pw)"
    cites: flows.md#F-U-001-login + KB §security-nama-comparison
    severity: error
  - id: PROP-003
    description: Login response time < 200ms for valid input
    invariant: "duration(login(valid_input)) < 200ms"
    cites: constitution.md §E-001
    severity: warning
---
```

## Required fields per property

| Field | Required | Description |
|---|---|---|
| `id` | yes | PROP-NNN sequential within unit |
| `description` | yes | 1-sentence prose |
| `invariant` | yes | Pseudo-code or formal statement of what holds true for ALL valid inputs |
| `cites` | yes (anti-halu rail) | Vault file:section OR entity reference; properties without citations rejected (render-pass 12.5.h, model-executed) |
| `severity` | yes | `error` (PBT failure halts bolt) or `warning` (failure logged, bolt continues) |

## Framework detection (auto)

At `generate-units` time, probe codebase for PBT framework presence:

| Language | Framework | Detection |
|---|---|---|
| PHP | Eris | `composer.json` has `giorgiosironi/eris` |
| TypeScript/JS | fast-check | `package.json` has `fast-check` |
| Python | Hypothesis | `requirements.txt` / `pyproject.toml` has `hypothesis` |
| Go | gopter | `go.mod` has `leanovate/gopter` |
| Rust | proptest | `Cargo.toml` has `proptest` |
| Ruby | rantly OR pbt | `Gemfile` has either |

**Detected**: generate-units emits PBT test stubs in language-specific syntax. Tests added to unit's `target_files` (new file: `tests/Property/<UnitName>Test.<ext>`).

**Not detected**: generate-units emits `## Properties (advisory)` section in unit body — properties documented but NOT translated to test code. User installs PBT framework + re-runs OR keeps as documentation-only.

**Anti-halu rail**: NEVER inject `composer require eris` etc. into project. Framework installation is user's call.

## Emission example — PHP/Eris

For PROP-002 (case-insensitive nama):

```php
// tests/Property/LoginExtensionPropertyTest.php
use Eris\TestTrait;
use Eris\Generator;

class LoginExtensionPropertyTest extends TestCase
{
    use TestTrait;

    /**
     * @property PROP-002: nama is case-insensitive
     * Cites: flows.md#F-U-001-login + KB §security-nama-comparison
     */
    public function testNamaCaseInsensitive()
    {
        $this->forAll(
            Generator\nat(),                            // nip
            Generator\elements(['Budi', 'Andi', 'Siti']),  // valid names
            Generator\string()                          // password
        )->then(function ($nip, $nama, $password) {
            $user = User::factory()->create(['nip' => $nip, 'nama' => $nama, 'password' => Hash::make($password)]);

            $resp1 = $this->postJson('/api/login', ['nip' => $nip, 'nama' => strtoupper($nama), 'password' => $password]);
            $resp2 = $this->postJson('/api/login', ['nip' => $nip, 'nama' => strtolower($nama), 'password' => $password]);
            $resp3 = $this->postJson('/api/login', ['nip' => $nip, 'nama' => $nama, 'password' => $password]);

            $this->assertEquals($resp1->status(), $resp2->status());
            $this->assertEquals($resp2->status(), $resp3->status());
        });
    }
}
```

## Emission example — TypeScript/fast-check

```typescript
import * as fc from 'fast-check';

describe('Login - PBT properties', () => {
  /**
   * PROP-001: login() is idempotent
   * Cites: flows.md#F-U-001-login
   */
  it('idempotent for valid input', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 99999 }),    // nip
        fc.string(),                            // nama
        fc.string(),                            // password
        (nip, nama, password) => {
          const result1 = login(nip, nama, password);
          const result2 = login(nip, nama, password);
          expect(result1).toEqual(result2);
        }
      ),
      { numRuns: 100 }
    );
  });
});
```

## Execute-bolts integration

Pre/post-flight scan extension: when unit has `properties:`:

1. Pre-flight: validate `cites` field actually resolves to vault section / entity / constitution
2. Execution: run PBT tests as part of acceptance_test phase (added via target_files automatically)
3. Post-flight: PBT failures with `severity: error` → halt `pbt_property_violated`; failures with `severity: warning` → log + commit anyway

```yaml
blocker:
  type: pbt_property_violated
  details:
    unit_id: U-001
    violated_property: PROP-002
    counterexample:
      nip: 12345
      nama: "Müller"     # PBT found unicode case-folding edge case
      password: "secret"
    expected: case-insensitive match
    actual: response codes differ for 'müller' vs 'Müller'
  next_action: "Property violated. Either fix code OR adjust property OR add explicit edge-case handling. See bolt-report.md for full counterexample."
```

## Properties vs acceptance_test — when to use which

| Aspect | acceptance_test | properties |
|---|---|---|
| Coverage | Specific scenarios (examples) | Universal invariants (all valid inputs) |
| Speed | Fast (handful of test cases) | Slower (100+ random cases per run) |
| Bug discovery | Catches what you predict | Catches edge cases you didn't predict |
| Anti-halu | High (concrete inputs) | High when citations enforced |
| Required | Yes (always) | No (opt-in) |

Use BOTH. Examples define the happy paths; properties stress-test invariants across input space.

## Multi-language story (open question)

PBT support varies across languages.

| Language | Maturity | Mega-sdd support |
|---|---|---|
| Python (Hypothesis) | ⭐⭐⭐⭐⭐ excellent | Full emission |
| TypeScript/JS (fast-check) | ⭐⭐⭐⭐⭐ excellent | Full emission |
| Go (gopter) | ⭐⭐⭐⭐ good | Full emission |
| Rust (proptest) | ⭐⭐⭐⭐ good | Full emission |
| PHP (Eris) | ⭐⭐⭐ ok | Emission with caveats |
| Ruby (Rantly) | ⭐⭐ limited | Skip emission; document properties only |
| Other languages | varies | Skip emission; document properties only |

Anti-halu: when emission isn't supported for language, properties stay in unit body as `## Properties (advisory)` documentation. User maintains; framework usage is voluntary.

## Anti-halu rails (mandatory)

- **Citations enforced**: every property MUST `cites` vault section / entity / constitution clause. Properties without citations are REJECTED by render-pass check 12.5.h (model-executed rule, per validation-passes.md — no deterministic validator; the B1 postflight cite-check is the bolt-side backstop).
- **No framework auto-install**: skill never modifies `composer.json` / `package.json` / etc. Framework presence is user's responsibility.
- **Counterexamples preserved**: PBT failures emit counterexample JSON in halt YAML for user debugging.
- **Severity is binary**: `error` halts; `warning` doesn't. No nuanced levels (avoid analysis paralysis).
- **Skippable**: `--no-pbt` flag on execute-bolts disables PBT validation (preserves pre-v2.5 behavior).

## Backward compatibility

- v3.10 units without `properties:` field → execute-bolts treats as v2.4 (just acceptance_test); no behavior change
- Existing acceptance_test mechanism unchanged
- PBT-emitted test files use `tests/Property/` convention; doesn't conflict with existing test directories
- `--no-pbt` flag preserves pre-v2.5 behavior

## References

- Anthropic NeurIPS 2025 paper "Property-Based Testing with Claude" — research validation
- Hypothesis (Python): https://hypothesis.readthedocs.io/
- fast-check (TS/JS): https://github.com/dubzzz/fast-check
- gopter (Go): https://github.com/leanovate/gopter
- proptest (Rust): https://github.com/proptest-rs/proptest
- Eris (PHP): https://github.com/giorgiosironi/eris
