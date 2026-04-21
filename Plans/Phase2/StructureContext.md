# StructureContext — Implementation Plan

## Context

Phase 2 (Vertical Slice) requires one structure — the Sentry Turret — that visibly changes wave outcomes. PlacementContext is already implemented and owns physical model spawning + the PlacementAtom. StructureContext is the combat layer on top: it listens for placed structures, tracks them as ECS entities, runs a per-frame targeting loop, and fires an attack signal for a future CombatContext to apply damage.

**User decisions:**
- Targeting: server per-frame poll (StructureContext queries EnemyContext each tick)
- Damage execution: StructureContext fires `StructureAttacked` signal; **CombatContext** (planned separately) applies damage
- Structure HP: deferred to Phase 3
- Placement bridge: PlacementContext fires a `StructurePlaced` BindableEvent; StructureContext listens

**Phase 2 scope:** Sentry Turret only.

---

## Goal

Build a server-authoritative `StructureContext` that:
1. Owns a dedicated JECS world for structure entities
2. Listens for `StructurePlaced` events from PlacementContext and creates ECS entities
3. Listens for `RunEnd` from RunContext and cleans up all structure entities
4. Runs a per-Heartbeat targeting system: for each structure, find nearest alive enemy in range
5. Runs a per-Heartbeat attack scheduler: fire `StructureAttacked` signal on cooldown + valid target
6. Exposes a server query API for CombatContext and other future consumers

---

## Short Action Flow

```
Server starts
  -> Knit discovers StructureContext
  -> StructureContext:KnitInit()
      -> StructureECSWorldService creates isolated JECS world
      -> StructureComponentRegistry registers components
      -> All services initialized via Registry

StructureContext:KnitStart()
  -> Acquire EnemyContext, RunContext, PlacementContext
  -> PlacementContext.StructurePlaced:Connect -> RegisterStructureCommand:Execute(record)
  -> RunContext.StateChanged:Connect -> if RunEnd -> CleanupAllCommand:Execute()
  -> Register StructureTargeting + StructureAttack scheduler systems

Per-Heartbeat:
  StructureTargetingSystem:Tick()
    -> GetAliveEnemies() ONCE per tick -> build position cache
    -> For each structure with ActiveTag:
        -> Find nearest enemy within AttackRange
        -> SetTarget(entity, nearest) or SetTarget(entity, nil)

  StructureAttackSystem:Tick(dt)
    -> For each structure with ActiveTag:
        -> Elapsed += dt
        -> If Elapsed >= AttackCooldown AND target not nil:
            -> Reset Elapsed = 0
            -> Fire StructureAttacked { structureEntity, targetEntity, damage, structureType }

CombatContext (future) listens to StructureAttacked -> calls EnemyContext:ApplyDamage()
```

---

## Assumptions

- PlacementContext is implemented; will be modified to expose `StructurePlaced` BindableEvent.
- EnemyContext exposes `GetAliveEnemies(): Result<{ entity }>` (must be unwrapped) and `GetEntityFactory(): Result<EnemyEntityFactory>`. There is no `GetEnemyPosition` method — position is read via `factory:GetPosition(entity)` which returns `{ cframe: CFrame }`.
- RunContext exposes `StateChanged` signal.
- StructureContext does NOT spawn models (PlacementContext owns that).
- No client replication from StructureContext in Phase 2.

---

## Ambiguities Resolved

| Question | Decision |
|---|---|
| Does StructureContext spawn models? | No — PlacementContext owns model spawning. |
| How does StructureContext learn about placements? | PlacementContext fires `StructurePlaced` BindableEvent. |
| Who applies damage to enemies? | CombatContext (planned separately). StructureContext fires signal only. |
| Structure HP in Phase 2? | No — deferred to Phase 3. |
| GetAliveEnemies() call frequency? | Once per tick, shared across all structure targeting evaluations. Result is unwrapped before iterating. |
| How is enemy position read? | Via `EnemyEntityFactory:GetPosition(entity).cframe.Position` — factory ref cached at Start() time via `EnemyContext:GetEntityFactory():Unwrap()`. |

---

## Files to Create / Modify

### Modify
- `src/ServerScriptService/Contexts/Placement/PlacementContext.lua` — add `StructurePlaced` BindableEvent + fire after successful placement

### Create (Shared / ReplicatedStorage)
```
src/ReplicatedStorage/Contexts/Structure/
  Config/
    StructureConfig.lua         <- AttackRange, AttackDamage, AttackCooldown per type
  Types/
    StructureTypes.lua          <- StructureType, component type exports
```

