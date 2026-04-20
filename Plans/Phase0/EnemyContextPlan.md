# EnemyContext — Implementation Plan

## Context

The GDD defines a sci-fi hybrid RTS wave-defense on a single lane. The WorldContext plan (WorldPlan.md) establishes the foundational tile grid, spawn points, goal point, and resource side pockets. EnemyContext is the next layer: it owns enemy entities, their lane movement, health/death lifecycle, death position events for resource-drop systems, target-preference metadata for future structure/extractor attackers, and Workspace model synchronization. No wave spawning logic lives here — that belongs to a future WaveContext. EnemyContext is the raw entity layer that WaveContext will call into.

The import project (src/Imports/) provides a proven structural reference: JECS world + ComponentRegistry + EntityFactory + ModelFactory + SyncService + Application Commands, all wired through a Knit service using the Registry pattern. This plan mirrors that structure, adapted for the RTS lane-defense domain (SimplePath waypoint marching along WorldContext tiles, no player-isolation since there is one shared run, Swarm + Tank roles only in Phase 1).

**User decisions:**
- Pathfinding: SimplePath (same as import)
- Models: R6 models in Workspace at spawn time
- Enemy roles: Swarm + Tank only (Phase 1)
- ECS world: EnemyContext owns its own isolated JECS world
- GDD update: resource buildings/extractors can be enemy targets later; Phase 1 enemies may still path to the goal, but role/config data must not prevent structure/extractor targeting in later phases.

---

## Goal

Build a server-authoritative `EnemyContext` that:
1. Owns a dedicated JECS world for enemy entities
2. Registers ECS components for enemy data (Health, Position, Role, PathState, ModelRef, AliveTag)
3. Spawns enemy entities + R6 models at WorldContext spawn points
4. Moves enemies along the lane using SimplePath marching through WorldContext tile waypoints
5. Handles death (HP → 0): destroys model, removes entity from ECS world
6. Emits death facts with role, wave number, and death CFrame for WaveContext counting and future resource pickup/drop systems
7. Fires `GoalReached` signal when an enemy reaches the goal point
8. Exposes a server-to-server query API for future WaveContext and ScoringContext

---

## Short Action Flow

```
Server starts
  → Knit discovers EnemyContext
  → EnemyContext:KnitInit()
      → EnemyECSWorldService creates dedicated JECS world
      → EnemyComponentRegistry registers all components
      → EnemyEntityFactory, EnemyModelFactory, EnemySyncService, EnemyMovementSystem initialized via Registry
  → EnemyContext:KnitStart()
      → WorldContext = Knit.GetService("WorldContext")
      → self._waypoints = _BuildWaypoints(WorldContext)
      → ServerScheduler registers EnemyMovement, EnemyPositionPoll, EnemySync systems

WaveContext (future) calls:
  EnemyContext:SpawnEnemy(enemyType, spawnCFrame) → Result<entity>
    → SpawnEnemy command
        → EnemySpawnPolicy validates type + CFrame
        → EnemyEntityFactory:CreateEnemy() → JECS entity with waypoints set
        → EnemyModelFactory:CreateEnemyModel() → R6 model in Workspace/Enemies
        → EnemyEntityFactory:SetModelRef(entity, model)
        → EnemySyncService:RegisterEntity(entity)
    → returns Ok(entity)

Per-Heartbeat:
  EnemyMovementSystem:Tick()
    → QueryAliveEntities → for each: advance SimplePath toward next waypoint
    → on waypoint reached: increment index; if past last waypoint → MarkGoalReached + fire signal
  EnemySyncService:PollPositions()
    → read model:GetPivot() → write PositionComponent
  EnemySyncService:SyncDirtyEntities()
    → for DirtyTag entities: set AnimationState attribute on model; remove DirtyTag

CombatContext (future) calls:
  EnemyContext:ApplyDamage(entity, amount) → Result<boolean>
    → EnemyEntityFactory:ApplyDamage → reduce HP
    → if HP ≤ 0 → read death CFrame + identity/wave metadata → emit Wave.EnemyDied(role, waveNumber, deathCFrame) → DespawnEnemy:Execute(entity)

EnemyContext:GetAliveEnemies() → { entity }       (WaveContext: wave completion check)
EnemyContext:GetGoalReachedEnemies() → { entity }  (RunContext: run-end condition)
```

---

