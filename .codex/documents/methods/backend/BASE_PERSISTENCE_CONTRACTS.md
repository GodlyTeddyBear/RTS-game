# BasePersistenceService Contracts

Method contracts for using `ReplicatedStorage.Utilities.BasePersistenceService` as a shared persistence helper.

Canonical architecture references:
- [../../architecture/backend/ERROR_HANDLING.md](../../architecture/backend/ERROR_HANDLING.md)
- [../../architecture/backend/STATE_SYNC.md](../../architecture/backend/STATE_SYNC.md)
- [INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md](INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md)

---

## Core Rules

- Use `BasePersistenceService` for shared profile-path read/write helper behavior across contexts.
- Keep profile lifecycle ownership in context infrastructure and lifecycle wiring modules.
- Use explicit persistence entrypoints in context services (for example `Load...`, `Save...`) that call base helper methods.
- Use `Result`-based failures at persistence boundaries where profile data or path access can fail.

---

## Profile Access Boundary Contract

- `GetProfileData(player)` is the boundary gate for profile availability.
- Missing profile data must return a `Result.Err(...)` with context-appropriate type/message.
- Callers must handle the `Result` contract and avoid direct profile assumptions.

---

## Path Traversal + Write Contract

- `LoadPathData(player)` reads through configured path segments and returns `Result.Ok(valueOrNil)`.
- `EnsurePath(player)` creates missing path tables and returns `Result.Ok(pathTable)`.
- `SetPathValue(player, key, value)` and `DeletePathValue(player, key)` perform explicit scoped mutations only after profile/path checks pass.
- `SaveAll(items, saveOne)` applies explicit per-item save behavior and propagates the first failure `Result`.

---

## Result Boundary Contract

- Persistence helper methods must return `Result` where profile access, path traversal, or write operations can fail.
- Nil-as-valid state (`missing leaf path`) should return `Result.Ok(nil)` instead of defect-style failure.
- Unexpected runtime failures should follow repo `Result` conventions at the infrastructure boundary.

---

## Prohibitions

- Do not put feature-specific policy/spec/domain decisions into `BasePersistenceService`.
- Do not register profile lifecycle handlers (`ProfileLoaded`, `ProfileSaving`, loader wiring) inside the base persistence helper.
- Do not mutate persistence state through ad-hoc tables or raw profile writes outside explicit helper methods.
- Do not expose generic ambiguous mutation entrypoints that hide load/save intent.

---

## Failure Signals

- Base persistence helper imports domain services or contains eligibility checks.
- Context lifecycle is wired directly inside `BasePersistenceService`.
- Callers bypass helper methods and write to profile paths ad hoc.
- Persistence boundary methods return plain values where a `Result` contract is required.

---

## Checklist

- [ ] Base helper is used only for shared persistence mechanics, not feature policy logic.
- [ ] Profile lifecycle wiring stays context-owned.
- [ ] Context persistence modules expose explicit `Load...` / `Save...` entrypoints.
- [ ] Profile/path boundary failures use `Result` contracts.
- [ ] Path traversal and writes go through explicit helper methods.