### Create (Server)
```
src/ServerScriptService/Contexts/Structure/
  StructureContext.lua
  Errors.lua
  Application/
    Commands/
      RegisterStructureCommand.lua
      CleanupAllCommand.lua
    Queries/
      GetActiveStructuresQuery.lua
      GetStructureCountQuery.lua
  StructureDomain/
    Specs/
      StructureSpecs.lua
    Policies/
      RegisterStructurePolicy.lua
  Infrastructure/
    ECS/
      StructureECSWorldService.lua
      StructureComponentRegistry.lua
      StructureEntityFactory.lua
    Services/
      StructureTargetingSystem.lua
      StructureAttackSystem.lua
```

---

## Implementation Plan

### Step 1 — StructureConfig + StructureTypes (Shared)

**Files:**
- `src/ReplicatedStorage/Contexts/Structure/Config/StructureConfig.lua`
- `src/ReplicatedStorage/Contexts/Structure/Types/StructureTypes.lua`

**StructureConfig tasks:**
- `"SentryTurret"`: `{ DisplayName="Sentry Turret", AttackRange=18, AttackDamage=15, AttackCooldown=1.2 }`
- `table.freeze`

**StructureTypes tasks:**
- `export type StructureType = "SentryTurret"`
- `export type StructureId = string`
- `export type TAttackStatsComponent = { AttackRange: number, AttackDamage: number, AttackCooldown: number }`
- `export type TAttackCooldownComponent = { Elapsed: number }`
- `export type TTargetComponent = { Entity: any }`
- `export type TInstanceRefComponent = { InstanceId: number, WorldPos: Vector3 }`
- `export type TIdentityComponent = { StructureId: StructureId, StructureType: StructureType }`

**Exit criteria:** All modules require without error under `--!strict`

---

### Step 2 — Errors.lua

**File:** `src/ServerScriptService/Contexts/Structure/Errors.lua`

- `UNKNOWN_STRUCTURE_TYPE`, `INVALID_PLACEMENT_RECORD`, `ENTITY_NOT_FOUND`
- `table.freeze`

---

### Step 3 — StructureECSWorldService

**File:** `src/ServerScriptService/Contexts/Structure/Infrastructure/ECS/StructureECSWorldService.lua`

- Mirrors EnemyECSWorldService exactly
- `StructureECSWorldService.new()` — creates `JECS.World.new()`
- `GetWorld(): any`

---

### Step 4 — StructureComponentRegistry

**File:** `src/ServerScriptService/Contexts/Structure/Infrastructure/ECS/StructureComponentRegistry.lua`

**`Init(registry)`:** Register + name via `world:component()` + `world:set(comp, JECS.Name, "...")`:
- `AttackStatsComponent`, `AttackCooldownComponent`, `TargetComponent`, `InstanceRefComponent`, `IdentityComponent`, `ActiveTag`

---

### Step 5 — StructureEntityFactory

**File:** `src/ServerScriptService/Contexts/Structure/Infrastructure/ECS/StructureEntityFactory.lua`

**`Init(registry)`:** store `self.World`, `self.Components`

**Methods:**
- `CreateStructure(record: StructureRecord): entity` — create entity, set all components from StructureConfig, add ActiveTag
- `SetTarget(entity, targetEntity: any?)` — set or clear TargetComponent
- `GetTarget(entity): any?`
- `GetAttackStats(entity): TAttackStatsComponent?`
- `GetCooldown(entity): TAttackCooldownComponent?`
- `SetCooldownElapsed(entity, elapsed: number)`
- `GetIdentity(entity): TIdentityComponent?`
- `GetInstanceRef(entity): TInstanceRefComponent?`
- `QueryActiveEntities(): { entity }` — `world:query(ActiveTag)` collect
- `DeleteEntity(entity)` — `world:delete(entity)`
- `DeleteAll()` — iterate active entities, delete each

**Guards:** Nil-check entity before all get/set

---

### Step 6 — StructureSpecs + RegisterStructurePolicy

**Files:**
- `src/ServerScriptService/Contexts/Structure/StructureDomain/Specs/StructureSpecs.lua`
- `src/ServerScriptService/Contexts/Structure/StructureDomain/Policies/RegisterStructurePolicy.lua`

