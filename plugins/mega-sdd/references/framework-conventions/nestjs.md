---
framework: nestjs
framework_version_range: "10.x — 11.x"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: package.json
  dependency_marker: "@nestjs/core"
  version_regex: '"@nestjs/core"\s*:\s*"[\^~]?(\d+)\.'
extends: _universal
pack_tier: full
---

# NestJS Convention Pack (10.x — 11.x)

Conventions for NestJS (Node.js, TypeScript) backend projects. Extends `_universal.md` — universal defaults apply, NestJS-specific rules override on conflict.

NestJS is an opinionated framework built on top of Node.js that uses TypeScript decorators, a module system, and dependency injection (DI) to structure applications in a way that is highly testable and scalable.

## File location standards

| Artifact | Path |
|---|---|
| App entry point | `src/main.ts` |
| Root module | `src/app.module.ts` |
| Feature module | `src/<feature>/<feature>.module.ts` |
| Controller | `src/<feature>/<feature>.controller.ts` |
| Service (provider) | `src/<feature>/<feature>.service.ts` |
| DTO classes | `src/<feature>/dto/<action>-<feature>.dto.ts` |
| Entity (TypeORM) | `src/<feature>/entities/<feature>.entity.ts` |
| Guard | `src/<feature>/guards/<guard-name>.guard.ts` or `src/common/guards/<guard-name>.guard.ts` |
| Interceptor | `src/<feature>/interceptors/` or `src/common/interceptors/` |
| Pipe | `src/<feature>/pipes/` or `src/common/pipes/` |
| Exception filter | `src/<feature>/filters/` or `src/common/filters/` |
| Decorator (custom) | `src/common/decorators/` |
| Config module | `src/config/` (via `@nestjs/config`) |
| Unit tests | Co-located `<file>.spec.ts` next to the source file |
| E2E tests | `test/<feature>.e2e-spec.ts` |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Module class | PascalCase + `Module` suffix | `UsersModule`, `AuthModule` |
| Controller class | PascalCase + `Controller` suffix | `UsersController`, `AuthController` |
| Service class | PascalCase + `Service` suffix | `UsersService`, `JwtAuthService` |
| Guard class | PascalCase + `Guard` suffix | `JwtAuthGuard`, `RolesGuard` |
| Interceptor class | PascalCase + `Interceptor` suffix | `LoggingInterceptor`, `TransformInterceptor` |
| Pipe class | PascalCase + `Pipe` suffix | `ParseIntPipe`, `ValidationPipe` |
| Exception filter class | PascalCase + `Filter` suffix | `HttpExceptionFilter` |
| DTO class | PascalCase + `Dto` suffix | `CreateUserDto`, `UpdateUserDto`, `LoginDto` |
| Entity class | PascalCase (singular) | `User`, `Order` |
| Entity filename | kebab-case + `.entity.ts` | `user.entity.ts`, `order.entity.ts` |
| Custom decorator | camelCase function (for param decorators) or PascalCase constant | `@CurrentUser()`, `Roles` |
| Provider token (custom) | SCREAMING_SNAKE_CASE string or Symbol | `'USER_REPOSITORY'`, `Symbol('CONFIG_OPTIONS')` |
| Route path | kebab-case, plural nouns | `/users`, `/user-profiles`, `/auth/login` |
| Method name | camelCase verb + noun | `findAll`, `findOne`, `create`, `update`, `remove` |
| Test file | co-located `*.spec.ts` (unit) or `test/*.e2e-spec.ts` (e2e) | `users.service.spec.ts` |

## Idioms (preferred patterns)

