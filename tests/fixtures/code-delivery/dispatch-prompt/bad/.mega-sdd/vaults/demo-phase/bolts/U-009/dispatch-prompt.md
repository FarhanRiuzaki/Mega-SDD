═══════════════════════════════════════════
BOLT SUBAGENT DISPATCH — U-009
═══════════════════════════════════════════

UNIT: U-009 "Widget detail + index views"
SCOPE: S-2 (Widget management) — framework: laravel-base-26

═══════════════════════════════════════════
TIER 1 — Always read (target ≤2KB)
═══════════════════════════════════════════

## Unit body (verbatim)
---
unit_id: U-009
title: "Widget detail + index views"
module: widget
scope: S-2
starterkit_context_consumed: true
starterkit_relevance: [ui_ux]
target_files:
  - resources/views/widgets/index.blade.php
  - resources/views/widgets/show.blade.php
---

## Goal
Render the widget index + detail views.

## Target files
```
resources/views/widgets/index.blade.php
resources/views/widgets/show.blade.php
```

═══════════════════════════════════════════
TIER 2 — Relevant slice (target ≤5KB)
═══════════════════════════════════════════

### Starterkit context (relevant to this unit)

UI/UX: extends=layouts.app, notification=sweetalert2, idioms=[responsive mobile-first (sm/md/lg); blade-components]

### Starterkit code patterns (follow these conventions)

- controller:
    location:  app/Http/Controllers/
    naming:    {Model}Controller<ext>
    extension: .php
    _source:   app/Http/Controllers/ExampleController.php:1-30

### Reference code example (from starterkit)

Pattern: controller
File:    app/Http/Controllers/ExampleController.php

```php
class ExampleController extends Controller
{
    public function index() { return view('examples.index'); }
}
```

Follow this style for new controller files.
