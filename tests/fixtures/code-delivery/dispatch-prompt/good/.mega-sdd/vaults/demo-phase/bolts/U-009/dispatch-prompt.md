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
Design tokens: colors={primary: #3b82f6, secondary: #64748b}; spacing=default; fonts=[Inter]

### Starterkit code patterns (follow these conventions)

- view:
    location:  resources/views/
    naming:    {model}.blade.php
    extension: .blade.php
    _source:   resources/views/dashboard.blade.php:1-50

### Reference code example (from starterkit)

Pattern: view
File:    resources/views/dashboard.blade.php

```blade
@extends('layouts.app')
@section('content')
<div class="container grid grid-cols-1 md:grid-cols-3 gap-4">
  <h1 class="text-2xl font-semibold">{{ $widget->name }}</h1>
  <span>{{ $widget->branch->name }}</span>
</div>
@endsection
```

Follow this style for new view files. Do not deviate from the layout extend,
responsive grid, or relation-resolved label idiom shown above.
