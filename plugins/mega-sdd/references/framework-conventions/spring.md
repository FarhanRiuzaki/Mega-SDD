---
framework: spring
framework_version_range: "3.x (Boot)"
last_verified_against: 2026-06-10
maintainer: mega-sdd
detection_signature:
  package_manifest: pom.xml
  dependency_marker: "spring-boot-starter"
  version_regex: '<artifactId>spring-boot-starter\S*</artifactId>[\s\S]*?<version>(\d+\.\d+)'
extends: _universal
pack_tier: full
---

# Spring Boot Convention Pack (3.x)

Conventions for Spring Boot 3.x Java backend projects. Extends `_universal.md` — universal defaults apply, Spring-specific rules override on conflict.

> **Build tool note**: the primary detection manifest is `pom.xml` (Maven). Projects using Gradle carry `build.gradle` or `build.gradle.kts` instead of `pom.xml`; the dependency marker `spring-boot-starter` applies in both cases (as a Gradle dependency string rather than a Maven artifact ID).

## File location standards

| Artifact | Path |
|---|---|
| Controllers | `src/main/java/<pkg>/controller/` |
| Services | `src/main/java/<pkg>/service/` |
| Repositories | `src/main/java/<pkg>/repository/` |
| Entities / domain models | `src/main/java/<pkg>/entity/` (or `model/`) |
| DTOs | `src/main/java/<pkg>/dto/` |
| Config classes | `src/main/java/<pkg>/config/` |
| Exception handlers | `src/main/java/<pkg>/exception/` |
| Security config | `src/main/java/<pkg>/config/SecurityConfig.java` |
| Application entry point | `src/main/java/<pkg>/<AppName>Application.java` |
| Application properties | `src/main/resources/application.properties` or `application.yml` |
| Profile-specific config | `src/main/resources/application-{profile}.yml` |
| Thymeleaf templates (MVC) | `src/main/resources/templates/` |
| Static assets (MVC) | `src/main/resources/static/` |
| Unit + integration tests | `src/test/java/<pkg>/` |
| Test resources | `src/test/resources/` |

## Naming standards

| Concept | Convention | Example |
|---|---|---|
| Class case | PascalCase | `UserService`, `OrderController` |
| Method case | camelCase | `findById`, `createOrder` |
| Variable / field case | camelCase | `userRepository`, `jwtSecret` |
| Constant case | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Package name | lowercase dot-separated | `com.example.myapp.service` |
| Controller class | PascalCase + `Controller` suffix | `UserController`, `OrderController` |
| Service class | PascalCase + `Service` suffix | `UserService`, `PaymentService` |
| Repository interface | PascalCase + `Repository` suffix | `UserRepository`, `OrderRepository` |
| Entity class | PascalCase singular noun | `User`, `OrderItem` |
| DTO class | PascalCase + `Dto` suffix (or `Request`/`Response`) | `UserDto`, `CreateOrderRequest`, `OrderResponse` |
| Config class | PascalCase + `Config` suffix | `SecurityConfig`, `WebMvcConfig` |
| Exception class | PascalCase + `Exception` suffix | `ResourceNotFoundException`, `ValidationException` |
| Test class | PascalCase + `Test` suffix | `UserServiceTest`, `OrderControllerTest` |
| Test method | camelCase descriptive | `shouldReturnUserWhenIdExists`, `givenInvalidEmail_whenCreate_thenThrows` |
| DB column name | snake_case (via JPA column mapping) | `created_at`, `first_name` |
| DB table name | snake_case plural | `users`, `order_items` |

## Idioms (preferred patterns)