**StructureSpecs:** `IsValidStructureType(string): boolean`, `HasValidInstanceId(any): boolean`

**RegisterStructurePolicy:** `Check(record): Result` — runs both specs; typed Err on failure; `Ok(true)` on pass

---

### Step 7 — RegisterStructureCommand + CleanupAllCommand

**RegisterStructureCommand:Execute(record):**
1. `Try(self._policy:Check(record))`
2. `entity = self._factory:CreateStructure(record)`
3. `Result.MentionSuccess(...)`
4. Return `Result.Ok(entity)`

**CleanupAllCommand:Execute():**
1. `self._factory:DeleteAll()`
2. Return `Result.Ok(true)`

---

### Step 8 — Query Modules

- `GetActiveStructuresQuery:Execute()` → `factory:QueryActiveEntities()`
- `GetStructureCountQuery:Execute()` → `#factory:QueryActiveEntities()`

---

### Step 9 — StructureTargetingSystem

**File:** `src/ServerScriptService/Contexts/Structure/Infrastructure/Services/StructureTargetingSystem.lua`

**`Start(deps)`:** store `self._enemyContext`; unwrap and cache `self._enemyEntityFactory = deps.enemyContext:GetEntityFactory():Unwrap()`

**`Tick()`:**
1. `local result = self._enemyContext:GetAliveEnemies()` — **once per tick**; if `not result.success` skip tick
2. Build `{ [entity]: Vector3 }` position cache: for each entity in `result.data`, call `self._enemyEntityFactory:GetPosition(entity)` → use `.cframe.Position`; skip if nil
3. For each active structure:
   - Get `stats.AttackRange` and `instanceRef.WorldPos`
   - Find nearest enemy within range from position cache
   - `self._factory:SetTarget(entity, nearest)` or `SetTarget(entity, nil)`

**Performance:** O(structures × enemies) — acceptable for Phase 2 counts

---

### Step 10 — StructureAttackSystem

**File:** `src/ServerScriptService/Contexts/Structure/Infrastructure/Services/StructureAttackSystem.lua`

**`Start(deps)`:** store `self._onAttack` callback

**`Tick(dt)`:**
1. For each active structure:
   - `cooldown.Elapsed += dt` → `SetCooldownElapsed`
   - If `Elapsed < stats.AttackCooldown`: skip
   - `target = GetTarget(entity)` — if nil: skip (do not reset; accumulate so first shot fires immediately on target entry)
   - Reset elapsed = 0
   - `self._onAttack({ structureEntity, targetEntity, damage = stats.AttackDamage, structureType })`

---

### Step 11 — Modify PlacementContext

**File:** `src/ServerScriptService/Contexts/Placement/PlacementContext.lua`

- In `KnitInit()`: create `self._structurePlacedSignal = Instance.new("BindableEvent")`; expose as `self.StructurePlaced = self._structurePlacedSignal.Event`
- After successful `PlaceStructureCommand:Execute()`: fire signal with the StructureRecord

---

### Step 12 — StructureContext Knit Service

**File:** `src/ServerScriptService/Contexts/Structure/StructureContext.lua`

**`KnitInit()`:**
- `Registry.new("Structure")`
- Create ECSWorldService; register world
- Register all services (Infrastructure / Domain / Application)
- `self._structureAttackedSignal = Instance.new("BindableEvent")`
- Register attack callback in registry
- `registry:InitAll()`
- `self.StructureAttacked = self._structureAttackedSignal.Event` — public for CombatContext

**`KnitStart()`:**
- Acquire `EnemyContext`, `RunContext`, `PlacementContext`
- Inject EnemyContext into TargetingSystem
- `PlacementContext.StructurePlaced:Connect(function(record) self._registerCmd:Execute(record) end)`
- `RunContext.StateChanged:Connect(function(state) if state == "RunEnd" then self._cleanupCmd:Execute() end end)`
- Register `StructureTargeting` + `StructureAttack` scheduler systems

**Public API:**
- `StructureContext:GetActiveStructures(): { entity }`
- `StructureContext:GetStructureCount(): number`
- `StructureContext.StructureAttacked` — BindableEvent signal for CombatContext

No Client remotes. `WrapContext(StructureContext, "StructureContext")` at bottom.

---

## Verification Checklist