## Assumptions

- WorldContext is available via `Knit.GetService("WorldContext")` before EnemyContext:KnitStart() — Knit ordering covers this.
- Physical lane exists in Studio Workspace as a `World` folder (placed manually). Enemy models go in `Workspace.Enemies` (created at runtime).
- Waypoints are extracted from WorldContext tile grid: lane tiles sorted by column, center row, from spawn side to goal side. WorldContext:GetGoalPoint().Position is appended as the final waypoint.
- SimplePath is available at `ReplicatedStorage.Utilities.SimplePath`.
- Promise and Janitor are at `ReplicatedStorage.Packages.Promise` and `.Packages.Janitor`.
- Enemy models are placeholder R6 rigs cloned from `ReplicatedStorage.Assets.Enemies[role]` (must be placed in Studio beforehand).
- ServerScheduler is at `ServerScriptService.Scheduler.ServerScheduler`.
- No client replication code needed — Roblox replicates Workspace.Enemies models automatically.
- `GoalReached` and `EnemyDied` are BindableEvents (server-internal signals, not RemoteEvents).
- Enemy identity/path components include `WaveNumber` and `TargetPreference` metadata. Phase 1 uses target preference `"Goal"` for Swarm/Tank, but future roles can use `"Structure"` or `"Extractor"` without reshaping the entity model.
- PathfindingHelper is copied from import to `src/ReplicatedStorage/Utilities/PathfindingHelper.lua`.

---

## Ambiguities Resolved

| Question | Decision |
|---|---|
| Does EnemyContext need a JECS world? | Yes — own isolated world, mirrors CombatECSWorldService |
| How do enemies navigate? | SimplePath following tile-grid waypoints from WorldContext |
| What is the waypoint sequence? | WorldContext tile grid lane tiles sorted col ascending, center row, + goal CFrame appended |
| Who calls SpawnEnemy? | Future WaveContext calls EnemyContext:SpawnEnemy() |
| Who applies damage? | Future CombatContext calls EnemyContext:ApplyDamage() |
| Where do models live in Workspace? | Workspace.Enemies folder (flat — single shared run, no per-user isolation) |
| Phase 1 roles? | Swarm (fast, low HP) and Tank (slow, high HP) only |
| Do Phase 1 enemies target structures? | No — but config/component fields must allow future structure/extractor target roles. |
| Client remotes? | None — Roblox model replication handles visual sync automatically |

---

## Files to Create / Modify

### Modify
- `src/ReplicatedStorage/Utilities/PathfindingHelper.lua` — copy from `src/Imports/Combat/Executors/Helpers/PathfindingHelper.lua`

### Create (Shared / ReplicatedStorage)
```
src/ReplicatedStorage/Contexts/Enemy/
  Config/
    EnemyConfig.lua            ← Role definitions: Swarm + Tank stats, move speed
    EnemyMovementConfig.lua    ← SimplePath agent params, arrival threshold
  Types/
    EnemyTypes.lua             ← EnemyRole, EnemyId, component type exports
```

### Create (Server)
```
src/ServerScriptService/Contexts/Enemy/
  EnemyContext.lua
  Errors.lua
  Application/
    Commands/
      SpawnEnemy.lua           ← validate → create entity with wave/target metadata → create model → register sync
      DespawnEnemy.lua         ← cancel path, destroy model, delete entity
  EnemyDomain/
    Policies/
      EnemySpawnPolicy.lua
    Specs/
      EnemySpecs.lua
  Infrastructure/
    ECS/
      EnemyECSWorldService.lua
      EnemyComponentRegistry.lua
      EnemyEntityFactory.lua
    Services/
      EnemyModelFactory.lua
      EnemyMovementSystem.lua
      EnemySyncService.lua
```

---

## Implementation Plan

### Step 1 — EnemyConfig + EnemyMovementConfig + EnemyTypes (Shared)

**Objective:** Define all constants and types before any server code depends on them.

**Files:**
- `src/ReplicatedStorage/Contexts/Enemy/Config/EnemyConfig.lua`
- `src/ReplicatedStorage/Contexts/Enemy/Config/EnemyMovementConfig.lua`
- `src/ReplicatedStorage/Contexts/Enemy/Types/EnemyTypes.lua`

