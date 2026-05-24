# Laravel — UI/UX Libraries Detection Patterns

> Catalog consumed by `ui-ux-extractor` subagent in `scan-codebase` v2.6.0+ deep-scan.

**Output target:** `starterkit-context.yaml §ui_ux` block

## Coverage: 5 categories

1. JS framework: Alpine / Livewire / Inertia / Vue / React / none
2. CSS framework: Tailwind / Bootstrap / Bulma / custom / none
3. Notification lib: SweetAlert2 / Toastr / native / not_detected
4. Icon lib: Heroicons / FontAwesome / not_detected
5. DataTable lib: yajra/laravel-datatables / not_detected

---

## JS framework detection

### Alpine

**Manifest fingerprint** (`package.json` dependencies/devDependencies):
```json
"alpinejs": "^3.0"
```

**File fingerprints:**
- `resources/js/app.js` contains `import Alpine from 'alpinejs'` OR `Alpine.start()`
- Blade views use `x-data`, `x-show`, `x-on:` directives

### Livewire

**Manifest fingerprint:**
```json
"livewire/livewire": "^3.0"
```

**File fingerprints:**
- `app/Livewire/` directory exists (v3) OR `app/Http/Livewire/` (v2)
- Blade views use `<livewire:component-name />` syntax OR `@livewire('...')`

### Inertia

**Manifest fingerprint:**
```json
"inertiajs/inertia-laravel": "^1.0"   // composer.json
"@inertiajs/vue3": "..."              // package.json (Vue flavor)
"@inertiajs/react": "..."             // package.json (React flavor)
```

**File fingerprints:**
- `resources/js/Pages/` directory exists
- `app/Http/Middleware/HandleInertiaRequests.php` exists

### Vue (standalone)

**Manifest fingerprint:**
```json
"vue": "^3.0"
```

**File fingerprints:**
- `resources/js/app.js` imports `createApp` from `vue`
- `resources/js/components/*.vue` files exist

### React (standalone)

**Manifest fingerprint:**
```json
"react": "^18.0", "react-dom": "..."
```

**File fingerprints:**
- `resources/js/app.jsx` or `resources/js/app.tsx` exists

### none

If `resources/js/app.js` is empty/missing or only contains Bootstrap import without JS framework: `js_framework: none`.

---

## CSS framework detection

### Tailwind

**Manifest fingerprint:**
```json
"tailwindcss": "^3.0" OR "^4.0"
```

**File fingerprints:**
- `tailwind.config.js` exists
- `resources/css/app.css` has `@tailwind base; @tailwind components; @tailwind utilities;`

**Design tokens** — parse `tailwind.config.js`:
- `theme.extend.colors` → populate `design_tokens.colors` (subset: primary, secondary, accent, danger, success, warning)
- `theme.extend.spacing` → if customized, populate `design_tokens.spacing`; else `default`
- `theme.extend.fontFamily` → populate `design_tokens.fonts`

### Bootstrap

**Manifest fingerprint:**
```json
"bootstrap": "^5.0"
```

**File fingerprints:**
- `resources/sass/app.scss` imports `~bootstrap/scss/bootstrap`
- `resources/js/bootstrap.js` exists (Laravel convention)

### Bulma / custom / none

- Bulma: `bulma` in package.json → `css_framework: bulma`
- Custom: only `app.css` exists with no framework imports → `css_framework: custom`
- None: no CSS framework signals → `css_framework: none`

---

## Notification lib detection

### SweetAlert2

**Manifest fingerprint** (package.json):
```json
"sweetalert2": "^11.0"
```

**File fingerprints:**
- `resources/js/app.js` imports `Swal from 'sweetalert2'` OR `import 'sweetalert2/dist/sweetalert2.min.css'`
- Blade views use `Swal.fire(...)` OR `<x-sweetalert />` component
- Notification component at `resources/views/components/notification.blade.php` or similar

