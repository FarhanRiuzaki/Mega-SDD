---
framework: dotnet
framework_version_range: ".NET 6+ (LTS 8.x baseline)"
last_verified_against: 2026-06-24
maintainer: mega-sdd
detection_signature:
  package_manifest: "*.csproj"
  dependency_marker: "Microsoft.EntityFrameworkCore"
  version_regex: '<TargetFramework>net(\d+\.\d+)'
extends: _universal
pack_tier: full
---

# .NET Convention Pack (base — non-web C#)

Conventions for general .NET / C# projects (console apps, worker services, class libraries, and EF Core data layers) targeting .NET 6+. Extends `_universal.md` — universal defaults apply, .NET-specific rules override on conflict. The `aspnetcore` pack extends THIS pack with the web layer (controllers, middleware, auth/authz, server/client UI).

> **Detection note**: the base marker is `Microsoft.EntityFrameworkCore` in a `*.csproj` WITHOUT a web SDK (`<Project Sdk="Microsoft.NET.Sdk.Web">`). A web SDK promotes detection to `aspnetcore` (specific-before-generic). This base layer is deliberately ORM-agnostic above the data-access section: the EF Core specifics are quarantined to `## ERD additions` and the data-access idioms, so a non-EF console/worker project still matches cleanly.

## File location standards

| Artifact | Path |
|---|---|
| Solution file | `<Solution>.sln` (repo root) |
| Project file | `src/<Project>/<Project>.csproj` |
| Entry point (console / worker) | `src/<Project>/Program.cs` |
| Domain entities / models | `src/<Project>/Models/` (or `Entities/`, `Domain/`) |
| Service classes | `src/<Project>/Services/` |
| Repositories (when used) | `src/<Project>/Repositories/` |
| Data context (EF Core) | `src/<Project>/Data/` (e.g. `AppDbContext.cs`) |
| EF Core migrations | `src/<Project>/Migrations/` |
| DTOs / records | `src/<Project>/Dtos/` (or `Models/Dtos/`) |
| Strongly-typed options | `src/<Project>/Configuration/` (or `Options/`) |
| App configuration | `src/<Project>/appsettings.json` + `appsettings.{Environment}.json` |
| DI registration helpers | `src/<Project>/Extensions/ServiceCollectionExtensions.cs` |
| Unit + integration tests | `tests/<Project>.Tests/` |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Class / struct / record case | PascalCase | `UserService`, `OrderItem` |
| Method case | PascalCase | `FindById`, `CreateOrder` |
| Async method | PascalCase + `Async` suffix | `GetUserAsync`, `SaveChangesAsync` |
| Interface | `I` + PascalCase | `IUserRepository`, `IClock` |
| Public property | PascalCase | `FirstName`, `CreatedAt` |
| Private instance field | `_camelCase` | `_userRepository`, `_logger` |
| Local variable / parameter | camelCase | `userId`, `cancellationToken` |
| Constant / `static readonly` | PascalCase | `MaxRetryCount`, `DefaultTimeout` |
| Enum type + members | PascalCase | `OrderStatus.Pending` |
| Namespace | PascalCase dot-separated | `Company.Product.Orders` |
| Generic type parameter | `T` + PascalCase | `TEntity`, `TKey` |
| Source file | PascalCase `.cs` matching primary type | `UserService.cs` |
| DB column (EF Core) | matches property PascalCase by default; snake_case only via an explicit naming convention | `CreatedAt` → `created_at` |
| DB table (EF Core) | `DbSet<T>` property name (often pluralized) | `Users`, `OrderItems` |

## Idioms (preferred patterns)

- **Constructor injection over service-locator** — declare dependencies as `private readonly` interface-typed fields set in the constructor; register implementations in `Program.cs` (or a `ServiceCollectionExtensions` method) on `IServiceCollection`. Avoid resolving from `IServiceProvider` inside business code.
- **`async`/`await` for all I/O** — return `Task` / `Task<T>`, suffix the method `Async`, and accept a `CancellationToken` parameter threaded through to the I/O call. Never block on async with `.Result` / `.Wait()` (deadlock + thread-pool starvation).
- **Options pattern for configuration** — bind config sections to POCO option classes via `services.Configure<TOptions>(...)` and inject `IOptions<TOptions>` / `IOptionsSnapshot<TOptions>`; avoid scattering raw `IConfiguration["Key"]` string lookups through the code.
- **`ILogger<T>` for structured logging** — inject `ILogger<T>` and use message templates (`_logger.LogInformation("Created {OrderId}", id)`); never `Console.WriteLine` for diagnostics in library/service code.
- **Nullable reference types enabled** — set `<Nullable>enable</Nullable>` in the project; model optionality in the type system rather than reaching for the `!` null-forgiving operator.
- **Records for immutable data** — model DTOs and value objects as `record` (or `readonly record struct`) for value equality and immutability; reserve mutable `class` for entities and services.
- **Read-only collection types at boundaries** — expose `IReadOnlyList<T>` / `IEnumerable<T>` from public APIs rather than mutable `List<T>`; use LINQ for in-memory projection and filtering.
- **EF Core async query methods** — query via `DbSet<T>` with `ToListAsync` / `FirstOrDefaultAsync` / `SingleOrDefaultAsync`; persist with `SaveChangesAsync`. Manage schema with `dotnet ef migrations add` — never hand-edit a generated migration's `Designer` snapshot.