- **Constructor injection over field injection** — declare dependencies as `final` fields and inject via a constructor; `@Autowired` is optional on a single-constructor class and should be omitted (Spring 4.3+). Avoid `@Autowired` on fields directly.
- **Layered architecture** — `@RestController` (or `@Controller`) → `@Service` → `@Repository`; each layer talks only to the layer directly below it. Controllers parse requests and delegate; services hold business logic; repositories handle persistence.
- **DTOs at API boundaries** — never expose `@Entity` objects directly in REST responses or request bodies; map to/from DTOs in the controller or a dedicated mapper (MapStruct recommended).
- **Spring Data JPA repositories** — extend `JpaRepository<Entity, ID>` (or `CrudRepository` / `PagingAndSortingRepository`) for persistence; avoid raw `EntityManager` calls unless performing complex bulk operations.
- **`@Entity` for JPA persistence** — annotate domain classes with `@Entity` + `@Id` + `@GeneratedValue`; use `@Column` for explicit column mapping when the field name differs from the snake_case convention.
- **`@RequestMapping` / verb-specific shortcuts** — prefer `@GetMapping`, `@PostMapping`, `@PutMapping`, `@DeleteMapping`, `@PatchMapping` over `@RequestMapping(method = RequestMethod.GET)` for conciseness.
- **`application.yml` over `application.properties`** — prefer YAML for multi-environment configuration with Spring profiles (`spring.profiles.active`); `.properties` is acceptable for simple projects.
- **`@ControllerAdvice` / `@RestControllerAdvice` for global exception handling** — centralize error responses in a dedicated exception-handler class rather than `try/catch` in every controller.
- **`@Transactional` at the service layer** — annotate service methods that perform multi-step writes; do not annotate controllers or repositories directly for business transactions.
- **Spring Security `SecurityFilterChain` (not `WebSecurityConfigurerAdapter`)** — Spring Boot 3.x uses component-based security config via a `@Bean SecurityFilterChain`; `WebSecurityConfigurerAdapter` is removed in Spring 6.

## Hard Rules emitted

```
HARD_RULE: Controller classes MUST end with `Controller` suffix
  path_glob: src/main/java/**/controller/**/*.java
  rule_type: NAMING_RULE
  pattern: 'Controller\.java$'
  rationale: Convention enables auto-discovery and clarifies layer role; request mappings target these classes

HARD_RULE: Service classes MUST end with `Service` suffix
  path_glob: src/main/java/**/service/**/*.java
  rule_type: NAMING_RULE
  pattern: 'Service\.java$'
  rationale: Distinguishes business-logic layer from persistence layer; Spring component-scan relies on stereotype clarity

HARD_RULE: Repository interfaces MUST end with `Repository` suffix and extend a Spring Data repository
  path_glob: src/main/java/**/repository/**/*.java
  rule_type: NAMING_RULE
  pattern: 'Repository\.java$'
  rationale: Spring Data generates implementations at startup; non-conformant interface names are not auto-wired

HARD_RULE: Entity classes MUST carry `@Entity` and `@Id` annotations
  path_glob: src/main/java/**/entity/**/*.java
  rule_type: SIGNATURE_RULE
  pattern: '@Entity'
  rationale: JPA persistence requires both markers; a class in entity/ without @Entity is silently ignored by the persistence context

HARD_RULE: Field injection (`@Autowired` on a field) MUST NOT be used in new classes
  path_glob: src/main/java/**/*.java
  rule_type: CUSTOM
  forbidden_pattern: '@Autowired\s+private'
  rationale: Field injection prevents immutability, hides dependencies, and breaks unit testability without a DI container

HARD_RULE: Entity objects MUST NOT be returned directly from REST controller methods — use DTOs
  path_glob: src/main/java/**/controller/**/*.java
  rule_type: CUSTOM
  rationale: Exposing entities leaks JPA internals (lazy-load exceptions, version fields, internal IDs) and couples API shape to DB schema

HARD_RULE: Business logic MUST reside in `@Service` classes, not in controllers or repositories
  path_glob: src/main/java/**/*.java
  rule_type: CUSTOM
  rationale: Controllers handle HTTP concerns; repositories handle persistence; services are the only layer where business invariants are enforced

HARD_RULE: Multi-step write operations MUST be wrapped in a `@Transactional` service method
  path_glob: src/main/java/**/service/**/*.java
  rule_type: SIGNATURE_RULE
  pattern: '@Transactional'
  rationale: Without transaction demarcation, a mid-flight failure leaves the DB in an inconsistent state
```

## Forbidden patterns

- `@Autowired` on fields (use constructor injection)
- Returning `@Entity` instances from REST endpoints (use DTOs)
- Business logic in `@RestController` / `@Controller` methods (delegate to `@Service`)
- Raw SQL via `EntityManager.createNativeQuery()` for standard CRUD (use Spring Data JPA derived queries or JPQL)
- `WebSecurityConfigurerAdapter` (removed in Spring 6 / Boot 3.x — use `SecurityFilterChain` bean)
- `System.out.println()` for logging (use SLF4J `LoggerFactory.getLogger()` / `@Slf4j` Lombok)
- Hardcoded credentials or secrets in source code (use `application.yml` + environment variables or Spring Vault)

## ERD additions (Spring / JPA)

