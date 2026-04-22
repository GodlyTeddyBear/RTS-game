# ECS Persistence Rules


---
## Purpose

ECS Persistence is the bridge between ECS entity components and ProfileStore. It converts entity component data to plain data tables for storage, and plain data tables back into ECS entity state on load.

This is distinct from Charm-sync persistence (which handles player wallet/atom state). Use ECS Persistence when entity data must survive across sessions.

---

## When to Use ECS Persistence vs Charm-sync

| Concern | Use |
|---------|-----|
| Entity component state that survives across sessions | ECS Persistence (`*PersistenceService`) |
| Per-player runtime state replicated to client (wallet, stats) | Charm-sync (`*SyncService`) |
| Transient ECS state that resets each run | Neither - ECS only, no persistence |

---

## Core Rules

- The persistence service is the only place that reads `profile.Data` for its path and writes entity data back to it - no other module touches that path.
- The persistence service lives in `Infrastructure/Persistence/` alongside sync services.
- The persistence service contains no domain logic - pure conversion and read/write only.
- All loads return a deep copy - callers never hold a reference to live profile data.
- All fallible operations return `Result<T>` - `Ok` on success, `Err` on failure.
- `SaveAll` aborts on the first failure and returns the failing `Result`.
- The persistence service does not create or destroy ECS entities - it only reads from and writes to components and profile data.
- Entity hydration (creating entities from loaded data) is the responsibility of the factory, not the persistence service.
- Runtime/client synchronization after persistence writes is orchestrated by Application commands or Context handlers, not by the persistence service itself.

---

## Method Shape

Every ECS persistence service exposes explicit, operation-focused methods:

| Method | Signature | Purpose |
|--------|-----------|---------|
| `Load<Entity>Data` | `(player) -> Result<DataTable?>` | Return deep copy of stored data, or `Ok(nil)` if none |
| `Save<Entity>` | `(player, entity) -> Result<boolean>` | Convert one entity's components to profile data |
| `SaveAll<Entities>` | `(player, entities) -> Result<boolean>` | Save all entities; abort on first failure |
| `Delete<Entity>` | `(player, entityId) -> Result<boolean>` | Remove one entity entry from profile data |
| `Add/Record/Increment...` | `(player, deltaArgs...) -> Result<UpdatedData>` | Mutate one persisted concern in place (for example `AddMoney`, `RecordWaveClear`) |

`Load` returns `Ok(nil)` - not `Err` - when no data has been persisted yet. `Err` is reserved for genuine failures (missing profile, bad state).

Prefer incremental mutation methods over bulk snapshot setters. Do not pass the entire persisted object from callers when a specific operation method can express the write intent.

---

## Profile Data Path Ownership

Each persistence service owns exactly one path under `profile.Data`. It is responsible for ensuring that path exists before writing.

```lua
-- Service owns: profile.Data.Production.Workers
local function _EnsureWorkersTable(data: any)
    if not data.Production then
        data.Production = {}
    end
    if not data.Production.Workers then
        data.Production.Workers = {}
    end
end
```

No other module writes to a path owned by a persistence service.

---

## Component Serialization

The persistence service serializes only the fields needed to reconstruct the entity. It does not serialize derived, transient, or runtime-only component fields.

```lua
-- CORRECT: serialize only persistent fields
data.Production.Workers[worker.Id] = {
    Id = worker.Id,
    Rank = worker.Rank,
    Level = worker.Level,
    Experience = worker.Experience,
    AssignedTo = assignment and assignment.Role or nil,
    Equipment = equipment and { ToolId = equipment.ToolId, Slot = equipment.Slot } or nil,
}

-- WRONG: serializing transient/derived state
data.Production.Workers[worker.Id] = {
    HealthPercent = ..., -- [DERIVED] - never persist this
    CooldownElapsed = ..., -- transient - resets on load
}
```

---

## Load Contract

Load always returns a deep copy. The caller may freely mutate the returned table without affecting profile data.

```lua
function WorkerPersistenceService:LoadWorkerData(player: Player): Result<{ [string]: any }>
    local data = self.ProfileManager:GetData(player)
    if not data then
        return Ok(nil :: any)
    end
    if not data.Production or not data.Production.Workers then
        return Ok(nil :: any)
    end
    return Ok(deepCopy(data.Production.Workers))
end
```

---

## Lifecycle Wiring

ECS persistence hooks into the standard persistence lifecycle events - it does not use ad-hoc `Players.PlayerAdded` / `Players.PlayerRemoving` handlers.

```text
ProfileLoaded  -> persistence service loads data -> factory hydrates entities
ProfileSaving  -> persistence service serializes entities -> writes to profile.Data
```

The persistence service is called by the context's lifecycle handler, not by the service itself.

---

## Persist Then Sync Orchestration Pattern

When a command updates data that is both persisted and client-visible, apply this order:

1. Validate business rules (Domain/Policy).
2. Mutate ECS/runtime state.
3. Persist via `*PersistenceService`.
4. Sync runtime/client view via `*SyncService`.

Use `Try(...)` on persistence first, then perform sync:

```lua
Try(self.PersistenceService:SaveWorkerEntity(player, entity))
self.SyncService:CreateWorker(userId, workerId, workerType)
```

Incremental example:

```lua
local updatedRunStats = Try(self.PersistenceService:RecordWaveClear(player, waveNumber))
self.SyncService:SyncRunStats(userId, updatedRunStats)
```

If persistence fails, do not emit a successful sync for that mutation path.

For context-level lifecycle boundaries:
- `ProfileLoaded`: load persisted data, hydrate runtime state, then hydrate/sync client atoms.
- `ProfileSaving`: flush runtime state through persistence services synchronously.

---

## Separation from Charm-sync

A context may have both a `*SyncService` (Charm-sync) and a `*PersistenceService` (ECS bridge). They own separate concerns and separate profile data paths.

They must not call each other directly. Coordination belongs in Application commands and Context lifecycle handlers.

```text
ResourceSyncService      -> owns Charm atom -> replicates wallet to client
WorkerPersistenceService -> owns profile.Data.Production.Workers -> persists entity state
Command/Context bridge   -> orchestrates persist then sync order
```

---

## Examples

<!-- Add context-specific correct usage examples here when updating this contract. -->

---

## Prohibitions

- Do not violate the required rules defined in this document's Core Rules and contract sections.

---

## Failure Signals

- Implementation behavior contradicts one or more required rules in this contract.

---

## Checklist

- [ ] All required rules in this contract are satisfied.