**EnemyConfig.lua tasks:**
- Export table keyed by `EnemyRole` string:
  - `"Swarm"`: `{ DisplayName="Swarm", BaseHP=30, BaseATK=8, BaseDEF=2, MoveSpeed=16 }`
  - `"Tank"`: `{ DisplayName="Tank", BaseHP=120, BaseATK=20, BaseDEF=10, MoveSpeed=6 }`
- `table.freeze`

**EnemyMovementConfig.lua tasks:**
- `WAYPOINT_ARRIVAL_THRESHOLD = 2` (studs)
- `SWARM_AGENT_PARAMS = { AgentRadius=1.5, AgentHeight=5, AgentCanJump=false }`
- `TANK_AGENT_PARAMS = { AgentRadius=2.5, AgentHeight=6, AgentCanJump=false }`
- `table.freeze`

**EnemyTypes.lua tasks:**
- `export type EnemyRole = "Swarm" | "Tank"`
- `export type EnemyId = string`
- `export type THealthComponent = { Current: number, Max: number }`
- `export type TPositionComponent = { CFrame: CFrame }`
- `export type TEnemyRoleComponent = { Role: EnemyRole, MoveSpeed: number, TargetPreference: string }`
- `export type TPathStateComponent = { WaypointIndex: number, Waypoints: { Vector3 }, PathPromise: any?, Arrived: boolean }`
- `export type TModelRefComponent = { Instance: Model }`
- `export type TIdentityComponent = { EnemyId: EnemyId, EnemyType: EnemyRole, WaveNumber: number? }`

**Trigger:** Manual (prerequisite for all server steps).
**Exit criteria:** All modules require without error under `--!strict`.

---

### Step 2 — Copy PathfindingHelper

**Objective:** Make the shared pathfinding utility available outside the Imports folder.

**Task:** Copy `src/Imports/Combat/Executors/Helpers/PathfindingHelper.lua` to `src/ReplicatedStorage/Utilities/PathfindingHelper.lua`. No content changes — file is already correct.

**Exit criteria:** `require(ReplicatedStorage.Utilities.PathfindingHelper)` works.

---

### Step 3 — EnemyECSWorldService

**Objective:** Create and own an isolated JECS world for enemy entities. Mirrors `CombatECSWorldService` exactly.

**File:** `src/ServerScriptService/Contexts/Enemy/Infrastructure/ECS/EnemyECSWorldService.lua`

**Tasks:**
- `EnemyECSWorldService.new()` — creates `JECS.World.new()`, stores as `self.World`
- `GetWorld(): any` — returns world instance
- No `Init` hook needed (world created in constructor)

**Exit criteria:** `.new():GetWorld()` returns a live JECS world.

---

### Step 4 — EnemyComponentRegistry

**Objective:** Register all ECS components in the world. Called via `registry:InitAll()`.

**File:** `src/ServerScriptService/Contexts/Enemy/Infrastructure/ECS/EnemyComponentRegistry.lua`

**Tasks:**
- `EnemyComponentRegistry.new()` → instance
- `Init(registry)` lifecycle hook:
  - `local world = registry:Get("World")`
  - Register + name each component via `world:component()` + `world:set(comp, JECS.Name, "...")`:
    - `HealthComponent` (`THealthComponent`)
    - `PositionComponent` (`TPositionComponent`)
    - `RoleComponent` (`TEnemyRoleComponent`)
    - `PathStateComponent` (`TPathStateComponent`)
    - `ModelRefComponent` (`TModelRefComponent`)
    - `IdentityComponent` (`TIdentityComponent`)
    - `AliveTag` — no data, alive entity filter
    - `DirtyTag` — no data, marks entities needing model sync
    - `GoalReachedTag` — no data, marks entities that reached the goal

**Export type:** Typed export matching `TCombatComponentRegistry` pattern from import.
**Exit criteria:** All components accessible after `Init`; no JECS errors.

---

### Step 5 — EnemyEntityFactory

**Objective:** Create, query, and mutate enemy entities in the JECS world.

**File:** `src/ServerScriptService/Contexts/Enemy/Infrastructure/ECS/EnemyEntityFactory.lua`

**Tasks:**
- `EnemyEntityFactory.new()` → instance
- `Init(registry)`: store `self.World`, `self.Components`