## Hard Rules emitted

These rules merge into `binding.md` §Suggested Unit Hard Rules when this pack is loaded.

```
HARD_RULE: Interface types MUST be named `I` + PascalCase
  path_glob: src/**/*.cs
  rule_type: NAMING_RULE
  pattern: 'interface\s+I[A-Z]'
  rationale: The I-prefix is the universal .NET signal that distinguishes an abstraction from its implementation; DI registration and mocking conventions assume it

HARD_RULE: Async methods returning Task MUST end with the `Async` suffix
  path_glob: src/**/*.cs
  rule_type: NAMING_RULE
  pattern: 'Async\s*\('
  rationale: The Async suffix is the .NET Framework Design Guideline marker; callers rely on it to spot awaitable members and to avoid sync-over-async blocking

HARD_RULE: Private instance fields MUST use the `_camelCase` form
  path_glob: src/**/*.cs
  rule_type: CUSTOM
  pattern: 'private\s+(readonly\s+)?[\w<>,\[\]\?\. ]+\s+_[a-z]'
  rationale: The underscore prefix disambiguates fields from locals/parameters without `this.` and is the dominant .NET convention; mixed styles break readability and analyzers

HARD_RULE: `Console.WriteLine` MUST NOT be used for logging in library/service code
  path_glob: src/**/Services/**/*.cs
  rule_type: CUSTOM
  forbidden_pattern: 'Console\.WriteLine'
  rationale: Console output bypasses log levels, structured fields, and sinks; inject ILogger<T> so diagnostics are filterable and routable

HARD_RULE: Source files MUST be PascalCase `.cs` matching the primary type they declare
  path_glob: src/**/*.cs
  rule_type: NAMING_RULE
  pattern: '^[A-Z][A-Za-z0-9]*\.cs$'
  rationale: One-public-type-per-file with a matching filename is the .NET project convention; IDE navigation and code generation assume it

HARD_RULE: Project files MUST enable nullable reference types
  path_glob: src/**/*.csproj
  rule_type: SIGNATURE_RULE
  pattern: '<Nullable>enable</Nullable>'
  rationale: Without nullable annotations the compiler cannot surface null-dereference risks, eliminating a whole class of runtime NullReferenceExceptions
```

## Forbidden patterns

- `Console.WriteLine` for diagnostics in service/library code (use `ILogger<T>`)
- Blocking on async via `.Result` / `.Wait()` / `.GetAwaiter().GetResult()` in non-entry code (deadlock + thread starvation)
- `async void` methods other than event handlers (exceptions escape unobservable)
- Raw `IConfiguration["Key"]` lookups scattered through business logic (use the Options pattern)
- `BinaryFormatter` for serialization (removed / unsafe — use `System.Text.Json`)
- `System.Random` for security-sensitive values (use `System.Security.Cryptography.RandomNumberGenerator`)
- Public mutable fields on a type (expose properties instead)
- Hardcoded connection strings or secrets in source / committed `appsettings.json`

## Security idioms

> Consumed by the review-panel `security-reviewer` lens (pack security slice) and by
> `bolt-implementer` via T2 framework-pack rules. Stack-correct, mechanism-named —
> the dangerous bypass is spelled out next to each idiom. Web-only concerns (XSS, CSRF,
> HTTP auth enforcement, file uploads) live in the `aspnetcore` pack that extends this.