### Toastr

**Manifest fingerprint:**
```json
"toastr": "^2.0"
```

### native (Laravel session flash + Blade)

Detection: `@if(session('success'))` patterns in Blade layouts without third-party notification lib.

### not_detected

When no notification lib is found.

---

## Icon lib detection

### Heroicons

**Manifest fingerprint:**
```json
"@heroicons/vue": "..." OR "@heroicons/react": "..." OR
```
Composer:
```json
"blade-ui-kit/blade-heroicons": "^2.0"
```

### FontAwesome

**Manifest fingerprint:**
```json
"@fortawesome/fontawesome-free": "..."
```

### not_detected

When no icon lib is found.

---

## DataTable lib detection

### yajra/laravel-datatables

**Manifest fingerprint:**
```json
"yajra/laravel-datatables-oracle": "^11.0"
```

**File fingerprints:**
- `app/DataTables/*.php` files extending `Yajra\DataTables\Services\DataTable`
- Base class often `BaseDataTable` at `app/DataTables/BaseDataTable.php` (per laravel-base-26 pack)

### not_detected

When no DataTable lib is found.

---

## Layout file detection

Inspect `resources/views/layouts/`:
- If `app.blade.php` exists → `layout_extends: "layouts.app"`, `layout_file: "resources/views/layouts/app.blade.php"`
- If `master.blade.php` exists → `layout_extends: "layouts.master"`, `layout_file: "resources/views/layouts/master.blade.php"`
- If `main.blade.php` exists → `layout_extends: "layouts.main"`, `layout_file: "resources/views/layouts/main.blade.php"`
- If multiple → pick the one most-extended by views in `resources/views/` (grep for `@extends('layouts.X')` counts)
- If none → `layout_extends: ""`, `layout_file: ""`

## Component dir detection

- `resources/views/components/` (Blade Components convention) → `component_dir: "resources/views/components"`
- `resources/js/Components/` (Inertia convention) → `component_dir: "resources/js/Components"`
- Multiple may coexist; pick the dominant one (more files = dominant)

## Idioms inference

Parse `resources/js/app.js`, `resources/views/layouts/<layout>.blade.php` for recurring patterns:
- `document.addEventListener('DOMContentLoaded', ...)` usage → idiom: "use document.addEventListener('DOMContentLoaded', ...) over $(document).ready"
- Tailwind responsive prefixes (`sm:`, `md:`, `lg:`) used heavily → idiom: "responsive mobile-first (sm/md/lg breakpoints)"
- `$(document).ready(...)` usage → idiom: "uses jQuery ready (legacy pattern)"

Emit only idioms that have ≥3 occurrences in scanned files. No guessing.

---

## Sample full §ui_ux output

```yaml
ui_ux:
  js_framework: alpine
  css_framework: tailwind
  layout_extends: "layouts.app"
  layout_file: "resources/views/layouts/app.blade.php"
  component_dir: "resources/views/components"
  notification_lib: sweetalert2
  icon_lib: heroicons
  datatable_lib: yajra/laravel-datatables
  design_tokens:
    colors: { primary: "#3b82f6", secondary: "#64748b" }
    spacing: default
    fonts: ["Inter"]
  idioms:
    - "use document.addEventListener('DOMContentLoaded', ...) over $(document).ready"
    - "responsive mobile-first (sm/md/lg breakpoints)"
  _source: ["package.json:<line>", "tailwind.config.js", "resources/views/layouts/app.blade.php", "resources/js/app.js"]
```

## Anti-halu

- Idioms array MUST be empirically grounded (≥3 occurrences). Never guess "uses X pattern" without evidence.
- `not_detected` is a valid value for notification_lib, icon_lib, datatable_lib. Never invent.
- design_tokens only populated if `tailwind.config.js` has explicit `extend.colors` / `extend.spacing` / `extend.fontFamily` blocks; else use `default`.