- **`@Module({})` for feature encapsulation** — every feature has its own module class decorated with `@Module({ imports, controllers, providers, exports })`; the root `AppModule` imports feature modules
- **`@Injectable()` for all providers** — services, guards, interceptors, pipes, and repositories are decorated with `@Injectable()` and registered in the `providers` array of their module
- **Constructor-based dependency injection** — dependencies are injected via the constructor (TypeScript type metadata drives DI): `constructor(private readonly usersService: UsersService) {}`; avoid manual `new` for injected classes
- **`@Controller()` with route decorators** — controllers are thin HTTP adapters; use `@Get()`, `@Post()`, `@Put()`, `@Patch()`, `@Delete()` to bind handler methods to routes; use `@Param()`, `@Body()`, `@Query()` to extract request data
- **DTOs + `ValidationPipe` for input validation** — create a DTO class per action (e.g. `CreateUserDto`, `UpdateUserDto`) annotated with `class-validator` decorators (`@IsString()`, `@IsEmail()`, `@IsNotEmpty()`); apply `ValidationPipe` globally in `main.ts` via `app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }))`
- **`@UseGuards()` for authentication and authorization** — apply guards at the controller or handler level: `@UseGuards(JwtAuthGuard)` for authentication, `@UseGuards(JwtAuthGuard, RolesGuard)` for RBAC; guards implement `CanActivate` from `@nestjs/common`
- **`@nestjs/config` for configuration** — inject `ConfigService` to read environment variables: `this.configService.get<string>('JWT_SECRET')`; never read `process.env` directly in services or controllers; load config in `AppModule` via `ConfigModule.forRoot({ isGlobal: true })`
- **Interceptors for cross-cutting response transforms** — use `@UseInterceptors()` or a global interceptor for response wrapping, logging, and caching; keep controllers free of envelope logic
- **Global pipes, filters, and interceptors in `main.ts`** — register app-wide infrastructure (`ValidationPipe`, `HttpExceptionFilter`) in `main.ts` via `app.useGlobalPipes()` / `app.useGlobalFilters()` / `app.useGlobalInterceptors()`
- **Feature module `exports` for shared providers** — a module that provides a service to other modules must add it to `exports`; a consuming module must add the provider's module to its `imports`; do not rely on global scope for feature services
- **TypeORM via `@nestjs/typeorm`** — define entities with `@Entity()` and TypeORM column decorators; use `@InjectRepository(Entity)` to inject a `Repository<Entity>` in the service constructor; register entities in the feature module via `TypeOrmModule.forFeature([Entity])`

## Hard Rules emitted

```
HARD_RULE: Business logic MUST live in provider/service classes, not in controllers
  path_glob: src/**/*.controller.ts
  rule_type: CUSTOM
  rationale: Controllers are thin HTTP adapters; coupling domain logic to HTTP transport makes it untestable and unportable

HARD_RULE: Input DTOs MUST use class-validator decorators and be processed by ValidationPipe
  path_glob: src/**/dto/*.dto.ts
  rule_type: CUSTOM
  rationale: Unvalidated input DTO allows invalid data into the domain; ValidationPipe strips unknown properties (whitelist) and type-coerces

HARD_RULE: All providers (services, guards, repositories) MUST be decorated with @Injectable()
  path_glob: src/**/*.ts
  rule_type: SIGNATURE_RULE
  pattern: '@Injectable\(\)'
  rationale: NestJS DI container only manages classes marked @Injectable(); without it the class cannot be injected

HARD_RULE: Feature modules MUST declare all their providers in the providers[] array of @Module({})
  path_glob: src/**/*.module.ts
  rule_type: CUSTOM
  rationale: Providers not listed in their module's providers[] are invisible to the DI container

HARD_RULE: Authorization MUST be enforced via Guards that implement CanActivate, not inline in service methods
  path_glob: src/**/*.guard.ts
  rule_type: CUSTOM
  rationale: Inline authz checks in service methods are untestable in isolation and violate separation of concerns

HARD_RULE: process.env MUST NOT be accessed directly outside src/config/; use ConfigService
  path_glob: src/**/*.ts
  rule_type: CUSTOM
  rationale: Direct process.env access bypasses validation and makes configuration untestable

HARD_RULE: Modules that expose providers to other modules MUST list those providers in exports[]
  path_glob: src/**/*.module.ts
  rule_type: CUSTOM
  rationale: A provider not in exports[] cannot be injected by importing modules — causes runtime DI errors
```

## Testing conventions

- **Test runner**: Jest (bundled with the NestJS CLI scaffold); configured in `package.json` or `jest.config.ts`
- **Unit tests**: co-located `*.spec.ts` files next to the source file (e.g. `users.service.spec.ts` next to `users.service.ts`)
- **E2E tests**: `test/<feature>.e2e-spec.ts`; uses `supertest` against a real NestJS application started via `Test.createTestingModule`
- **Testing module**: use `@nestjs/testing`'s `Test.createTestingModule({ providers: [...] }).compile()` to create an isolated module; mock dependencies with `{ provide: UsersService, useValue: mockService }`
- **Service unit test pattern**:
  ```ts
  const module = await Test.createTestingModule({
    providers: [
      UsersService,
      { provide: getRepositoryToken(User), useValue: mockRepo },
    ],
  }).compile();
  const service = module.get<UsersService>(UsersService);
  ```