### Functional
- [ ] Server starts cleanly after StructureContext is added
- [ ] After valid placement, `GetStructureCount()` returns 1
- [ ] Enemy within AttackRange → `StructureAttacked` fires after first cooldown
- [ ] `StructureAttacked` payload: correct `structureEntity`, `targetEntity`, `damage`, `structureType`
- [ ] Enemy moves out of range → TargetComponent cleared; attack stops
- [ ] Enemy re-enters range → targeting resumes next tick; fires immediately if cooldown already elapsed
- [ ] On RunEnd → `GetStructureCount()` returns 0; no JECS leaks
- [ ] `PlacementContext.StructurePlaced` fires and entity registered correctly

### Edge Cases
- [ ] No enemies spawned — targeting runs without error; all TargetComponents nil
- [ ] All enemies despawned mid-wave — targeting clears; attack stops without crash
- [ ] Two structures placed — both target independently
- [ ] `CleanupAllCommand` on empty world — no error
- [ ] Unknown structureType in record — `RegisterStructureCommand` returns Err; no entity created

### Security
- [ ] No Client remotes on StructureContext
- [ ] `StructureAttacked` is a BindableEvent (server-internal), not a RemoteEvent
- [ ] `RegisterStructureCommand` not callable from any client path

### Performance
- [ ] `GetAliveEnemies()` called once per tick (not per structure)
- [ ] Position cache built once per tick
- [ ] Phase 2 counts (<=5 structures, <=20 enemies): targeting loop < 0.5ms

---

## Critical Files

| File | Action |
|---|---|
| `src/ServerScriptService/Contexts/Placement/PlacementContext.lua` | Modify — add StructurePlaced signal |
| `src/ReplicatedStorage/Contexts/Structure/Config/StructureConfig.lua` | Create |
| `src/ReplicatedStorage/Contexts/Structure/Types/StructureTypes.lua` | Create |
| `src/ServerScriptService/Contexts/Structure/Errors.lua` | Create |
| `src/ServerScriptService/Contexts/Structure/Infrastructure/ECS/StructureECSWorldService.lua` | Create |
| `src/ServerScriptService/Contexts/Structure/Infrastructure/ECS/StructureComponentRegistry.lua` | Create |
| `src/ServerScriptService/Contexts/Structure/Infrastructure/ECS/StructureEntityFactory.lua` | Create |
| `src/ServerScriptService/Contexts/Structure/Infrastructure/Services/StructureTargetingSystem.lua` | Create |
| `src/ServerScriptService/Contexts/Structure/Infrastructure/Services/StructureAttackSystem.lua` | Create |
| `src/ServerScriptService/Contexts/Structure/StructureDomain/Specs/StructureSpecs.lua` | Create |
| `src/ServerScriptService/Contexts/Structure/StructureDomain/Policies/RegisterStructurePolicy.lua` | Create |
| `src/ServerScriptService/Contexts/Structure/Application/Commands/RegisterStructureCommand.lua` | Create |
| `src/ServerScriptService/Contexts/Structure/Application/Commands/CleanupAllCommand.lua` | Create |
| `src/ServerScriptService/Contexts/Structure/Application/Queries/GetActiveStructuresQuery.lua` | Create |
| `src/ServerScriptService/Contexts/Structure/Application/Queries/GetStructureCountQuery.lua` | Create |
| `src/ServerScriptService/Contexts/Structure/StructureContext.lua` | Create |

---

## Reusable Utilities

| Utility | Path | Usage |
|---|---|---|
| `Registry` | `src/ReplicatedStorage/Utilities/Registry.lua` | Module lifecycle in KnitInit |
| `Result` | `src/ReplicatedStorage/Utilities/Result.lua` | Command return values |
| `WrapContext` | `src/ReplicatedStorage/Utilities/WrapContext.lua` | Error boundary on Knit service |
| JECS | `ReplicatedStorage.Packages.JECS` | ECS world + components |
| Knit | `ReplicatedStorage.Packages.Knit` | Service registration + cross-context calls |

---

## Recommended Build Order

Steps 1 + 2 (Config + Types + Errors) — unblocked, parallel.
Steps 3 + 4 (ECSWorldService + ComponentRegistry) — parallel.
Step 5 (EntityFactory) — depends on Step 4.
Step 6 (Specs + Policy) — depends on Step 1.
Steps 7 + 8 (Commands + Queries) — depend on Steps 5 + 6.
Steps 9 + 10 (TargetingSystem + AttackSystem) — depend on Step 5.
Step 11 (Modify PlacementContext) — unblocked; do anytime.
Step 12 (StructureContext) — depends on all above.