- **`@GeneratedValue(strategy = GenerationType.IDENTITY)`** is the standard auto-increment strategy; `SEQUENCE` for databases that prefer sequences (PostgreSQL).
- **Bidirectional relationships**: `@OneToMany(mappedBy = "parent")` on the owning side; always set both sides of the relationship in Java code.
- **`@JoinColumn`**: explicit FK column name via `name` attribute when the default inference is ambiguous.
- **Audit columns**: `created_at` + `updated_at` via `@CreatedDate` / `@LastModifiedDate` with `@EnableJpaAuditing` and an `@EntityListeners(AuditingEntityListener.class)` on the entity.
- **Soft deletes**: no built-in support; implement via a `deleted_at` column + `@Where(clause = "deleted_at IS NULL")` Hibernate annotation or a custom `@Filter`.

## Testing conventions

- Test runner: Maven — `mvn test`; Gradle — `./gradlew test`
- JUnit version: JUnit 5 (Jupiter) — bundled via `spring-boot-starter-test`
- Base annotations:
  - `@SpringBootTest` — full application context integration test
  - `@WebMvcTest(ControllerClass.class)` — slice test for a single controller (loads only MVC layer)
  - `@DataJpaTest` — slice test for JPA repositories (in-memory H2 by default)
  - `@MockBean` — replaces a Spring bean with a Mockito mock in a slice or full context test
- HTTP layer testing: `MockMvc` (auto-configured with `@WebMvcTest`); or `TestRestTemplate` / `WebTestClient` for full-context tests
- Mocking: Mockito (`@Mock`, `@InjectMocks`, `@ExtendWith(MockitoExtension.class)`) for pure unit tests without Spring context
- Test method naming: descriptive camelCase or `given_when_then` style
- Fixtures: use `@BeforeEach` setup methods or `@Sql` scripts for database state
- Testcontainers: for integration tests that require a real database (PostgreSQL, MySQL); annotate with `@Testcontainers` + `@Container`
- Coverage: JaCoCo plugin (`jacoco-maven-plugin` / `jacoco` Gradle plugin) for coverage reporting

## Deep-scan file hints

```yaml
auth_hints:
  - "src/main/java/**/config/SecurityConfig.java"
  - "src/main/resources/application.yml"
  - "src/main/resources/application.properties"
  - "src/main/java/**/service/*UserDetailsService*.java"
authz_hints:
  - "src/main/java/**/config/SecurityConfig.java"
  - "@EnableWebSecurity"
  - "src/main/java/**/*Controller*.java"
  - "src/main/resources/application.yml"
ui_hints:
  - "src/main/resources/templates/"
  - "src/main/resources/static/"
```

## Authz mapping

- `mechanism`: `annotation` (`@PreAuthorize` / `@Secured` on methods) + `filter-chain` (`SecurityFilterChain` `authorizeHttpRequests` rules)
- `role_source`: `db` (custom `UserDetailsService` loading roles from a database) or `token` (JWT claims carrying authorities)
- Construct → `declarations[].kind`:
  - `@PreAuthorize("hasRole('ADMIN')")` or `@PreAuthorize("hasAuthority('SCOPE_read')")` on a controller/service method → `{kind: role}`
  - `@Secured("ROLE_X")` on a method → `{kind: role}`
  - `SecurityFilterChain` bean with `.authorizeHttpRequests(auth -> auth.requestMatchers(...).hasRole(...))` rules → `{kind: filter-chain}`
  - `@EnableMethodSecurity` (or legacy `@EnableGlobalMethodSecurity`) in config class → enables method-level annotation enforcement

## UI detection

- Server-rendered MVC: Thymeleaf templates under `src/main/resources/templates/`; layouts via `th:fragment` attribute (e.g., `th:fragment="layout(content)"`) and inclusion via `th:replace` / `th:insert`
- Component / partial: Thymeleaf fragments defined with `th:fragment` in dedicated template files (e.g., `templates/fragments/navbar.html`)
- Notification call: Spring MVC Flash attributes (`RedirectAttributes.addFlashAttribute`) or client-side notification library imported in a base template
- Many Spring Boot projects are REST-only (no server-rendered UI); in that case `src/main/resources/templates/` will be absent — the pack applies to both REST-API and MVC styles

## Reuse discovery

```yaml
reuse_hints:
  helpers: [ "**/util/**/*.java", "**/utils/**/*.java", "**/helper/**/*.java" ]
  model_api: [ "**/entity/**/*.java", "**/model/**/*.java" ]
  services: [ "**/service/**/*.java" ]
  commands: [ "**/*Runner.java" ]
```

- model_api: public methods, JPA query methods (`findBy*`, `existsBy*`), and `@Query`-annotated methods on each entity/repository.
- commands: classes implementing `CommandLineRunner` or `ApplicationRunner` (the `run(...)` method signature acts as the entry point).