- **Input validation** — annotate models/DTOs with DataAnnotations (`[Required]`, `[StringLength]`, `[Range]`) and validate with `Validator.TryValidateObject`, or use FluentValidation; binding external input to an unvalidated object is the gap.
- **SQL injection** — EF Core LINQ queries are parameterized; `FromSqlInterpolated($"... {value}")` parameterizes interpolated values, but `FromSqlRaw("... " + value)` with concatenation is the bypass — never concatenate user input into SQL text.
- **Password hashing** — use a purpose-built KDF (`Rfc2898DeriveBytes` / PBKDF2, or a vetted library); never MD5/SHA1, never store plaintext, never roll your own scheme.
- **Cryptography / randomness** — `System.Security.Cryptography` primitives; `RandomNumberGenerator.GetBytes(...)` for tokens, salts, and nonces — `System.Random` / `Guid` are predictable and must not gate security.
- **Deserialization** — deserialize with `System.Text.Json` to explicit known types; avoid `BinaryFormatter` and unconstrained polymorphic deserialization that can instantiate attacker-chosen types.
- **Mass assignment** — bind request/import data to dedicated DTOs or `record`s and map to entities deliberately; binding directly onto an EF Core entity lets a caller set server-owned columns.
- **Secrets / config** — externalize via environment variables, User Secrets (`dotnet user-secrets`) in development, and a secret store (Azure Key Vault / AWS Secrets Manager) in production; a credential committed in `appsettings.json` is the leak.
- **Path / file handling** — normalize and constrain any path built from external input (`Path.GetFullPath` + a base-directory containment check); using an unsanitized filename to build a path is a traversal vector.

## ERD additions (EF Core)

> Quarantined data-access layer — applies only when the project uses EF Core. Extends
> `_universal.md` §ERD Quality Rails.

- **Keys**: a property named `Id` or `<Entity>Id` is the convention-discovered primary key; configure composite/alternate keys via Fluent API `HasKey` / `HasAlternateKey` in `OnModelCreating`.
- **Relationships**: navigation properties + a shadow or explicit FK property (`CustomerId` for a `Customer Customer` navigation); configure cardinality with `HasOne`/`HasMany`/`WithMany` when convention is ambiguous.
- **Value generation**: `ValueGeneratedOnAdd` (identity) by default for integer keys; `Guid` keys generated client-side or via database default.
- **Audit columns**: `CreatedAt` / `UpdatedAt` maintained via an overridden `SaveChangesAsync` that stamps tracked `Added`/`Modified` entries, or EF Core interceptors.
- **Soft deletes**: an `IsDeleted` flag plus a global query filter (`HasQueryFilter(e => !e.IsDeleted)`) so soft-deleted rows are excluded by default.

## Testing conventions

- Test runner: `dotnet test`
- Test framework: xUnit (`[Fact]` / `[Theory]` + `[InlineData]`) is the .NET default; NUnit (`[Test]`) and MSTest (`[TestMethod]`) are also supported — detect from the test project's package references.
- Test project: `tests/<Project>.Tests/` referencing the project under test; one test project per production project.
- Test class naming: `<TypeUnderTest>Tests` (e.g. `OrderServiceTests`)
- Test method naming: `Method_Scenario_ExpectedResult` (e.g. `FindById_WhenMissing_ReturnsNull`)
- Mocking: Moq or NSubstitute against the injected interfaces
- Assertions: built-in `Assert` or FluentAssertions (`result.Should().Be(...)`)
- EF Core tests: the in-memory provider (`Microsoft.EntityFrameworkCore.InMemory`) for fast unit tests, or SQLite/Testcontainers for behavior that depends on a real relational engine

## Migration / dependency management

- Lock file: `packages.lock.json` (when `RestorePackagesWithLockFile` is enabled)
- Restore: `dotnet restore`
- Add a package: `dotnet add package <Name>`
- Build: `dotnet build`
- EF Core schema: `dotnet ef migrations add <Name>` then `dotnet ef database update`

## Deep-scan file hints

_(N/A: base .NET (console / worker / class library) has no built-in authentication, authorization, or UI. The `aspnetcore` pack that extends this declares those hints.)_

## Authz mapping

_(N/A: base .NET has no built-in authorization framework. Web authorization is declared in the `aspnetcore` pack.)_

## UI detection

_(N/A: base .NET renders no UI. Server/client UI conventions are declared in the `aspnetcore` pack.)_

## Reuse discovery

```yaml
reuse_hints:
  helpers:  [ "src/**/Helpers/**/*.cs", "src/**/Utils/**/*.cs", "src/**/Extensions/**/*.cs" ]
  model_api: [ "src/**/Models/**/*.cs", "src/**/Entities/**/*.cs", "src/**/Domain/**/*.cs" ]
  services: [ "src/**/Services/**/*.cs" ]
  commands: [ "src/**/Commands/**/*.cs", "src/**/Workers/**/*.cs" ]
```

- model_api: public methods and properties on each entity/aggregate; EF Core `DbSet<T>` query extension methods.
- commands: classes implementing `IHostedService` / `BackgroundService` (the `ExecuteAsync` entry point), or CLI command handlers.