**Methods:**
- `CreateEnemy(enemyId: EnemyId, enemyType: EnemyRole, spawnCFrame: CFrame, waveNumber: number?): entity`
  - `world:entity()`
  - Set `HealthComponent`, `PositionComponent`, `RoleComponent` (from EnemyConfig), `IdentityComponent`
  - Set `PathStateComponent = { WaypointIndex=1, Waypoints={}, PathPromise=nil, Arrived=false }`
  - Add `AliveTag`
  - Return entity
- `SetModelRef(entity, model: Model)` → sets `ModelRefComponent`, adds `DirtyTag`
- `SetWaypoints(entity, waypoints: { Vector3 })` → updates `PathStateComponent.Waypoints`
- `SetWaypointIndex(entity, index: number)` → updates `PathStateComponent.WaypointIndex`
- `SetPathPromise(entity, promise: any?)` → stores active promise in `PathStateComponent.PathPromise`
- `MarkGoalReached(entity)` → adds `GoalReachedTag`, removes `AliveTag`
- `ApplyDamage(entity, amount: number): boolean` — reduce `HealthComponent.Current`; return `true` if HP ≤ 0
- `GetDeathCFrame(entity): CFrame?` — returns model pivot if available, otherwise PositionComponent CFrame
- `UpdatePosition(entity, cframe: CFrame)` → mutates `PositionComponent.CFrame`
- `IsAlive(entity): boolean` → `world:has(entity, AliveTag)`
- `GetPosition(entity): TPositionComponent?`
- `GetModelRef(entity): TModelRefComponent?`
- `GetPathState(entity): TPathStateComponent?`
- `GetIdentity(entity): TIdentityComponent?`
- `GetRole(entity): TEnemyRoleComponent?`
- `QueryAliveEntities(): { entity }` → `world:query(AliveTag)` collect
- `QueryGoalReachedEntities(): { entity }` → `world:query(GoalReachedTag)` collect
- `DeleteEntity(entity)` → `world:delete(entity)`

**Guards:** Bounds-check WaypointIndex before access; nil-check entity before get/set.
**Exit criteria:** `CreateEnemy` produces entity with correct components; `ApplyDamage` returns `true` at HP ≤ 0.

---

### Step 6 — EnemyModelFactory

**Objective:** Create R6 enemy models in `Workspace.Enemies`, update positions, destroy on death.

**File:** `src/ServerScriptService/Contexts/Enemy/Infrastructure/Services/EnemyModelFactory.lua`

**Tasks:**
- `EnemyModelFactory.new()` → instance
- `Init(registry)` — no registry dependencies
- `_GetEnemiesFolder(): Folder` — `findOrCreateFolder(Workspace, "Enemies")`
- `_EnsureCollisionGroup()` — register `"Enemies"` collision group; set NPC self-collision false
- `CreateEnemyModel(enemyType: EnemyRole, enemyId: EnemyId): Model`
  - Clone from `ReplicatedStorage.Assets.Enemies[enemyType]`
  - Set `model.Name = enemyType .. "_" .. enemyId`
  - Apply collision group to all BaseParts
  - Parent to `Workspace.Enemies`
  - Return model
- `UpdatePosition(model: Model, cframe: CFrame)` → `model:PivotTo(cframe)`
- `GetModelPosition(model: Model): Vector3?` → `model:GetPivot().Position`
- `DestroyModel(model: Model)` → `model:Destroy()`

**Roblox APIs:** `PhysicsService`, `Workspace`, `Instance.new("Folder")`
**Exit criteria:** Model appears in `Workspace.Enemies`; destroyed after `DestroyModel`.

---

### Step 7 — EnemySyncService

**Objective:** Sync ECS PositionComponent ← model position (poll), and sync anim attribute → model (dirty). Mirrors `NPCGameObjectSyncService`.

**File:** `src/ServerScriptService/Contexts/Enemy/Infrastructure/Services/EnemySyncService.lua`

**Tasks:**
- `EnemySyncService.new()`:
  - `self.EntityToInstance = {}` — entity → Model map
  - `self.InstanceToEntity = {}` — Model → entity map
- `Init(registry)`: store `World`, `Components`, `EnemyEntityFactory`, `EnemyModelFactory`
- `RegisterEntity(entity)` — read ModelRefComponent; populate both maps
- `PollPositions()` — for each entity in `EntityToInstance`: read `model:GetPivot()`, call `EnemyEntityFactory:UpdatePosition(entity, cf)`
- `SyncDirtyEntities()` — query `DirtyTag`; set `model:SetAttribute("AnimationState", ...)` (default "Walk"); remove `DirtyTag`
- `DeleteEntity(entity)` — `EnemyModelFactory:DestroyModel(model)`, clear both maps
- `CleanupAll()` — destroy all models; clear maps (called on run end)

