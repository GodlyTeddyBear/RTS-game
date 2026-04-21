# Infrastructure Runtime + Persistence Contracts

Defines strict contracts for Infrastructure runtime and persistence methods.

Canonical architecture references:
- [../../architecture/backend/STATE_SYNC.md](../../architecture/backend/STATE_SYNC.md)
- [../../architecture/backend/ERROR_HANDLING.md](../../architecture/backend/ERROR_HANDLING.md)
- [../../architecture/backend/SYSTEMS.md](../../architecture/backend/SYSTEMS.md)

---

## Runtime Boundary Contract

- Use `Result` at genuinely fallible runtime boundaries:
  - external APIs (`fromPcall(...)`)
  - nil-as-failure boundaries (`fromNilable(...)`)
  - multi-step operations that can partially fail
- Use plain Lua returns for safe in-memory reads where `nil` is a valid state.

---

## Sync Service Placement Contract

- Atom read/write orchestration services must live in `Infrastructure/Persistence`.
- Context/Application modules mutate atom state only through these sync services.
- Direct atom mutation outside sync services is prohibited.

---

## Persistence Lifecycle Contract

- Hydration/save ownership is context-driven through:
  - `GameEvents.Events.Persistence.ProfileLoaded`
  - `GameEvents.Events.Persistence.ProfileSaving`
  - `PlayerLifecycleManager:RegisterLoader(...)`
  - `PlayerLifecycleManager:NotifyLoaded(...)`
- Persistence lifecycle logic must not be owned by feature-local `Players.PlayerAdded/PlayerRemoving` flows.

---

## Persistence Method Shape Contract

- Persistence infrastructure exposes explicit method pairs (for example `Load...`, `Save...`).
- Context event handlers call these explicit methods at profile lifecycle boundaries.

---

## Prohibitions

- Do not place sync services under `Infrastructure/Services`.
- Do not evaluate domain eligibility/spec rules inside infrastructure modules.
- Do not mutate atom state from Application, Domain, or Context modules directly.
- Do not implement profile hydration/save ownership with ad-hoc player event handlers inside contexts.

---

## Failure Signals

- Infrastructure read/write orchestration module exists outside `Infrastructure/Persistence`.
- Query/command/context writes atom data directly instead of calling sync service mutation APIs.
- Infrastructure module contains policy/spec eligibility branching.
- Context persistence flow depends on `PlayerAdded/PlayerRemoving` rather than persistence events + lifecycle manager.
- Persistence module exposes a generic ambiguous sync entrypoint with no explicit load/save boundary semantics.

---

## Checklist

- [ ] Result usage follows runtime-boundary rules (`fromPcall`, `fromNilable`, `Try` where appropriate).
- [ ] Sync service is implemented under `Infrastructure/Persistence`.
- [ ] Atom mutations occur only through sync service APIs.
- [ ] Hydration/save wiring uses persistence events + lifecycle manager.
- [ ] Persistence modules expose explicit `Load...` / `Save...` methods.
- [ ] Infrastructure contains runtime operations only, not domain eligibility decisions.
