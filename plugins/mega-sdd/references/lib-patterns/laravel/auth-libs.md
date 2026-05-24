# Laravel — Auth Libraries Detection Patterns

> Catalog consumed by `auth-extractor` subagent in `scan-codebase` v2.6.0+ deep-scan.

**Output target:** `starterkit-context.yaml §auth` block (see `references/starterkit-context-schema.md`)

## Coverage

5 Laravel auth libs + `not_detected` fallback:
- Sanctum (API tokens + SPA cookie auth)
- Breeze (lightweight starter)
- Jetstream (Livewire/Inertia-powered starter)
- Fortify (headless auth backend)
- Passport (full OAuth2 server)

---

## Sanctum

**Manifest fingerprint** (`composer.json` `require`):
```json
"laravel/sanctum": "^3.0" OR "^4.0"
```

**File fingerprints:**
- `app/Http/Kernel.php` contains `\Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful`
- `config/sanctum.php` exists
- `routes/api.php` typically has `middleware('auth:sanctum')` groups

**Routes typical:** API-first; web auth absent unless paired with Breeze/Jetstream.

**Sample output YAML slice:**
```yaml
auth:
  lib: sanctum
  lib_version: "4.0"
  guard: sanctum
  user_model: "App\\Models\\User"  # read from config/auth.php providers.users.model
  routes:
    login: "/login"               # only if web routes also present
    register: ""
    logout: "/logout"
    password_reset: ""
  features: []                    # 2fa/social_login only if paired with Fortify/Socialite
  _source: ["composer.json:<line>", "config/sanctum.php", "app/Http/Kernel.php:<line>"]
```

---

## Breeze

**Manifest fingerprint:**
```json
"laravel/breeze": "^2.0"  # dev-time only; check require-dev too
```

**File fingerprints:**
- `routes/auth.php` exists with `Route::middleware('guest')->group(...)` blocks for login/register
- `app/Http/Controllers/Auth/AuthenticatedSessionController.php` exists
- `resources/views/auth/login.blade.php` exists (Blade flavor) OR `resources/js/Pages/Auth/Login.vue|.jsx` (Inertia flavor)

**Routes typical:** `/login`, `/register`, `/logout`, `/forgot-password`, `/reset-password`, `/verify-email`

**Features detection:**
- email_verification: `app/Http/Middleware/EnsureEmailIsVerified.php` exists OR `routes/auth.php` has `verified` middleware
- 2fa: NOT default (use Fortify or Jetstream)
- social_login: NOT default (Breeze adds password auth only)

**Sample output YAML slice:**
```yaml
auth:
  lib: breeze
  lib_version: "2.0"
  guard: web
  user_model: "App\\Models\\User"
  routes:
    login: "/login"
    register: "/register"
    logout: "/logout"
    password_reset: "/forgot-password"
  features: [email_verification]
  _source: ["composer.json:<line>", "routes/auth.php", "app/Http/Controllers/Auth/AuthenticatedSessionController.php"]
```

---

## Jetstream

**Manifest fingerprint:**
```json
"laravel/jetstream": "^5.0"
```

**File fingerprints:**
- `config/jetstream.php` exists
- `app/Actions/Jetstream/` directory exists (Teams actions if teams enabled)
- `resources/views/api/api-token-manager.blade.php` exists (Livewire stack) OR `resources/js/Pages/API/Index.vue` (Inertia stack)

**Features detection (from config/jetstream.php `features` array):**
- `Features::accountDeletion()` → features array includes `account_deletion`
- `Features::api()` → features includes `api_tokens`
- `Features::teams()` → features includes `teams`
- `Features::profilePhotos()` → features includes `profile_photos`

**Sample output YAML slice:**
```yaml
auth:
  lib: jetstream
  lib_version: "5.0"
  guard: web
  user_model: "App\\Models\\User"
  routes:
    login: "/login"
    register: "/register"
    logout: "/logout"
    password_reset: "/forgot-password"
  features: [email_verification, 2fa, api_tokens, teams]
  _source: ["composer.json:<line>", "config/jetstream.php"]
```

---

## Fortify

**Manifest fingerprint:**
```json
"laravel/fortify": "^1.0"
```

**File fingerprints:**
- `config/fortify.php` exists
- `app/Actions/Fortify/` directory exists (CreateNewUser, UpdateUserProfileInformation, etc.)
- `app/Providers/FortifyServiceProvider.php` exists

**Features detection (from config/fortify.php `features` array):**
- `Features::twoFactorAuthentication()` → `2fa`
- `Features::emailVerification()` → `email_verification`
- `Features::updatePasswords()`, `Features::resetPasswords()`, `Features::registration()` → standard auth features

**Sample output YAML slice:**
```yaml
auth:
  lib: fortify
  lib_version: "1.0"
  guard: web
  user_model: "App\\Models\\User"
  routes:
    login: "/login"               # Fortify registers these by default
    register: "/register"
    logout: "/logout"
    password_reset: "/forgot-password"
  features: [email_verification, 2fa]
  _source: ["composer.json:<line>", "config/fortify.php", "app/Providers/FortifyServiceProvider.php"]
```

---

## Passport

**Manifest fingerprint:**
```json
"laravel/passport": "^12.0"
```

**File fingerprints:**
- `config/passport.php` exists
- `app/Models/User.php` uses `Laravel\Passport\HasApiTokens` trait
- `app/Providers/AuthServiceProvider.php` calls `Passport::routes()` or registers Passport scopes

**Sample output YAML slice:**
```yaml
auth:
  lib: passport
  lib_version: "12.0"
  guard: api
  user_model: "App\\Models\\User"
  routes:
    login: "/oauth/token"
    register: ""
    logout: "/oauth/tokens"
    password_reset: ""
  features: [oauth2]
  _source: ["composer.json:<line>", "config/passport.php", "app/Models/User.php:<line>"]
```

---

## not_detected fallback

When NONE of the above match:

```yaml
auth:
  lib: not_detected
  lib_version: ""
  guard: ""                       # may still read default from config/auth.php if exists
  user_model: ""                  # may still read from config/auth.php
  routes: { login: "", register: "", logout: "", password_reset: "" }
  features: []
  _source: ["composer.json"]      # cite the absence
```

Anti-halu: NEVER guess. If no fingerprint matched, emit `not_detected`. Downstream consumers degrade gracefully.

## Detection precedence

Multiple libs may coexist (e.g., Sanctum + Breeze). Detection order matters for the `lib:` enum value:

1. **Jetstream** (most opinionated; if present, dominates)
2. **Breeze** (web-flavored, simpler than Jetstream)
3. **Fortify** (headless; present standalone OR under Jetstream)
4. **Passport** (OAuth2; may coexist with Sanctum for hybrid API auth)
5. **Sanctum** (token/SPA auth)
6. `not_detected` (none of the above)

If multiple match, emit the highest-precedence as `lib:`; list others in `libs:` (Task 3 libs-extractor handles that).
