# Plan: Inherit Import's BT/Executor/Policy Architecture into CombatContext

## Context

The current CombatContext drives enemy movement with a raw `CombatMovementService` (Promise-based waypoint pathing). There is no decision layer — enemies just walk. The import's CombatContext has a proven per-entity Behavior Tree tick loop backed by Executors, Domain Policies, and Domain Services. The goal is to lift that architecture into this RTS's CombatContext, adapted for the lane-defense model (enemies have no attack targets; they walk toward the goal). Phase 3 requires enemy role variety (swarm, tank, disruptor) with distinct AI behaviors — the BT/Executor pattern makes that straightforward. Adventurer/hitbox/lock-on/NPC-event systems are explicitly out of scope.

---

## Assumptions

- The existing `CombatMovementService` and `ProcessCombatTick` (movement-only) will be **replaced** by the new BT tick pipeline.
- The `EnemyEntityFactory` needs new ECS components: `BehaviorTree`, `CombatAction`, `AttackCooldown`, `BehaviorConfig`. These are added to `EnemyComponentRegistry`.
- The `BehaviorTree` utility (`ReplicatedStorage/Utilities/BehaviorTree`) is already present and usable.
- Executors are **singletons** shared across all entities (per import pattern). Per-entity state lives in tables keyed by entity.
- The BT tick runs server-side only; no client remotes are involved.
- The import's `BehaviorTreeTickPolicy` manual-mode / adventurer branch is irrelevant here — simplified to: skip if action is Committed, skip if interval not elapsed.
- `WaveCompletionPolicy` from import will be adapted: "wave complete" = all enemies are dead or goal-reached (no adventurer wipe check).
- `CombatLoopService` is replaced with the import's richer version (per-userId map, IsPaused, TotalWaves fields) — the RTS is single-player but the structure is identical.

---

## Action Flow

```
WaveStarted event
  → CombatContext._OnRunWaveStarted
    → StartCombat:Execute(waveNumber, isEndless)
      → AssignBehaviorTree per enemy entity (BehaviorTreeFactory)
      → SetBehaviorConfig per entity from EnemyConfig role defaults
      → CombatLoopService:StartCombat(waveNumber)

ServerScheduler CombatTick (every frame)
  → ProcessCombatTick:Execute()
    → Phase 1: BehaviorTreeTickPolicy:Check(entity, time) per alive entity
        → if passes → BT.run(perceptionCtx) → SetPendingAction
    → Phase 2: ActionTransition per entity
        → cancel current executor, start pending executor
    → Phase 3: ActionTick per entity
        → executor:Tick() → "Running" | "Success" | "Fail"
        → on goal reached → HandleGoalReached (existing command, unchanged)
    → Phase 4: WaveCompletionPolicy:Check()
        → all enemies dead/goal-reached → emit Run.WaveEnded

EnemySpawned event (mid-wave, e.g. next wave or re-spawn)
  → assign BehaviorTree + BehaviorConfig to new entity
  → LaneAdvanceExecutor picks up from waypoint 1
```

---

## File / Module Layout

### New files to create

