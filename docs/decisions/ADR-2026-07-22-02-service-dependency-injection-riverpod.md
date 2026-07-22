# ADR-2026-07-22-02: Riverpod for All Service Dependency Injection

**Status:** Proposed
**Owner:** Agent session 2026-07-22

## Decision

All CoverWise Flutter service classes will be wired through Riverpod providers. Static service classes (all-static pattern) will be converted to Riverpod providers or Notifiers. The `DocumentService.authenticatedDio` static singleton will be replaced by an `authenticatedDioProvider`. The `service_providers.dart` file will be extended to cover all 23 service classes.

## Date

2026-07-22

## Context

The CoverWise Flutter app has 23 service classes using three coexisting DI patterns:

- **All-static (9 services):** AuthService, AnalyticsService, SessionService, InstallService, AppStateRepository, NotificationService, ContactService, LeadGenerationService, PreventiveHealthService. These are namespaces of static methods with no constructor injection. Dependencies are resolved by directly calling other static services or accessing Hive boxes by name.
- **Instance via Riverpod (5 services):** DocumentService, QueryService, PolicyExtractionService, RelationshipExtractionService, EvidenceService. These accept dependencies in their constructors and are wired through Riverpod providers in `service_providers.dart`.
- **Singleton (3 services):** PrincipalKeyService, ConsentSyncService, HiveWorkspaceService. These use factory constructors with a private `_instance`.
- **Instance (direct) (3 services):** LocalStorageService, ServerConsentService, EntitlementService. These accept constructor args but are instantiated ad-hoc rather than through providers.
- **Static-only (safe) (3 services):** MlOcrService, DemoService, DragDropService. These are pure functions or have no mutable state.

A deep-dive analysis (docs/di_dive_2026-07-22.md) identified concrete damage from the mixed approach:

1. **PolicyExtractionService** creates its own `Dio` without `AuthInterceptor` — the exact same bug that was already fixed in EvidenceService. Server-bound calls go out without a Bearer token and are rejected.
2. **AuthService has zero test coverage** across 73 test files. No test calls `signIn`, `accessToken`, `signOut`, or `deleteAccount`. The static pattern using `FlutterSecureStorage` and `Supabase.instance.client` makes it effectively untestable without real hardware-backed secure storage.
3. **DocumentService.authenticatedDio** is consumed by 6 different callers (EvidenceService, AnalyticsService, ServerConsentService, BillingAdapter, ProcessingStatusScreen, DocumentService itself). Nobody owns its lifecycle. A screen comment explicitly documents: "must not close it while other screens may still be using it."
4. **Static state leaks between tests** — AnalyticsService._buffer, SessionService._currentSessionId, InstallService._cachedInstallId persist across test cases.
5. **ConsentSyncService** uses a factory hack (optional Dio override) to enable testing, but this creates ephemeral test instances that bypass the production singleton's dedup logic.
6. **Startup order** in main.dart is a sequential script with implicit dependencies. A new developer adding a service that depends on another service discovers the dependency at runtime, not at compile time.

The app already uses `flutter_riverpod ^3.3.2` for all state management. All screens are `ConsumerWidget` or `ConsumerStatefulWidget`. A `service_providers.dart` file exists with 3 providers. The mechanism is already in place and underutilized.

## Options Considered

### Option A: Riverpod for all service DI (CHOSEN)

Extend the existing Riverpod provider pattern to cover all services. Static services become Riverpod providers or Notifiers. `DocumentService.authenticatedDio` becomes `authenticatedDioProvider`. The provider graph replaces the sequential startup script.

**Pros:**
- Zero new dependencies (Riverpod already in pubspec.yaml, all screens already use it)
- `ref.onDispose` provides lifecycle management that nothing else offers (close Dio, cancel timers, flush buffers)
- `ProviderScope.overrides` provides test injection without mocking frameworks
- Provider graph evaluates dependencies lazily, replacing the manual startup ordering
- Auth state changes can invalidate providers, causing reactive recreation (e.g., new Dio on token refresh)
- Pattern family: once a migration pattern is established (static → provider), it applies uniformly to all remaining services

**Cons:**
- Learning curve for `ref.watch` vs `ref.read` vs `ref.invalidate`, but the app is past that
- Provider files need organization (one file per concern or one big file)
- Some one-shot calls from non-widget contexts need `ref` propagation or a container pattern
- Migration requires touching every file that calls a static service method