**Position flow:** Model (SimplePath moves it) → PositionComponent (read cache). SyncService never moves the model.
**Exit criteria:** `PollPositions()` updates PositionComponent from model; `SyncDirtyEntities()` clears DirtyTag.

---

### Step 8 — EnemySpecs + EnemySpawnPolicy

**Objective:** Domain validation for spawn parameters.

**Files:**
- `src/ServerScriptService/Contexts/Enemy/EnemyDomain/Specs/EnemySpecs.lua`
- `src/ServerScriptService/Contexts/Enemy/EnemyDomain/Policies/EnemySpawnPolicy.lua`

**EnemySpecs tasks:**
- `IsValidEnemyType(enemyType): boolean` — `EnemyConfig[enemyType] ~= nil`
- `HasValidSpawnCFrame(spawnCFrame): boolean` — `typeof(spawnCFrame) == "CFrame"`

**EnemySpawnPolicy tasks:**
- `EnemySpawnPolicy.new()`
- `Check(enemyType, spawnCFrame): Result` — runs both specs; returns `Err` with `Errors.INVALID_ENEMY_TYPE` or `Errors.INVALID_SPAWN_CFRAME` on failure; `Ok(true)` on pass

**Exit criteria:** `Check("Swarm", CFrame.new())` → Ok; `Check("Invalid", ...)` → Err.

---

### Step 9 — Errors.lua

**File:** `src/ServerScriptService/Contexts/Enemy/Errors.lua`

**Tasks:**
- `INVALID_ENEMY_TYPE = "EnemyContext: invalid enemy type"`
- `INVALID_SPAWN_CFRAME = "EnemyContext: invalid spawn CFrame"`
- `ENTITY_CREATION_FAILED = "EnemyContext: entity creation failed"`
- `MODEL_CREATION_FAILED = "EnemyContext: model creation failed"`
- `table.freeze`

**Exit criteria:** All constants importable.

---

### Step 10 — SpawnEnemy + DespawnEnemy Commands

**Objective:** Application-layer orchestration for entity + model lifecycle.

**Files:**
- `src/ServerScriptService/Contexts/Enemy/Application/Commands/SpawnEnemy.lua`
- `src/ServerScriptService/Contexts/Enemy/Application/Commands/DespawnEnemy.lua`

**SpawnEnemy tasks:**
- `SpawnEnemy.new()` → instance
- `Init(registry)`: store `EnemySpawnPolicy`, `EnemyEntityFactory`, `EnemyModelFactory`, `EnemySyncService`
- `Execute(enemyType: EnemyRole, spawnCFrame: CFrame, waypoints: { Vector3 }, waveNumber: number?): Result<entity>`
  1. `Try(self.EnemySpawnPolicy:Check(enemyType, spawnCFrame))`
  2. `local enemyId = HttpService:GenerateGUID(false)`
  3. `local entity = self.EnemyEntityFactory:CreateEnemy(enemyId, enemyType, spawnCFrame, waveNumber)`
  4. `self.EnemyEntityFactory:SetWaypoints(entity, waypoints)`
  5. `fromPcall(...)` → create model → `UpdatePosition(model, spawnCFrame)` → `SetModelRef(entity, model)` → `EnemySyncService:RegisterEntity(entity)`
  6. `MentionSuccess(...)` → `return Ok(entity)`

**DespawnEnemy tasks:**
- `Execute(entity): Result<boolean>`
  1. Read `pathState = EnemyEntityFactory:GetPathState(entity)`; if `pathState.PathPromise`, call `pathState.PathPromise:cancel()`
  2. `self.EnemySyncService:DeleteEntity(entity)` — destroys model, cleans maps
  3. `self.EnemyEntityFactory:DeleteEntity(entity)` — removes from JECS world
  4. Return `Ok(true)`

**Exit criteria:** `SpawnEnemy:Execute("Swarm", CFrame.new(), {...})` → Ok(entity); model visible in Workspace.Enemies. `DespawnEnemy` cleans up cleanly with no leaks.

---

