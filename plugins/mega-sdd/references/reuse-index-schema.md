# Reuse Index Schema

> Canonical schema for `.mega-sdd/codebase/reuse-index.yaml` — the starterkit's callable API surface, so bolts reuse existing code instead of reinventing it. Sibling to `starterkit-context.yaml`; separately cacheable.

**Produced by:** `scan-codebase` deep-scan `reuse-extractor` (5th slice)
**Consumed by:** `generate-units` (per-unit `reuse_candidates`), `execute-bolts` (bolt reuse-first lookup), `validate-reuse-duplication.sh` (advisory)

## Anti-halu rails
1. Every entry MUST carry `_source: <file:line>`; an entry with no verifiable source is dropped, not emitted.
2. Signatures only — NEVER store a function body (bounds size; avoids stale-copy drift).
3. `purpose_confidence: inferred` marks any purpose not backed by a docblock.
4. Absence is omission, never a fabricated entry.
5. Per-category cap (default 300) with `truncated.<cat>: true` + overflow note when exceeded.

## Structure

```yaml
schema_version: "1.0"
generated_from: "<git sha or content signature>"
truncated: { helpers: false, model_api: false, services: false, commands: false }

helpers:
  - name: format_currency
    kind: global_helper            # global_helper | util_method
    path: app/Helpers/money.php
    signature: "format_currency(int $amount, string $currency = 'IDR'): string"
    purpose: "Format integer minor-units into a localized currency string"
    purpose_confidence: stated     # stated | inferred
    _source: "app/Helpers/money.php:42-58"

model_api:
  - model: "App\\Models\\User"
    path: app/Models/User.php
    methods: [ "hasRole(string|Role $role): bool   @88" ]
    scopes:  [ "scopeActive(Builder $q): Builder    @120" ]
    traits:  ["HasRoles", "HasAuditLog"]
    _source: "app/Models/User.php"

services:
  - class: "App\\Services\\CreateOrderService"
    path: app/Services/CreateOrderService.php
    entrypoints: [ "handle(OrderData $d): Order   @30" ]
    purpose: "Create an order with stock reservation + invoice"
    purpose_confidence: inferred
    _source: "app/Services/CreateOrderService.php:30-95"

commands:
  - signature: "sync:catalog {--force}"
    class: "App\\Console\\Commands\\SyncCatalog"
    path: app/Console/Commands/SyncCatalog.php
    purpose: "Re-sync product catalog from upstream"
    purpose_confidence: stated
    _source: "app/Console/Commands/SyncCatalog.php"
```
