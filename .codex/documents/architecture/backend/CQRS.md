# CQRS — Asymmetric Layers

Commands and Queries are separated at the Application layer. Commands traverse the full DDD stack. Queries skip the Domain layer entirely.

---

## Folder Structure

```
Application/
├── Commands/        # Write operations — full DDD stack
│   ├── AddItem.lua
│   └── RemoveItem.lua
└── Queries/         # Read operations — skip Domain
    └── GetInventory.lua
```

`Application/Services/` no longer exists. Every Application service lives in either `Commands/` or `Queries/`.

---

## Dependency Rules

```
Commands:   Context → Application/Commands → Domain → Infrastructure
Queries:    Context → Application/Queries → Infrastructure (NO Domain)
```

| Rule | Detail |
|------|--------|
| Queries never require from `[ContextName]Domain/` | No Domain validators, calculators, or value objects |
| Queries never inject Domain services via Registry | `Init()` only pulls Infrastructure services |
| Queries never call mutation methods on SyncService | Only `Get*ReadOnly()` and `Get*Atom()` |
| Commands return confirmations, not full state | Return what changed, not the resulting state |

---

## Command Contract

Commands represent intent to change state. They follow the existing Application service pattern.

```lua
function Command:Init(registry, _name)
    -- Domain services (validation, calculation)
    self.Validator = registry:Get("SomeValidator")
    -- Infrastructure services (mutation, persistence)
    self.SyncService = registry:Get("SomeSyncService")
    self.PersistenceService = registry:Get("SomePersistenceService")
end

function Command:Execute(...)
    -- 1. Validate (Domain)
    -- 2. Calculate (Domain)
    -- 3. Mutate (Infrastructure — SyncService)
    -- 4. Persist (Infrastructure — PersistenceService)
    -- 5. Return confirmation
end
```

---

## Query Contract

Queries are thin. Validate input inline, read from Infrastructure, return data.

```lua
function Query:Init(registry, _name)
    -- Infrastructure ONLY — no Domain services
    self.SyncService = registry:Get("SomeSyncService")
end

function Query:Execute(...)
    -- 1. Guard clause (inline, not Domain validation)
    -- 2. Read from Infrastructure (deep clone)
    -- 3. Return data
end
```

---

## Input Validation in Queries

Queries validate input structurally, not with Domain services.

| Validation type | Where | Example |
|----------------|-------|---------|
| Input guards | Inline in Query `Execute()` | `userId > 0`, `slotIndex ~= nil` |
| Business rules | Domain Services (Commands only) | "Has capacity?", "Is stackable?" |

If a query needs business logic to determine what to return, that logic becomes a **read projection** in Infrastructure — not Domain logic.

---

## Classifying a Service

**Does it change state?** → Command (even if it also returns data).
**Does it only read?** → Query.

If a query later needs side effects (logging views, triggering checks), move it to `Commands/`.

---

## Restore Commands (Hydration on Player Join)

When a player rejoins and their data is loaded, ECS entities and their side effects (positions, slot claims, active states) must be reconstructed. This is done with **restore commands** — private methods on the Context that mirror the corresponding Application Commands but skip steps that don't apply on restore.

### Rule: restore commands must mirror their Application Command

A restore command is not a simplified version of the assign command — it is the same command with specific steps skipped. Skipping a policy check to "save time" is dangerous because **policies often return resolved state** (live instances, entity references) that the command needs. Bypassing the policy means you have to re-resolve that state yourself, which duplicates logic and is error-prone.

**Steps to skip on restore:**
| Step | Reason to skip |
|------|---------------|
| Assign task target | Already restored from persisted data |
| Persist to ProfileStore | Data is already correct in the store |
| Sync to client atom | Atom is already populated by `LoadUserWorkers` |

**Steps to keep:**
| Step | Reason to keep |
|------|---------------|
| Policy check | Resolves live instances (ore model, entity ref) needed by subsequent steps |
| Claim slot / register state | Must re-register in-memory tracking (e.g. `MiningSlotService.SlotMap`) |
| `UpdatePosition` | Teleports the model to the correct world position |
| `StartMining` / start active state | Restarts the production loop |

### Timing: models must exist before restore commands run

`UpdatePosition` teleports via `GameObjectComponent` — the model must already exist. Restore commands must run **after** `SyncDirtyEntities` has flushed the newly created entities. Similarly, `LotSpawned` must fire **after** the lot's `SyncDirtyEntities` flush, so zone sub-entities (Mines, Farm, etc.) exist when the policy queries them.

### Pattern

```lua
-- In Context._SpawnWorkersFromPendingData:

-- Pass 1: create entities, restore static state
for workerId, workerData in workersData do
    self:_RestoreWorker(userId, workerId, workerData)
end

-- Flush so models exist in workspace
self.GameObjectSyncService:SyncDirtyEntities()

-- Pass 2: restore dynamic state (position, slot claims, active states)
for workerId, workerData in workersData do
    if workerData.AssignedTo == "Miner" and workerData.TaskTarget then
        self:_HydrateMinerAssignment(userId, workerId, workerData.TaskTarget)
    end
end
```

```lua
-- _HydrateMinerAssignment mirrors AssignMinerOre:Execute, skipping persist/sync/assigntarget
function WorkerContext:_HydrateMinerAssignment(userId, workerId, oreId)
    local result = self.AssignMinerOrePolicy:Check(userId, workerId, oreId)
    if not result.success then return end

    local entity = result.value.Entity
    local oreInstance = result.value.OreInstance  -- resolved by policy, not re-fetched

    local slotIndex, standPos, lookAtPos =
        self.MiningSlotService:ClaimSlot(userId, workerId, oreId, oreInstance:GetPivot(), oreInstance)

    self.EntityFactory:AssignSlotIndex(entity, slotIndex)
    self.EntityFactory:UpdatePosition(entity, standPos.X, standPos.Y, standPos.Z, lookAtPos.X, lookAtPos.Y, lookAtPos.Z)
    self.EntityFactory:StartMining(entity, oreId, oreConfig.MiningDuration)
end
```

---

## SyncService

The SyncService is **not split**. It already has natural read/write separation:

- Read methods: `Get*ReadOnly()`, `Get*Atom()`
- Write methods: `SetSlot()`, `UpdateSlotQuantity()`, etc.

The rule is enforced by convention: queries only call read methods.

---

## Context.lua

Unchanged — still a pure pass-through. Only the `require` paths change:

```lua
-- Commands
local AddItem = require(script.Parent.Application.Commands.AddItem)
-- Queries
local GetInventory = require(script.Parent.Application.Queries.GetInventory)
```

Registration stays the same — both register as "Application" category.

---

## Registry

Unchanged. Commands and queries both register with category `"Application"`.