### Step 11 — EnemyMovementSystem

**Objective:** Per-Heartbeat system advancing each alive enemy along its waypoint list via SimplePath.

**File:** `src/ServerScriptService/Contexts/Enemy/Infrastructure/Services/EnemyMovementSystem.lua`

**Tasks:**
- `EnemyMovementSystem.new()` → instance
- `Init(registry)`: store `World`, `Components`, `EnemyEntityFactory`, `EnemyModelFactory`
- `Start(registry)`: `self._onGoalReached = registry:Get("OnGoalReachedCallback")` — injected by EnemyContext in KnitStart
- `Tick()`:
  - `local aliveEntities = self.EnemyEntityFactory:QueryAliveEntities()`
  - For each entity: `self:_AdvanceEntity(entity)`
- `_AdvanceEntity(entity)`:
  - Read `pathState = EnemyEntityFactory:GetPathState(entity)`
  - If `pathState.Arrived` → skip
  - If `pathState.PathPromise == nil` → `_StartNextWaypoint(entity, pathState)`
  - If `pathState.PathPromise.Status == Promise.Status.Resolved`:
    - `local nextIndex = pathState.WaypointIndex + 1`
    - `EnemyEntityFactory:SetPathPromise(entity, nil)`
    - If `nextIndex > #pathState.Waypoints` → `EnemyEntityFactory:MarkGoalReached(entity)`; call `self._onGoalReached(entity)`; return
    - Else → `EnemyEntityFactory:SetWaypointIndex(entity, nextIndex)`; `_StartNextWaypoint(entity, updated pathState)`
  - If `pathState.PathPromise.Status == Promise.Status.Rejected` → `EnemyEntityFactory:SetPathPromise(entity, nil)` (will retry next tick)
- `_StartNextWaypoint(entity, pathState)`:
  - `local target = pathState.Waypoints[pathState.WaypointIndex]`
  - `local roleComp = EnemyEntityFactory:GetRole(entity)` → pick agent params from EnemyMovementConfig based on role
  - `local agentParams = roleComp.Role == "Tank" and EnemyMovementConfig.TANK_AGENT_PARAMS or EnemyMovementConfig.SWARM_AGENT_PARAMS`
  - `local path = PathfindingHelper.CreatePath(entity, { NPCEntityFactory = self.EnemyEntityFactory }, agentParams)`
  - If path is nil → skip (model not ready)
  - `local promise = PathfindingHelper.RunPath(path, target)`
  - `EnemyEntityFactory:SetPathPromise(entity, promise)`

**Performance:** Promise.Status check is O(1); alive entity query is the only JECS iteration per frame.
**Exit criteria:** Enemy model moves tile by tile from spawn toward goal; `MarkGoalReached` fires when last waypoint resolved.

---

### Step 12 — EnemyContext Knit Service

**Objective:** Wire all services. Expose public server API. Register scheduler systems.

**File:** `src/ServerScriptService/Contexts/Enemy/EnemyContext.lua`

**KnitInit():**
- Create `Registry.new("Enemy")`
- Create `EnemyECSWorldService.new()`; register world: `registry:Register("World", ecsWorldService:GetWorld())`
- Register:
  - `EnemyComponentRegistry.new()` under `"Infrastructure"`
  - `EnemyEntityFactory.new()` under `"Infrastructure"`
  - `EnemyModelFactory.new()` under `"Infrastructure"`
  - `EnemySyncService.new()` under `"Infrastructure"`
  - `EnemyMovementSystem.new()` under `"Infrastructure"`
  - `EnemySpawnPolicy.new()` under `"Domain"`
  - `SpawnEnemy.new()` under `"Application"`
  - `DespawnEnemy.new()` under `"Application"`
- Create `self._goalReachedSignal = Instance.new("BindableEvent")`
- Register callback: `registry:Register("OnGoalReachedCallback", function(entity) self._goalReachedSignal:Fire(entity) end)`
- `registry:InitAll()`
- Cache refs: `self._spawnEnemy`, `self._despawnEnemy`, `self._entityFactory`, `self._syncService`, `self._movementSystem`
- `self.GoalReached = self._goalReachedSignal.Event` — public signal for RunContext