| Path | Purpose |
|---|---|
| `src/ServerScriptService/Contexts/Combat/CombatDomain/Policies/BehaviorTreeTickPolicy.lua` | Gates BT ticks: checks Committed state + tick interval |
| `src/ServerScriptService/Contexts/Combat/CombatDomain/Policies/WaveCompletionPolicy.lua` | Checks if all alive enemies are gone; emits wave complete |
| `src/ServerScriptService/Contexts/Combat/CombatDomain/Services/CombatPerceptionService.lua` | Builds per-entity perception snapshot for BT context |
| `src/ServerScriptService/Contexts/Combat/Infrastructure/Services/BehaviorTreeFactory.lua` | Maps enemy role strings to BT module; creates tree instances |
| `src/ServerScriptService/Contexts/Combat/Executors/Base/BaseExecutor.lua` | Default no-op Start/Tick/Cancel/Complete; all executors extend this |
| `src/ServerScriptService/Contexts/Combat/Executors/Base/ExecutorRegistry.lua` | Maps actionId string → executor singleton |
| `src/ServerScriptService/Contexts/Combat/Executors/LaneAdvanceExecutor.lua` | Drives the existing waypoint-pathing Promise logic; replaces raw CombatMovementService |
| `src/ServerScriptService/Contexts/Combat/Executors/IdleExecutor.lua` | No-op hold; returns "Running" every tick |
| `src/ServerScriptService/Contexts/Combat/BehaviorTrees/SwarmBehavior.lua` | BT for swarm role: LaneAdvance always |
| `src/ServerScriptService/Contexts/Combat/BehaviorTrees/TankBehavior.lua` | BT for tank role: LaneAdvance always (same as swarm for now, differentiated by config) |
| `src/ServerScriptService/Contexts/Combat/BehaviorTrees/BehaviorNodes/Conditions.lua` | RTS-adapted condition nodes (LaneBlocked, HealthLow) |
| `src/ServerScriptService/Contexts/Combat/BehaviorTrees/BehaviorNodes/Commands.lua` | Action command nodes (LaneAdvance, Idle) |
| `src/ServerScriptService/Contexts/Combat/BehaviorTrees/BehaviorNodes/init.lua` | Re-exports Conditions + Commands |
| `src/ReplicatedStorage/Contexts/Combat/Types/ExecutorTypes.lua` | `Entity`, `TActionServices`, `TExecutorConfig` shared types |
| `src/ReplicatedStorage/Contexts/Combat/Config/BehaviorConfig.lua` | Default behavior config per role (speeds, tick interval) |

### Files to modify

| Path | Change |
|---|---|
| `src/ServerScriptService/Contexts/Combat/CombatContext.lua` | Replace movement-only wiring with BT pipeline; add ExecutorRegistry, BehaviorTreeFactory, policies, perception service to registry |
| `src/ServerScriptService/Contexts/Combat/Application/Commands/StartCombat.lua` | On wave start, assign BT + BehaviorConfig to all alive enemies |
| `src/ServerScriptService/Contexts/Combat/Application/Commands/ProcessCombatTick.lua` | Replace `_movementService:Tick()` with 4-phase BT tick loop |
| `src/ServerScriptService/Contexts/Combat/Application/Commands/EndCombat.lua` | Call `ExecutorRegistry:CancelAll(entity)` on all entities before stopping loop |
| `src/ServerScriptService/Contexts/Combat/Infrastructure/Services/CombatLoopService.lua` | Replace single-session struct with per-userId map (import pattern: `IsPaused`, `TotalWaves`) |
| `src/ServerScriptService/Contexts/Enemy/Infrastructure/ECS/EnemyComponentRegistry.lua` | Register 4 new components: `BehaviorTree`, `CombatAction`, `AttackCooldown`, `BehaviorConfig` |
| `src/ServerScriptService/Contexts/Enemy/Infrastructure/ECS/EnemyEntityFactory.lua` | Add methods for new components: `GetBehaviorTree`, `SetBehaviorTree`, `GetCombatAction`, `SetPendingAction`, `StartAction`, `ClearAction`, `ResetActionState`, `GetBehaviorConfig`, `SetBehaviorConfig`, `UpdateBTLastTickTime` |
| `src/ReplicatedStorage/Contexts/Combat/Types/CombatTypes.lua` | Update `CombatSession` type to match import's `TActiveCombat` |

### Files to delete

| Path | Reason |
|---|---|
| `src/ServerScriptService/Contexts/Combat/Infrastructure/Services/CombatMovementService.lua` | Logic absorbed into `LaneAdvanceExecutor` |

---

## Implementation Steps

### Step 1 — Upgrade CombatLoopService to per-userId map

**Objective:** Replace the single `_session` struct with the import's `ActiveCombats: { [number]: TActiveCombat }` pattern. This is a prerequisite for everything else.