**Completeness: 10/10** — all 23 services converged to one pattern, lifecycle managed, testable.

### Option B: GetIt (service locator)

Add `get_it` package and register all services as singletons or factories in a composition root.

**Pros:**
- `GetIt.I<AuthService>()` from anywhere, no widget tree dependency
- Simple mental model (register + lookup)
- Works outside widget context (timers, callbacks, isolates)

**Cons:**
- Same fundamental problem as static services: global mutable state, no lifecycle management, no reactive recreation
- Still need manual cleanup in tests (`GetIt.I.reset()`)
- No dependency graph evaluation (must register in the right order, enforced at runtime)
- `ref.onDispose` equivalent does not exist — registered instances live until explicitly unregistered
- Adds a new dependency and a second DI mechanism alongside the existing Riverpod pattern
- Services that need lifecycle (Dio disposal, timer cancellation, buffer flush) still need manual teardown

**Assessment:** GetIt is slightly better than static services but does not solve the root problems (lifecycle, reactivity, test isolation). It would coexist with Riverpod, creating two DI surfaces.

**Completeness: 5/10** — lookup improves but lifecycle, reactivity, and test isolation remain manual.

### Option C: Manual constructor injection (no DI framework)

Every service accepts its dependencies in its constructor. A composition root in main.dart creates all services and passes them to providers or InheritedWidgets.

**Pros:**
- No framework dependency
- Every dependency is explicit in the constructor signature
- Tests create services with mocked dependencies — pure constructor injection
- Compile-time safety (a missing dependency is a compile error, not a runtime crash)

**Cons:**
- Composition root becomes a manual factory function that grows with every new service
- No lifecycle management — the composition root owns disposal and must track every disposable service
- No reactive pattern — changing a dependency (e.g., new Dio after token refresh) requires manual re-creation of all dependents
- No lazy evaluation — all services are created eagerly at startup or must be lazily initialized by hand
- The app is past the scale where this is practical (23 services with cross-cutting lifecycle concerns)

**Assessment:** Works well for small apps. CoverWise is past that scale. The composition root would be managing lifecycle manually, which is what Riverpod does automatically.

**Completeness: 6/10** — testable and explicit, but lifecycle and reactivity are manual.

### Option D: Injectable (code-gen DI)

Add `injectable` + `get_it` + `build_runner` for auto-wired dependency injection.

**Pros:**
- Type-safe, auto-wired, minimal boilerplate
- Popular in Flutter ecosystem
- Constructor injection is enforced by the pattern

**Cons:**
- Adds `build_runner` as a mandatory build step
- Code-gen can produce hard-to-debug errors, slow builds, and merge conflicts in generated files
- Still uses `get_it` under the hood — same lifecycle and reactivity limitations
- Overkill for 23 services where the wiring is straightforward
- Would be the third state management / DI concern in the app (Riverpod + Injectable + whatever replaces static)

**Assessment:** Code-gen DI makes sense at 50+ services with complex wiring. At 23 services where most are thin Hive wrappers, the overhead is not justified.

**Completeness: 7/10** — auto-wired and type-safe, but adds build_runner overhead and shares GetIt's lifecycle limitations.

## Chosen Path

Option A: Riverpod for all service DI.

The decision is driven by four factors:

1. **Existing investment.** The app already uses Riverpod for all state management. Every screen is a `ConsumerWidget`. Adding a second DI framework (GetIt, Injectable) would create two DI surfaces violating motto 7 (supersession — one canonical path).

2. **Lifecycle is the unsolved problem.** The `authenticatedDio` leak, the `AnalyticsService` timer, the `ProcessingStatusScreen` comment — all are lifecycle problems. Riverpod's `ref.onDispose` is the only option that solves them. No other approach provides lifecycle management. This alone eliminates Options B, C, and D for the services that have lifecycle (AuthService: Supabase client, AnalyticsService: timer + buffer, DocumentService: Dio + interceptors).

3. **Test isolation.** `ProviderScope.overrides` replaces every static mock pattern. Tests override providers with mocks; there is no static state to leak between test cases. This is the only option that provides isolation without manual teardown in every test file.