**KnitStart():**
- `local WorldContext = Knit.GetService("WorldContext")`
- `self._waypoints = self:_BuildWaypoints(WorldContext)` — see Waypoint Building section below
- `ServerScheduler:RegisterSystem(function() self._movementSystem:Tick() end, "EnemyMovement")`
- `ServerScheduler:RegisterSystem(function() self._syncService:PollPositions() end, "EnemyPositionPoll")`
- `ServerScheduler:RegisterSystem(function() self._syncService:SyncDirtyEntities() end, "EnemySync")`

**`_BuildWaypoints(WorldContext): { Vector3 }`:**
1. `local allTiles = WorldContext:GetAllTiles()`
2. Filter: `tile.zone == "lane"`
3. Find center row: pick most-common row, or middle row index
4. Filter to center row only
5. Sort by `tile.coord.col` ascending
6. Map to `tile.worldPos` Vector3 array
7. Append `WorldContext:GetGoalPoint().Position` as final entry

**Public API (server-to-server via Knit.GetService):**
- `EnemyContext:SpawnEnemy(enemyType, spawnCFrame, waveNumber: number?): Result<entity>` → calls `SpawnEnemy:Execute(enemyType, spawnCFrame, self._waypoints, waveNumber)`
- `EnemyContext:DespawnEnemy(entity): Result<boolean>`
- `EnemyContext:ApplyDamage(entity, amount: number): Result<boolean>` — `EnemyEntityFactory:ApplyDamage`; if dead → emit death event with role/wave/deathCFrame, then `DespawnEnemy:Execute(entity)`
- `EnemyContext:GetAliveEnemies(): { entity }` — `EnemyEntityFactory:QueryAliveEntities()`
- `EnemyContext:GetGoalReachedEnemies(): { entity }` — `EnemyEntityFactory:QueryGoalReachedEntities()`
- `EnemyContext:GetEnemyCount(): number`
- `EnemyContext:CleanupAll()` — calls `EnemySyncService:CleanupAll()` (run end cleanup)

No `Client` remotes in Phase 1.

**Bottom of file:** `WrapContext(EnemyContext, "EnemyContext")`

**Exit criteria:** Server starts cleanly. `SpawnEnemy("Swarm", ...)` returns Ok(entity). Enemy moves in Studio. `ApplyDamage` to 0 despawns model and entity. `GoalReached` signal fires at last waypoint.

---

## Waypoint Building Strategy

`_BuildWaypoints` in `KnitStart` (after WorldContext is available):
1. Call `WorldContext:GetAllTiles()` — returns flat `{ Tile }` array
2. Filter tiles where `tile.zone == "lane"`
3. Find the center row: collect unique row values, pick `math.floor(count/2) + 1` index
4. Filter to tiles with that center row only
5. Sort by `tile.coord.col` ascending
6. Map to `tile.worldPos` Vector3 array
7. Append `WorldContext:GetGoalPoint().Position` as final destination

Every enemy follows the same path. Spawn CFrame is passed separately (from WorldContext:GetSpawnPoints()) and is the initial model position.

---

## Reusable Utilities

| Utility | Path | Usage |
|---|---|---|
| Registry | `src/ReplicatedStorage/Utilities/Registry.lua` | Module lifecycle in KnitInit |
| Result | `src/ReplicatedStorage/Utilities/Result.lua` | Command return values |
| PathfindingHelper | `src/ReplicatedStorage/Utilities/PathfindingHelper.lua` | Lane movement (copy from Imports) |
| SimplePath | `ReplicatedStorage.Utilities.SimplePath` | Used by PathfindingHelper |
| Promise | `ReplicatedStorage.Packages.Promise` | Async pathfinding in PathfindingHelper |
| Janitor | `ReplicatedStorage.Packages.Janitor` | Cleanup in PathfindingHelper |
| JECS | `ReplicatedStorage.Packages.JECS` | ECS world and components |
| WrapContext | `ReplicatedStorage.Utilities.WrapContext` | Error boundary on Knit service |
| HttpService | Roblox service | `GenerateGUID` for enemy IDs |

---

## Validation Checklist