**Files:** `CombatLoopService.lua`, `CombatTypes.lua`

**Tasks:**
- Replace `_session` field with `ActiveCombats = {}` table keyed by userId.
- Add methods: `StartCombat(userId, waveNumber, isEndless)`, `StopCombat(userId)`, `PauseCombat(userId)`, `ResumeCombat(userId)`, `SetCurrentWaveNumber(userId, n)`, `IsActive(userId)`, `GetActiveCombat(userId)`, `GetActiveCombats()`.
- `TActiveCombat` type: `{ waveNumber: number, isEndless: boolean, IsPaused: boolean }`. No `onComplete` needed (RTS events handle resolution).
- Update `CombatTypes.lua` `CombatSession` to match.
- Update `CombatContext.KnitStart` scheduler loop: iterate `GetActiveCombats()`, skip `IsPaused` entries (mirrors import).
- Update `StartCombat` command: pass userId into `CombatLoopService:StartCombat`.
- Update `EndCombat` command: call `StopCombat(userId)`.
- Update `ProcessCombatTick` command: accept `userId` param.
- Update `HandleGoalReached` command: no change needed (already uses userId-less entity lookup).

**State changes:** CombatLoopService is now userId-aware; scheduler loop iterates active combats.

**Completion check:** Single-player run starts, ticks, and ends without errors. `IsActive(userId)` returns correct values.

---

### Step 2 — Add new ECS components to EnemyComponentRegistry + EnemyEntityFactory

**Objective:** Extend the enemy ECS with the 4 components required by the BT pipeline.

**Files:** `EnemyComponentRegistry.lua`, `EnemyEntityFactory.lua`, `ExecutorTypes.lua` (new)

**Tasks:**

**EnemyComponentRegistry:**
- Register 4 new components in `Init`: `BehaviorTree`, `CombatAction`, `AttackCooldown`, `BehaviorConfig`.
- JECS name them `"Enemy.BehaviorTree"`, `"Enemy.CombatAction"`, `"Enemy.AttackCooldown"`, `"Enemy.BehaviorConfig"`.

**Component shapes (in `ExecutorTypes.lua`):**
- `BehaviorTree`: `{ TreeInstance: any, TickInterval: number, LastTickTime: number }`
- `CombatAction`: `{ CurrentActionId: string?, ActionState: "None"|"Running"|"Committed", ActionData: any?, PendingActionId: string?, PendingActionData: any? }`
- `AttackCooldown`: `{ Cooldown: number, LastAttackTime: number }` — unused in Phase 3 but declared for schema completeness
- `BehaviorConfig`: `{ TickInterval: number }` — role-specific BT tick rate

**EnemyEntityFactory — new methods:**
- `GetBehaviorTree(entity)` / `SetBehaviorTree(entity, treeInstance, tickInterval)`
- `UpdateBTLastTickTime(entity, time)` — sets `LastTickTime` only
- `GetCombatAction(entity)` / `SetPendingAction(entity, actionId, data)` — sets `PendingActionId + PendingActionData`
- `StartAction(entity, actionId, data, time)` — sets `CurrentActionId`, `ActionState = "Running"`, clears pending
- `ClearAction(entity)` — resets `CombatAction` to all-nil / "None"
- `ResetActionState(entity)` — sets `ActionState = "None"`, keeps `CurrentActionId` for logging
- `GetBehaviorConfig(entity)` / `SetBehaviorConfig(entity, config)`

**Completion check:** `EnemyEntityFactory:SetBehaviorTree(entity, tree, 0.1)` stores and `GetBehaviorTree` retrieves correctly.

---

### Step 3 — Create BaseExecutor + ExecutorRegistry

**Objective:** Establish the executor singleton pattern used by all action executors.

**Files:** `Executors/Base/BaseExecutor.lua`, `Executors/Base/ExecutorRegistry.lua`

**Tasks:**