4. **Pattern family.** Per motto 0.12.3, once a pattern is established and signed off, apply it uniformly. The Riverpod provider pattern is established in `service_providers.dart`. The migration extends it to cover the remaining services. No new pattern is introduced.

## Tradeoffs

- **Provider file organization.** 23 providers in one file (`service_providers.dart`) becomes large. Split by concern (auth_providers.dart, document_providers.dart, analytics_providers.dart, etc.) — each with a clear import boundary.
- **Non-widget code.** Background timers, push notification handlers, and isolates need access to services without a `ref` object. Solution: a top-level `container` holding a `ProviderContainer` reference, set at app startup. This is a well-known Riverpod pattern.
- **Migration disruption.** Every file that calls `AuthService.signIn()` must change to `ref.read(authServiceProvider.notifier).signIn()`. This is mechanical but touches ~14 files. Mitigation: old static methods keep working with a `@Deprecated` annotation for one release cycle.

## Assumptions

1. The app stays on `flutter_riverpod` for the foreseeable future. If a future DI framework replaces Riverpod, the provider wrappers are the thing that needs rewriting — the services themselves remain unchanged (they are plain classes with constructor injection).
2. The `ProviderContainer` pattern for non-widget code is acceptable. This is a standard Riverpod practice documented by the Riverpod authors.
3. Migration happens in dependency order (8 commits), not all at once. Each commit is independently deployable.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `ProviderContainer` in non-widget code creates a global | Low | Medium | The container is scoped to service access only, not arbitrary global state. Wrapped in a `ServiceLocator` class with a narrow API. |
| Migration misses a static call site | Medium | Medium | Compile errors catch missing imports after old static methods are removed. The `@Deprecated` interim catches during the transition. |
| AuthService provider lifecycle conflicts with secure storage | Low | High | AuthService is migrated last. The existing startup sequence in main.dart is preserved until the provider is fully verified. |
| Test overrides become complex | Low | Low | Existing test pattern (HiveTestHelper + direct service construction) continues during migration. Provider overrides are additive for new tests. |
| `ref.invalidate` during active operations causes crashes | Low | Medium | Invalidation is explicit, not automatic. Providers are invalidated only on auth state changes and workspace resets — events that already cause full re-initialization. |

## Validation Plan

1. Each commit: `flutter test` passes with no regressions.
2. Commit 2 (authenticatedDioProvider): verify that all 6 consumers resolve to the same Dio instance (or get new instances after invalidation).
3. Commit 7 (AuthService provider): verify sign-in, sign-out, and token refresh work end-to-end against the real Supabase/dev API.
4. Final: run full test suite and confirm 0 regressions.

## Rollback / Migration Path

- **Per-commit rollback:** each commit is self-contained. If commit N causes issues, revert commit N. Earlier commits are not affected.
- **Full rollback:** restore `service_providers.dart`, `main.dart`, and all screen/service files to pre-migration state. The old static methods are preserved during migration (deprecated, not deleted), so the revert is a compile-safe restore.
- **Post-migration cleanup:** after one release cycle, remove `@Deprecated` static methods and the old `authenticatedDio` static getter.

## Update Log

*(No entries yet — this is the original ADR.)*

## Anything Else?

**Q: What about HiveWorkspaceService and PrincipalKeyService?** These are lifecycle-managed singletons with a clear initialization point (startup) and disposal point (workspace reset). They stay as singletons. The providers that depend on them (`hiveWorkspaceProvider`, `principalKeyProvider`) wrap them for access — they do not replace them.

**Q: What about AppStateRepository?** It is 256 lines of static Hive read/write methods. It is not a service — it is a data access object. It becomes a provider that returns the Hive box, with convenience methods as provider-static or extension methods. No behavior change.

**Q: Does this touch the backend at all?** No. This is a pure Flutter-side refactor. No API contracts change.

**Q: How does this interact with the workspace reset / account conversion flow?** The workspace reset flow in `main.dart` closes Hive boxes and re-opens them with a new key. Providers that hold Hive references will need to be invalidated during this flow. This is already the behavior today — the reset is a full re-initialization. The provider pattern makes it explicit (invalidate the box providers) rather than implicit (call `HiveWorkspaceService.resetForPrincipal()` and hope everyone re-reads).