### Functional
- [ ] Server starts cleanly after EnemyContext is added
- [ ] `SpawnEnemy("Swarm", spawnCFrame)` returns `Ok(entity)`; model appears in `Workspace.Enemies`
- [ ] Enemy model moves from spawn toward goal tile by tile
- [ ] `ApplyDamage(entity, 999)` returns `Ok(true)`; model destroyed; entity removed from JECS world
- [ ] Enemy death emits `Wave.EnemyDied(role, waveNumber, deathCFrame)` before model/entity cleanup
- [ ] `GetAliveEnemies()` count decreases after death
- [ ] `GoalReached` signal fires when enemy reaches final waypoint
- [ ] Swarm/Tank role config stores target preference `"Goal"` while allowing future `"Structure"` / `"Extractor"` roles
- [ ] `DespawnEnemy(entity)` destroys model and removes entity cleanly

### Edge Cases
- [ ] `SpawnEnemy("Invalid", ...)` returns `Err` (invalid type)
- [ ] `ApplyDamage` on already-dead entity does not error
- [ ] SimplePath rejected (blocked path) → entity retries next tick without crash
- [ ] Zero waypoints built (WorldContext returns empty lane) → enemy stays at spawn without crash
- [ ] `DespawnEnemy` with active PathPromise cancels the promise cleanly
- [ ] `CleanupAll()` destroys all models and clears JECS world entries

### Security
- [ ] No Client remotes on EnemyContext in Phase 1
- [ ] `ApplyDamage` and `SpawnEnemy` are not accessible from any RemoteEvent
- [ ] Enemy HP is never set from client side

### Performance
- [ ] 20 simultaneous enemies: Heartbeat budget stays under 1ms for movement + sync systems
- [ ] Model creation is one-time per spawn (not per-frame)
- [ ] `QueryAliveEntities()` only iterates entities with AliveTag

---

## Critical Files

| File | Action |
|---|---|
| `src/ReplicatedStorage/Utilities/PathfindingHelper.lua` | Copy from Imports |
| `src/ReplicatedStorage/Contexts/Enemy/Config/EnemyConfig.lua` | Create |
| `src/ReplicatedStorage/Contexts/Enemy/Config/EnemyMovementConfig.lua` | Create |
| `src/ReplicatedStorage/Contexts/Enemy/Types/EnemyTypes.lua` | Create |
| `src/ServerScriptService/Contexts/Enemy/Errors.lua` | Create |
| `src/ServerScriptService/Contexts/Enemy/Infrastructure/ECS/EnemyECSWorldService.lua` | Create |
| `src/ServerScriptService/Contexts/Enemy/Infrastructure/ECS/EnemyComponentRegistry.lua` | Create |
| `src/ServerScriptService/Contexts/Enemy/Infrastructure/ECS/EnemyEntityFactory.lua` | Create |
| `src/ServerScriptService/Contexts/Enemy/Infrastructure/Services/EnemyModelFactory.lua` | Create |
| `src/ServerScriptService/Contexts/Enemy/Infrastructure/Services/EnemySyncService.lua` | Create |
| `src/ServerScriptService/Contexts/Enemy/Infrastructure/Services/EnemyMovementSystem.lua` | Create |
| `src/ServerScriptService/Contexts/Enemy/EnemyDomain/Specs/EnemySpecs.lua` | Create |
| `src/ServerScriptService/Contexts/Enemy/EnemyDomain/Policies/EnemySpawnPolicy.lua` | Create |
| `src/ServerScriptService/Contexts/Enemy/Application/Commands/SpawnEnemy.lua` | Create |
| `src/ServerScriptService/Contexts/Enemy/Application/Commands/DespawnEnemy.lua` | Create |
| `src/ServerScriptService/Contexts/Enemy/EnemyContext.lua` | Create |

---

## Recommended First Build Step

**Step 1** (Config + Types) — unblocked, no dependencies, can all be done in parallel.
**Step 2** (PathfindingHelper copy) — unblocked.
**Step 3 + 4** (ECSWorldService + ComponentRegistry) — parallel, no inter-dependency.
**Step 9** (Errors.lua) — unblocked, write alongside Step 3.
**Step 5** (EntityFactory) — depends on Step 4 (Components).
**Step 6** (ModelFactory) — depends on Step 1 (EnemyConfig for collision group name).
**Step 7** (SyncService) — depends on Steps 5 + 6.
**Step 8** (Specs + Policy) — depends on Step 1 only.
**Step 10** (SpawnEnemy + DespawnEnemy) — depends on Steps 5, 6, 7, 8.
**Step 11** (MovementSystem) — depends on Steps 2, 5.
**Step 12** (EnemyContext) — depends on all above; wires everything together.