- **E2E test pattern** (supertest):
  ```ts
  const app = module.createNestApplication();
  await app.init();
  const res = await request(app.getHttpServer()).get('/users').set('Authorization', `Bearer ${token}`);
  expect(res.status).toBe(200);
  ```
- **Mocking**: jest mocks (`jest.fn()`, `jest.spyOn()`) for service methods; `getRepositoryToken(Entity)` as the injection token when mocking TypeORM repositories
- **Test scripts**: `npm run test` (unit), `npm run test:e2e` (end-to-end), `npm run test:cov` (coverage)

## Deep-scan file hints

```yaml
auth_hints:
  - "src/auth/auth.module.ts"
  - "src/auth/auth.service.ts"
  - "src/auth/strategies/"
  - "src/auth/guards/"
  - "src/common/guards/"
  - "src/auth/jwt.strategy.ts"
  - "src/auth/local.strategy.ts"
authz_hints:
  - "src/common/guards/roles.guard.ts"
  - "src/common/decorators/roles.decorator.ts"
  - "src/auth/guards/jwt-auth.guard.ts"
  - "src/common/guards/"
ui_hints: []
```

## Authz mapping

- `mechanism`: `guard` (NestJS guards implement `CanActivate` and are applied via `@UseGuards()` at the controller or handler level)
- `role_source`: `token` (JWT claims — role embedded in the JWT payload) or `db` (role fetched from a database on each request)
- Construct → `declarations[].kind`:
  - `@UseGuards(AuthGuard('jwt'))` or `@UseGuards(JwtAuthGuard)` applied to a controller/handler → `{kind: guard, sub: auth}`
  - `@UseGuards(RolesGuard)` combined with `@Roles('admin')` (via `@SetMetadata`) on a handler → `{kind: role}`
  - A class implementing `CanActivate` (e.g. `JwtAuthGuard`, `RolesGuard`) → `{kind: guard}`
  - `@SetMetadata('roles', ['admin'])` or a custom `@Roles('admin')` decorator built on `SetMetadata` → `{kind: role, metadata: roles}`

**Standard `@nestjs/passport` + custom RolesGuard pattern:**

1. **JWT strategy** — extend `PassportStrategy(Strategy)` from `passport-jwt` in `src/auth/strategies/jwt.strategy.ts`; decorate with `@Injectable()`; extract and validate the JWT payload; return the user object attached to `req.user`.
2. **`JwtAuthGuard`** — extend `AuthGuard('jwt')` from `@nestjs/passport`; decorate with `@Injectable()`; apply via `@UseGuards(JwtAuthGuard)` on controllers or handlers.
3. **`@Roles()` decorator** — created with `SetMetadata('roles', roles)` from `@nestjs/common`; applied to individual handlers: `@Roles('admin', 'moderator')`.
4. **`RolesGuard`** — implements `CanActivate`; reads the `roles` metadata key via `Reflector.getAllAndOverride('roles', [context.getHandler(), context.getClass()])` and compares against `req.user.roles`.
5. **Module wiring** — register the JWT strategy and guards in `providers[]` of `AuthModule`; export them so feature modules can use `@UseGuards(JwtAuthGuard, RolesGuard)` without re-importing the strategy.

## UI detection

_(N/A: API-only / no built-in UI)_

NestJS is a backend API framework with no built-in template rendering. MVC mode with a view engine (e.g. Handlebars via `@nestjs/serve-static` or `hbs` package) is possible but uncommon; treat any `views/` directory as project-specific configuration rather than a framework convention.

## Reuse discovery

```yaml
reuse_hints:
  helpers: [ "src/common/**", "src/utils/**" ]
  model_api: [ "src/**/*.entity.ts" ]
  services: [ "src/**/*.service.ts" ]
  commands: [ "src/**/*.command.ts", "src/**/*.cli.ts" ]
```

- `model_api`: TypeORM entity classes, their column definitions, relations (`@OneToMany`, `@ManyToOne`), and any active-record methods or subscribers.
- `services`: exported service classes and their public methods — these form the domain API used by controllers and other services.
- `commands`: CLI command handlers (nest-commander `@Command()` classes or custom scripts); check for `@nestjs/cli-plugin` or `nest-commander` in `package.json`.