**BaseExecutor:**
- Fields: `Config: { ActionId: string, IsCommitted: boolean, Duration: number? }`
- Methods (all no-op defaults): `Start(entity, data, services) → (boolean, string?)`, `Tick(entity, dt, services) → string`, `Cancel(entity, services)`, `Complete(entity, services)`
- `BaseExecutor.new(config)` sets `self.Config = config`.

**ExecutorRegistry:**
- `Register(actionId, executor)` — validates `actionId` is a non-empty string, stores in `_registry` table.
- `Get(actionId) → executor?`
- `CancelAll(entity, services)` — iterates all registered executors, calls `Cancel(entity, services)` on each (guards with pcall). Used at end-of-combat cleanup.

**Completion check:** `ExecutorRegistry:Get("LaneAdvance")` returns the registered executor.

---

### Step 4 — Create LaneAdvanceExecutor + IdleExecutor

**Objective:** Implement the two executors needed for Phase 3 enemy movement.

**Files:** `Executors/LaneAdvanceExecutor.lua`, `Executors/IdleExecutor.lua`

**Tasks:**

**LaneAdvanceExecutor** (replaces CombatMovementService):
- Extends `BaseExecutor` (`IsCommitted = false`).
- Per-entity state: `_promises: { [Entity]: any }`, `_waypointIndex: { [Entity]: number }`.
- `Start(entity, data, services)`:
  - Gets `PathState` from `EnemyEntityFactory`. If no waypoints, returns `false`.
  - Reads current `waypointIndex` from PathState.
  - Calls `PathfindingHelper.CreatePath` + `PathfindingHelper.RunPath` to target `waypoints[waypointIndex]`.
  - Stores promise. Sets `EnemyEntityFactory:SetPathMoving(entity, true)`.
  - Returns `true`.
- `Tick(entity, dt, services)`:
  - Checks promise status. If `Resolved`: advance `waypointIndex`. If past end: return `"Success"` (goal reached). Else start next waypoint path.
  - If `Rejected` / `Cancelled`: return `"Fail"`.
  - Returns `"Running"` while in transit.
- On `"Success"` (goal reached): `HandleGoalReached` command is triggered by `ProcessCombatTick` (see Step 6).
- `Cancel(entity, services)`: cancel promise, `SetPathMoving(entity, false)`.
- `Complete(entity, services)`: same cleanup as `Cancel`.

**IdleExecutor:**
- Extends `BaseExecutor` (`IsCommitted = false`).
- `Tick` always returns `"Running"`. No state.

**Completion check:** Spawning a swarm enemy and starting combat causes it to path along lane waypoints identically to the old `CombatMovementService`.

---

### Step 5 — Create Domain: BehaviorTreeTickPolicy + CombatPerceptionService

**Objective:** Policy gate for BT ticks; perception snapshot builder for BT context.

**Files:** `CombatDomain/Policies/BehaviorTreeTickPolicy.lua`, `CombatDomain/Services/CombatPerceptionService.lua`

**Tasks:**

**BehaviorTreeTickPolicy** (adapted from import, adventurer/manual branch removed):
- `Init(registry)`: gets `EnemyEntityFactory`.
- `Check(entity, currentTime) → Result`:
  - Read `CombatAction`. If `ActionState == "Committed"` → `Err("Committed")`.
  - Read `BehaviorTree`. If nil → `Err("NoBT")`.
  - If `currentTime - bt.LastTickTime < bt.TickInterval` → `Err("IntervalNotReady")`.
  - Return `Ok({ BehaviorTree = bt })`.

**CombatPerceptionService** (RTS-adapted, no target-selection needed):
- `BuildSnapshot(entity, currentTime)` → returns a facts table:
  - `HasWaypoints: boolean` — entity has valid lane waypoints
  - `IsAtGoal: boolean` — waypointIndex > #waypoints (all waypoints consumed)
  - `HealthPct: number` — current/max health ratio
  - `ShouldFlee: boolean` — `HealthPct < FleeThreshold` (future disruptor hook; always false in Phase 3)
- This snapshot is passed as `ctx.Facts` into BT `run()`.
- No target queries needed (RTS enemies don't target other entities).

**Completion check:** `BehaviorTreeTickPolicy:Check(entity, os.clock())` returns `Err` on first call (interval not elapsed), `Ok` after interval passes.

---

### Step 6 — Create WaveCompletionPolicy

**Objective:** RTS-adapted completion check: wave is done when all enemies are dead or goal-reached.

**Files:** `CombatDomain/Policies/WaveCompletionPolicy.lua`

**Tasks:**
- `Init(registry)`: gets `EnemyEntityFactory`.
- `Check() → { Status: "WaveComplete" | "InProgress" }`:
  - Query `EnemyEntityFactory:QueryAliveEntities()`. If count == 0 → `"WaveComplete"`.
  - Otherwise → `"InProgress"`.
- No "PartyWiped" check (no adventurers in RTS).
- Note: `HandleGoalReached` already removes `AliveTag` and despawns the entity, so goal-reached enemies naturally fall out of the alive query.

**Completion check:** After all enemies are despawned in a wave, `WaveCompletionPolicy:Check()` returns `"WaveComplete"`.

---

### Step 7 — Create BehaviorTreeFactory + BehaviorTrees (SwarmBehavior, TankBehavior)

**Objective:** Per-role BT definitions wired through a factory.

**Files:** `Infrastructure/Services/BehaviorTreeFactory.lua`, `BehaviorTrees/SwarmBehavior.lua`, `BehaviorTrees/TankBehavior.lua`, `BehaviorTrees/BehaviorNodes/Conditions.lua`, `BehaviorTrees/BehaviorNodes/Commands.lua`, `BehaviorTrees/BehaviorNodes/init.lua`

**Tasks:**

**BehaviorNodes/Commands.lua** — action command nodes:
- `LaneAdvance()` → `Task` that calls `ctx.NPCEntityFactory:SetPendingAction(ctx.Entity, "LaneAdvance", nil)` and calls `task:success()`.
- `Idle()` → `Task` that calls `SetPendingAction(entity, "Idle", nil)` and succeeds.

**BehaviorNodes/Conditions.lua** — condition nodes (RTS-scoped):
- `HasWaypointsCondition()` → succeeds if `ctx.Facts.HasWaypoints == true`.
- `ShouldFleeCondition()` → succeeds if `ctx.Facts.ShouldFlee == true` (placeholder for disruptor).

**BehaviorNodes/init.lua** — re-exports both modules.

**SwarmBehavior.lua:**
```
Priority:
  1. Seq(HasWaypointsCondition, LaneAdvance)
  2. Idle  (fallback if no waypoints)
```

**TankBehavior.lua:**
```
Priority:
  1. Seq(HasWaypointsCondition, LaneAdvance)
  2. Idle
```
(Tank behavior is identical to swarm for Phase 3; differentiated by `BehaviorConfig.TickInterval` being slower.)

**BehaviorTreeFactory:**
- `BEHAVIOR_MAP`: `{ swarm = SwarmBehavior, tank = TankBehavior }`.
- `CreateTree(role) → BehaviourTree instance | nil`. Falls back to `SwarmBehavior` on unknown role.
- `Init()`: no-op (no registry deps).

**Config/BehaviorConfig.lua:**
- `DEFAULTS_BY_ROLE`: `{ swarm = { TickInterval = 0.1 }, tank = { TickInterval = 0.2 } }`.
- `DEFAULT = { TickInterval = 0.15 }`.

**Completion check:** `BehaviorTreeFactory:CreateTree("swarm")` returns a non-nil tree that can call `.run()`.

---

### Step 8 — Rewrite ProcessCombatTick with 4-phase BT loop

**Objective:** Replace the simple `_movementService:Tick()` call with the import's 4-phase per-entity loop.

**Files:** `Application/Commands/ProcessCombatTick.lua`

**Tasks:**

**Init:**
- Gets from registry: `CombatLoopService`, `EnemyEntityFactory`, `BehaviorTreeTickPolicy`, `WaveCompletionPolicy`, `ExecutorRegistry`, `CombatPerceptionService`.

**Execute(userId):**

**Phase 1 — BT Tick:**
- `aliveEntities = EnemyEntityFactory:QueryAliveEntities()`
- For each entity: call `BehaviorTreeTickPolicy:Check(entity, currentTime)`. If `Ok`, build `perceptionCtx` with `Facts = CombatPerceptionService:BuildSnapshot(entity, time)`, then `bt.TreeInstance:run(perceptionCtx)` (pcall-guarded). Call `UpdateBTLastTickTime(entity, time)`.

**Phase 2 — Action Transition:**
- For each alive entity: read `CombatAction`. If `PendingActionId` is set:
  - If same as `CurrentActionId`: update `ActionData`, clear pending.
  - If `ActionState == "Committed"`: discard pending.
  - Else: cancel current executor (`ExecutorRegistry:Get(CurrentActionId):Cancel`), start pending executor (`:Start`). If start fails: `ClearAction`. Else: `StartAction`.

**Phase 3 — Action Tick:**
- For each alive entity: if `ActionState` is `"Running"` or `"Committed"`:
  - `result = executor:Tick(entity, dt, services)` (pcall-guarded).
  - If `"Success"`: check if this is a `LaneAdvance` completion (goal reached) → call `_HandleGoalReached(entity)`. Call `executor:Complete`. `ResetActionState`.
  - If `"Fail"`: `ClearAction`.

**`_HandleGoalReached(entity)`:**
- Delegate directly to `HandleGoalReached:Execute(entity)` (existing command, unchanged).

**Phase 4 — Wave Completion:**
- `WaveCompletionPolicy:Check()`. If `"WaveComplete"` → emit `GameEvents.Events.Run.WaveEnded(waveNumber)`.

**services table** passed to executors:
```lua
{ NPCEntityFactory, ExecutorRegistry, CurrentTime, EventBuffer = {} }
```
No `DamageCalculator`, `HitboxService`, or `World` needed for Phase 3.

**Completion check:** Swarm enemy advances lane waypoints, triggers `HandleGoalReached` on arrival, `WaveEnded` fires after last enemy.

---

### Step 9 — Rewrite StartCombat command

**Objective:** On wave start, assign BT + BehaviorConfig to all currently alive enemies.

**Files:** `Application/Commands/StartCombat.lua`

**Tasks:**

**Init:** gets `CombatLoopService`, `BehaviorTreeFactory`, `EnemyEntityFactory`.

**Execute(waveNumber, isEndless):**
- Validate `waveNumber > 0`.
- `CombatLoopService:StartCombat(userId, waveNumber, isEndless)` — get userId from a single `Players:GetPlayers()[1]` (single-player; clarify if multi needed later).
- Query alive entities. For each: `_AssignBehaviorTree(entity)`.

**`_AssignBehaviorTree(entity)`:**
- Read `Role` component to get role string.
- `tree = BehaviorTreeFactory:CreateTree(role)`.
- Read tick interval from `BehaviorConfig.DEFAULTS_BY_ROLE[role]` (or default).
- `EnemyEntityFactory:SetBehaviorTree(entity, tree, tickInterval)`.
- `EnemyEntityFactory:SetBehaviorConfig(entity, { TickInterval = tickInterval })`.
- Initialize `CombatAction` component to `{ CurrentActionId = nil, ActionState = "None", ... }`.

**Completion check:** After `StartCombat`, every alive enemy has a `BehaviorTree` component and a zeroed `CombatAction`.

---

### Step 10 — Wire new services into CombatContext + EndCombat cleanup

**Objective:** Update `CombatContext` registration, scheduler loop, and `EndCombat` to use the new pipeline.

**Files:** `CombatContext.lua`, `Application/Commands/EndCombat.lua`

**Tasks:**

**CombatContext.KnitInit:**
- Register (in order): `BehaviorTreeFactory` (Infrastructure), `ExecutorRegistry` (Infrastructure) with `LaneAdvanceExecutor` + `IdleExecutor` pre-populated, `BehaviorTreeTickPolicy` (Domain), `WaveCompletionPolicy` (Domain), `CombatPerceptionService` (Domain).
- Remove `CombatMovementService` registration.

**CombatContext.KnitStart:**
- Remove `_movementService:SetGoalReachedHandler(...)` wiring.
- Scheduler `CombatTick` system: iterate `CombatLoopService:GetActiveCombats()`, skip `IsPaused`, call `ProcessCombatTick:Execute(userId, deltaTime)`.
- Remove standalone `EnemyPositionPoll` system — `EnemyGameObjectSyncService:PollPositions()` is still called each tick (keep as-is, no change needed).

**CombatContext._OnEnemySpawned:**
- After `SetWaypoints`: also call `StartCombat._AssignBehaviorTree(entity)` or inline the BT assignment directly — newly spawned enemies mid-wave must get a BT.

**EndCombat.Execute:**
- Before `CombatLoopService:StopCombat`: iterate `EnemyEntityFactory:QueryAliveEntities()` and call `ExecutorRegistry:CancelAll(entity, services)` on each, then `EnemyEntityFactory:ClearAction(entity)`.

**Completion check:** Full run: wave starts → enemies advance → goal reached → WaveEnded fires → next wave (or RunEnded). No leftover promises or stale action state.

---

### Step 11 — Delete CombatMovementService

**Objective:** Remove the now-superseded movement service.

**Files:** `Infrastructure/Services/CombatMovementService.lua`

**Tasks:**
- Delete the file.
- Confirm no remaining imports (`Grep` for `CombatMovementService` across `src/`).

**Completion check:** No references to `CombatMovementService` remain.

---

## Verification

**End-to-end test:**
1. Start a run. Confirm wave starts and `CombatLoopService:IsActive(userId)` returns true.
2. Confirm swarm enemies walk the lane waypoints and reach the goal — commander takes damage.
3. Confirm tank enemies walk slower (slower tick interval means less-frequent BT re-evaluation; same movement speed is set by `Role.moveSpeed`).
4. Confirm that after the last enemy is despawned, `WaveEnded` fires and the next wave starts.
5. Confirm that `RunEnded` cleans up all executors without errors.
6. Confirm no lingering Promises after run ends (no memory leak).

**Edge cases:**
- Enemy spawned mid-wave after `StartCombat` — must receive BT assignment via `_OnEnemySpawned`.
- Player leaves mid-wave — `PlayerRemoving` → `EndCombat` → `CancelAll` must not error on empty entity list.
- `WaveCompletionPolicy` called when 0 enemies exist at wave start (edge: first enemy hasn't spawned yet) — guard with `aliveEntities count == 0 AND waveNumber > 0` to avoid false positive.

**Critical files:**
- [CombatContext.lua](src/ServerScriptService/Contexts/Combat/CombatContext.lua)
- [ProcessCombatTick.lua](src/ServerScriptService/Contexts/Combat/Application/Commands/ProcessCombatTick.lua)
- [StartCombat.lua](src/ServerScriptService/Contexts/Combat/Application/Commands/StartCombat.lua)
- [EndCombat.lua](src/ServerScriptService/Contexts/Combat/Application/Commands/EndCombat.lua)
- [CombatLoopService.lua](src/ServerScriptService/Contexts/Combat/Infrastructure/Services/CombatLoopService.lua)
- [EnemyEntityFactory.lua](src/ServerScriptService/Contexts/Enemy/Infrastructure/ECS/EnemyEntityFactory.lua)
- [EnemyComponentRegistry.lua](src/ServerScriptService/Contexts/Enemy/Infrastructure/ECS/EnemyComponentRegistry.lua)
