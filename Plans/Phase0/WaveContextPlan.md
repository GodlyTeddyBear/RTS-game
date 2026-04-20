# WaveContext — Wave Composition, Spawn Scheduling, Wave Cleared Detection, Endless Scaling

## Context

The GDD defines a wave-defense game where enemies advance on a single lane in discrete waves. RunContext (planned, not yet implemented) owns the run state machine and fires state transitions via the GameEvents bus. WaveContext is the next foundational system: it listens for RunContext state transitions, manages wave composition (what enemies appear in wave N), schedules enemy spawns over the wave duration, detects when all enemies are dead, and notifies RunContext to advance. In endless mode, it applies escalating mutators to each wave budget.

WaveContext does **not** spawn enemy instances — it fires a `Wave.SpawnEnemy` GameEvents emission that a future EnemyContext will consume. This keeps the contexts fully decoupled.

**GDD update 2026-04-20:** Enemies can drop resource pickups on death. WaveContext should not grant resources directly, but the `Wave.EnemyDied` event must include enough facts for future pickup/drop/economy logic: enemy role, wave number, and death CFrame/position.

Dependencies:
- `WorldContext:GetSpawnPoints()` — for spawn CFrame(s) passed in spawn event payload
- `RunContext` GameEvents: `Run.WaveStarted(waveNumber, isEndless)` and `Run.RunEnded()`
- Future EnemyContext consumes `Wave.SpawnEnemy` and emits `Wave.EnemyDied(role, waveNumber, deathCFrame)`

---

## Goal

Build a server-authoritative `WaveContext` Knit service that:
1. Listens for `Run.WaveStarted` and `Run.RunEnded` on the GameEvents bus
2. Reads wave composition from `WaveConfig` (enemy roles + counts per wave)
3. Drip-spawns enemies over the wave by emitting `Wave.SpawnEnemy` events (EnemyContext consumes)
4. Tracks active enemy count; when it reaches zero, calls `RunContext:NotifyWaveCleared()`
5. Listens for `Wave.EnemyDied` events (emitted by future EnemyContext) to decrement count
6. In endless mode, scales the wave budget via a multiplier and optional role upgrades
7. Exposes no client remotes in Phase 1 — wave state is server-only

---

## Short Action Flow

```
RunContext fires Run.WaveStarted(waveNumber, isEndless)
  → WaveContext._OnWaveStarted(waveNumber, isEndless)
      → WaveCompositionService:BuildWave(waveNumber, isEndless, endlessWaveIndex)
          → reads WaveConfig.WAVE_TABLE[waveNumber] or applies endless scaling formula
          → returns { SpawnGroup } ordered array
      → WorldContext:GetSpawnPoints() → spawnCFrames (cached in KnitStart)
      → WaveSpawnScheduler:Schedule(composition, spawnCFrames, waveNumber, onSpawned)
          → for each SpawnGroup: task.delay(group.groupDelay) →
              for each unit 1..count:
                task.delay((unitIndex-1) * SPAWN_DRIP_INTERVAL) →
                  GameEvents.Bus:Emit(Wave.SpawnEnemy, role, spawnCFrame, waveNumber)
                  onSpawned() → self._activeEnemyCount += 1

EnemyContext (future) receives Wave.SpawnEnemy → spawns instance → on death:
  GameEvents.Bus:Emit(Wave.EnemyDied, role, waveNumber, deathCFrame)

WaveContext._OnEnemyDied(role, waveNumber, deathCFrame)
  → guard: stale waveNumber → ignore
  → self._activeEnemyCount -= 1
  → if _activeEnemyCount <= 0 and _waveActive:
      → WaveSpawnScheduler:CancelAll()
      → Knit.GetService("RunContext"):NotifyWaveCleared()

RunContext fires Run.RunEnded
  → WaveContext._OnRunEnded()
      → WaveSpawnScheduler:CancelAll()
      → reset _activeEnemyCount, _waveActive, _endlessWaveIndex
```

---

## Assumptions

- RunContext emits `Run.WaveStarted(waveNumber: number, isEndless: boolean)` when entering `"Wave"` or `"Endless"` state, and `Run.RunEnded()` when entering `"RunEnd"` state. These are added to RunContext's `_OnStateChanged` (RunContext plan delta — noted below).
- `WorldContext:GetSpawnPoints()` returns `{ CFrame }`. Called once in `KnitStart` and cached.
- EnemyContext (future) emits `Wave.EnemyDied(role, waveNumber, deathCFrame)` when an enemy instance is destroyed. WaveContext never touches enemy instances and ignores `deathCFrame`; future pickup/drop systems consume it.
- `CLIMAX_WAVE` is not read by WaveContext — RunContext owns that decision and passes `isEndless = true` when appropriate.
- No UI in Phase 1.
- No client replication in Phase 1.
- `GameEvents/Contexts/` subfolder does not yet exist and must be created.

---

## Ambiguities Resolved

| Question | Decision |
|---|---|
| Does WaveContext call `NotifyWaveCleared()` directly or via event? | Direct Knit service call — server-to-server write, not a decoupled notification |
| How does WaveContext know spawn CFrames? | Calls `WorldContext:GetSpawnPoints()` in `KnitStart`, caches the result |
| Does WaveContext manage enemy HP/death or resource drops? | No — EnemyContext fires `Wave.EnemyDied`; WaveContext only counts. Future pickup/drop systems consume death position. |
| What if wave timer expires before all enemies die? | RunContext auto-advances via its own WAVE_DURATION timer; WaveContext cancels pending spawns on Run.RunEnded or next Run.WaveStarted |
| What is endless scaling? | `count = floor(baseCount * (1 + ENDLESS_SCALE_FACTOR * endlessWaveIndex))`; role upgrades appended at config-defined thresholds |
| Does WaveContext need per-frame ECS work? | No — spawn scheduling is task.delay based; no phase registration needed |
| Where is `Run.WaveStarted` emitted? | RunContext `_OnStateChanged` — entering `"Wave"` or `"Endless"` state |

---

## RunContext Plan Delta

When RunContext is implemented, add to `_OnStateChanged`:
- Entering `"Wave"` → `GameEvents.Bus:Emit(Events.Run.WaveStarted, self._waveNumber, false)`
- Entering `"Endless"` → `GameEvents.Bus:Emit(Events.Run.WaveStarted, self._waveNumber, true)`
- Entering `"RunEnd"` → `GameEvents.Bus:Emit(Events.Run.RunEnded)`

---

## Files to Create / Modify

### Modify
- `src/ReplicatedStorage/Events/GameEvents/init.lua` — add `Run` and `Wave` domain modules

### Create (Shared / ReplicatedStorage)
```
src/ReplicatedStorage/Events/GameEvents/Contexts/
  Run.lua          ← Run.WaveStarted, Run.RunEnded event constants + schemas
  Wave.lua         ← Wave.SpawnEnemy, Wave.EnemyDied event constants + schemas

src/ReplicatedStorage/Contexts/Wave/
  Config/
    WaveConfig.lua ← WAVE_TABLE, SPAWN_DRIP_INTERVAL, ENDLESS_SCALE_FACTOR, ENDLESS_ROLE_THRESHOLDS
  Types/
    WaveTypes.lua  ← SpawnGroup, WaveComposition, EndlessMutator Luau types
```

### Create (Server)
```
src/ServerScriptService/Contexts/Wave/
  WaveContext.lua
  Errors.lua
  Infrastructure/
    Services/
      WaveCompositionService.lua   ← Builds SpawnGroup list for wave N
      WaveSpawnScheduler.lua       ← task.delay drip scheduling, cancellable
      EndlessScalingService.lua    ← Scales count + appends role upgrades
```

---

## Implementation Plan

### Step 1 — GameEvents: Run domain module

**Objective:** Define event name constants and schemas for RunContext-emitted events that WaveContext consumes.

**File:** `src/ReplicatedStorage/Events/GameEvents/Contexts/Run.lua`

**Tasks:**
- Create the `GameEvents/Contexts/` folder (first file in this subfolder)
- Event constants:
  - `WaveStarted = "Run.WaveStarted"`
  - `RunEnded = "Run.RunEnded"`
- Schemas:
  - `["Run.WaveStarted"] = { "number", "boolean" }` — waveNumber, isEndless
  - `["Run.RunEnded"] = {}` — no arguments
- `table.freeze` events table

**Module ownership:** `ReplicatedStorage` (shared)

**Exit criteria:** `events.WaveStarted` and `events.RunEnded` are accessible strings; module requires without error

---

### Step 2 — GameEvents: Wave domain module

**Objective:** Define event name constants and schemas for WaveContext↔EnemyContext communication.

**File:** `src/ReplicatedStorage/Events/GameEvents/Contexts/Wave.lua`

**Tasks:**
- Event constants:
  - `SpawnEnemy = "Wave.SpawnEnemy"` — WaveContext fires; EnemyContext listens
  - `EnemyDied = "Wave.EnemyDied"` — EnemyContext fires; WaveContext and future pickup/drop systems listen
- Schemas:
  - `["Wave.SpawnEnemy"] = { "string", "CFrame", "number" }` — role, spawnCFrame, waveNumber
  - `["Wave.EnemyDied"] = { "string", "number", "CFrame" }` — role, waveNumber, deathCFrame
- `table.freeze` events table

**Module ownership:** `ReplicatedStorage` (shared)

**Exit criteria:** Both event name strings accessible; schemas match argument shapes

---

### Step 3 — Wire new domains into GameEvents init

**Objective:** Register `Run` and `Wave` domain modules so their events and schemas are included in the singleton bus.

**File:** `src/ReplicatedStorage/Events/GameEvents/init.lua`

**Tasks:**
- Add to `domainModules`:
  - `Run = require(script.Contexts.Run)`
  - `Wave = require(script.Contexts.Wave)`

**Exit criteria:** `GameEvents.Events.Run.WaveStarted` and `GameEvents.Events.Wave.SpawnEnemy` accessible at runtime

---

### Step 4 — WaveConfig (shared)

**Objective:** All wave constants and wave table in one frozen module.

**File:** `src/ReplicatedStorage/Contexts/Wave/Config/WaveConfig.lua`

**Tasks:**
- `SPAWN_DRIP_INTERVAL = 2` — seconds between individual enemy spawns within a group (tunable)
- `ENDLESS_SCALE_FACTOR = 0.15` — 15% more enemies per endless wave index (tunable)
- `WAVE_TABLE`: array indexed by wave number, each entry is an ordered array of `SpawnGroup`:
  ```
  [1] = {
    { role = "swarm", count = 5, groupDelay = 0 },
    { role = "swarm", count = 3, groupDelay = 8 },
  },
  [2] = {
    { role = "swarm", count = 6, groupDelay = 0 },
    { role = "tank",  count = 1, groupDelay = 12 },
  },
  -- ... up to CLIMAX_WAVE - 1
  ```
  `groupDelay` = seconds after wave start before that group begins spawning
- `ENDLESS_ROLE_THRESHOLDS`: maps endless wave index to extra role group appended:
  ```
  [3] = { role = "disruptor", count = 1 },
  [6] = { role = "artillery", count = 1 },
  ```
- `table.freeze` (deep-freeze all nested tables)

**Module ownership:** `ReplicatedStorage` (shared)

**Exit criteria:** All constants readable; `WAVE_TABLE[1]` returns expected spawn groups without error

---

### Step 5 — WaveTypes (shared)

**Objective:** Strict Luau type definitions for wave data structures.

**File:** `src/ReplicatedStorage/Contexts/Wave/Types/WaveTypes.lua`

**Tasks:**
- `export type SpawnGroup = { role: string, count: number, groupDelay: number }`
- `export type WaveComposition = { [number]: SpawnGroup }` — ordered array
- `export type EndlessMutator = { scaleFactor: number, addedRoles: { string } }`

**Module ownership:** `ReplicatedStorage` (shared)

**Exit criteria:** All types importable under `--!strict` with no errors

---

### Step 6 — WaveCompositionService (server infrastructure)

**Objective:** Pure function service — given wave number and isEndless flag, returns the ordered list of spawn groups.

**File:** `src/ServerScriptService/Contexts/Wave/Infrastructure/Services/WaveCompositionService.lua`

**Tasks:**
- Constructor `WaveCompositionService.new()` — reads `WaveConfig` internally
- `BuildWave(waveNumber: number, isEndless: boolean, endlessWaveIndex: number?): Result<WaveComposition>`
  - If `not isEndless`:
    - Assert `WaveConfig.WAVE_TABLE[waveNumber]` exists; return `Result.Err(Errors.UNKNOWN_WAVE)` if not
    - Return `WaveConfig.WAVE_TABLE[waveNumber]` (immutable — do not mutate)
  - If `isEndless`:
    - Base = `WaveConfig.WAVE_TABLE[#WaveConfig.WAVE_TABLE]` (last scripted wave)
    - Build new composition table — for each group: `newCount = math.floor(group.count * (1 + ENDLESS_SCALE_FACTOR * endlessWaveIndex))`
    - Apply `EndlessScalingService:ApplyRoleUpgrades(composition, endlessWaveIndex)` to append threshold groups
    - Return new composition (no mutation of config tables)
- `Init(registry, name)` lifecycle hook

**Guards:**
- Assert `waveNumber > 0`
- `endlessWaveIndex` defaults to 0 if nil

**Exit criteria:** `BuildWave(1, false)` returns WAVE_TABLE[1]; `BuildWave(15, true, 5)` returns inflated composition with expected count

---

### Step 7 — EndlessScalingService (server infrastructure)

**Objective:** Stateless helper for computing endless wave index and appending role upgrade groups.

**File:** `src/ServerScriptService/Contexts/Wave/Infrastructure/Services/EndlessScalingService.lua`

**Tasks:**
- Constructor `EndlessScalingService.new()`
- `GetEndlessWaveIndex(waveNumber: number, climaxWave: number): number`
  - Returns `waveNumber - climaxWave` (1-indexed offset past climax)
- `ApplyRoleUpgrades(composition: WaveComposition, endlessWaveIndex: number): WaveComposition`
  - Iterates `WaveConfig.ENDLESS_ROLE_THRESHOLDS`
  - For each threshold index ≤ `endlessWaveIndex`: append `{ role, count = threshold.count, groupDelay = 0 }` to a new composition table
  - Returns new table (does not mutate input)
- `Init(registry, name)` lifecycle hook

**Exit criteria:** `GetEndlessWaveIndex(12, 10)` returns 2; role upgrades appended correctly at threshold boundaries

---

### Step 8 — WaveSpawnScheduler (server infrastructure)

**Objective:** Drip-schedules enemy spawns using `task.delay`. Fully cancellable. Emits `Wave.SpawnEnemy` game events.

**File:** `src/ServerScriptService/Contexts/Wave/Infrastructure/Services/WaveSpawnScheduler.lua`

**Tasks:**
- Constructor `WaveSpawnScheduler.new()`
- Internal `_activeThreads: { thread }` — all live `task.delay` coroutine handles
- `Schedule(composition: WaveComposition, spawnCFrames: { CFrame }, waveNumber: number, onSpawned: () -> ())`
  - Calls `CancelAll()` first (guard against double-scheduling)
  - For each `SpawnGroup` in `composition` (index `gi`):
    - Outer thread: `task.delay(group.groupDelay, function()`
      - For each unit index `ui` = 1 to `group.count`:
        - Inner thread: `task.delay((ui - 1) * SPAWN_DRIP_INTERVAL, function()`
          - `spawnCFrame = spawnCFrames[((ui - 1) % #spawnCFrames) + 1]` (round-robin)
          - `GameEvents.Bus:Emit(Events.Wave.SpawnEnemy, group.role, spawnCFrame, waveNumber)`
          - `onSpawned()` (increments `_activeEnemyCount` in WaveContext)
          - Store inner thread handle in `_activeThreads`
      - Store outer thread handle in `_activeThreads`
- `CancelAll()` — iterate `_activeThreads`, `task.cancel()` each non-nil handle, clear table
- `Init(registry, name)` lifecycle hook

**Guards:**
- `CancelAll()` is always safe to call (no-op if empty)
- `#spawnCFrames == 0` → log error via `Result.MentionEvent`, return without scheduling

**Exit criteria:** `Schedule` with a 2-group composition emits the correct total number of `Wave.SpawnEnemy` events with correct role and CFrame; `CancelAll()` before completion stops remaining emissions

---

### Step 9 — Errors.lua

**Objective:** Centralized error constants for WaveContext.

**File:** `src/ServerScriptService/Contexts/Wave/Errors.lua`

**Tasks:**
- `UNKNOWN_WAVE = "WaveContext: no wave definition found for wave number"`
- `WAVE_ALREADY_ACTIVE = "WaveContext: received WaveStarted while wave already active"`
- `INVALID_ENEMY_DIED = "WaveContext: EnemyDied received but no wave is active"`
- `NO_SPAWN_POINTS = "WaveContext: no spawn CFrames available — WorldContext returned empty"`
- `table.freeze`

**Exit criteria:** Constants importable; module requires without error

---

### Step 10 — WaveContext Knit service (server)

**Objective:** Wire all infrastructure. Subscribe to GameEvents. Track active enemy count. Call `RunContext:NotifyWaveCleared()` when count hits zero.

**File:** `src/ServerScriptService/Contexts/Wave/WaveContext.lua`

**KnitInit:**
- `Registry.new("Wave")`
- Register `WaveCompositionService.new()` under `"Infrastructure"`
- Register `WaveSpawnScheduler.new()` under `"Infrastructure"`
- Register `EndlessScalingService.new()` under `"Infrastructure"`
- `registry:InitAll()`
- Store refs: `self._composition`, `self._scheduler`, `self._scaling`
- Internal state: `self._waveActive = false`, `self._activeEnemyCount = 0`, `self._currentWaveNumber = 0`, `self._endlessWaveIndex = 0`, `self._spawnCFrames = {}`

**KnitStart:**
- `self._spawnCFrames = Knit.GetService("WorldContext"):GetSpawnPoints()`
- Guard: if `#self._spawnCFrames == 0` → `Result.MentionEvent` error warning (do not crash; WorldContext may not be implemented yet in early testing)
- Subscribe to game events:
  - `GameEvents.Bus:On(Events.Run.WaveStarted, function(waveNumber, isEndless) self:_OnWaveStarted(waveNumber, isEndless) end)`
  - `GameEvents.Bus:On(Events.Run.RunEnded, function() self:_OnRunEnded() end)`
  - `GameEvents.Bus:On(Events.Wave.EnemyDied, function(role, waveNumber, deathCFrame) self:_OnEnemyDied(role, waveNumber, deathCFrame) end)`

**`_OnWaveStarted(waveNumber: number, isEndless: boolean)`:**
- Guard: if `self._waveActive` → `Result.MentionEvent` warning + cancel old schedule (defensive reset)
- If `isEndless`: `self._endlessWaveIndex += 1`
- `self._currentWaveNumber = waveNumber`
- `self._waveActive = true`
- `self._activeEnemyCount = 0`
- `local compositionResult = self._composition:BuildWave(waveNumber, isEndless, self._endlessWaveIndex)`
- On Err: log + return (do not crash)
- `self._scheduler:Schedule(composition, self._spawnCFrames, waveNumber, function() self._activeEnemyCount += 1 end)`
- `Result.MentionEvent("WaveContext", "Wave started", { waveNumber = waveNumber, isEndless = isEndless })`

**`_OnEnemyDied(role: string, waveNumber: number, deathCFrame: CFrame)`:**
- Guard: if `not self._waveActive` → `Result.MentionEvent` warning + return
- Guard: if `waveNumber ~= self._currentWaveNumber` → ignore (stale event from previous wave)
- Do not mutate EconomyContext here. The death CFrame is accepted for future pickup/drop listeners, not used by WaveContext.
- `self._activeEnemyCount -= 1`
- `Result.MentionEvent("WaveContext", "Enemy died", { role = role, remaining = self._activeEnemyCount })`
- If `self._activeEnemyCount <= 0`:
  - `self._waveActive = false`
  - `self._scheduler:CancelAll()` (no-op if all spawns already fired)
  - `Knit.GetService("RunContext"):NotifyWaveCleared()`

**`_OnRunEnded()`:**
- `self._scheduler:CancelAll()`
- `self._waveActive = false`
- `self._activeEnemyCount = 0`
- `self._endlessWaveIndex = 0`
- `Result.MentionEvent("WaveContext", "Run ended — wave state reset")`

**Public server API:**
- `WaveContext:GetActiveEnemyCount(): number`
- `WaveContext:GetCurrentWaveNumber(): number`

**No Client remotes** — wave data is server-only in Phase 1

**Exit criteria:** Emitting `Run.WaveStarted(1, false)` → correct number of `Wave.SpawnEnemy` events fire → after same count of `Wave.EnemyDied` events → `RunContext:NotifyWaveCleared()` called once

---

## Verification Checklist

### Functional Tests
- [ ] `GameEvents.Events.Run.WaveStarted` and `GameEvents.Events.Wave.SpawnEnemy` accessible after server init
- [ ] Emitting `Run.WaveStarted(1, false)` → `Wave.SpawnEnemy` fires with correct role/CFrame/waveNumber
- [ ] Drip interval: second unit in same group fires ~`SPAWN_DRIP_INTERVAL` seconds after first
- [ ] Group delay: second group fires ~`groupDelay` seconds after wave start
- [ ] After all `Wave.EnemyDied(role, waveNumber, deathCFrame)` events match spawn count → `RunContext:NotifyWaveCleared()` called exactly once
- [ ] Emitting `Run.RunEnded` mid-wave → no further `Wave.SpawnEnemy` events fire; count resets to 0
- [ ] Endless wave (`isEndless = true`): spawn count inflated by `ENDLESS_SCALE_FACTOR`
- [ ] `endlessWaveIndex` increments correctly on successive `Run.WaveStarted(N, true)` calls
- [ ] Double `Run.WaveStarted` before `Run.RunEnded` → old schedule cancelled; new schedule starts cleanly

### Edge Cases
- [ ] `Wave.EnemyDied` with stale `waveNumber` → ignored, count not decremented
- [ ] `Wave.EnemyDied` with valid `deathCFrame` does not trigger direct resource grants from WaveContext
- [ ] `Wave.EnemyDied` when no wave active → warning logged, no crash
- [ ] `WAVE_TABLE` entry missing for wave N → `Result.Err` logged, no crash, no spawn schedule started
- [ ] Multiple spawn CFrames → enemies distributed round-robin across all points
- [ ] `GetSpawnPoints()` returns empty table → error logged; wave does not schedule spawns
- [ ] Wave with 0 enemies total → `NotifyWaveCleared()` called immediately (count starts at 0, never incremented)

### Security Checks
- [ ] No Client remotes on WaveContext — no player can read or influence wave state
- [ ] `Wave.SpawnEnemy` and `Wave.EnemyDied` are server-side GameEvents only (not Blink remotes)
- [ ] `NotifyWaveCleared()` is called by WaveContext server code only

### Performance Checks
- [ ] No per-frame polling — all scheduling is `task.delay` based
- [ ] `CancelAll()` cleans up all thread handles — no leaked coroutines after run end
- [ ] `Wave.SpawnEnemy` has 0 listeners until EnemyContext subscribes (lazy signal creation is safe)
- [ ] Endless count inflation is `math.floor`'d — no floating point accumulation

---

## Critical Files

| File | Action |
|---|---|
| `src/ReplicatedStorage/Events/GameEvents/Contexts/Run.lua` | Create |
| `src/ReplicatedStorage/Events/GameEvents/Contexts/Wave.lua` | Create |
| `src/ReplicatedStorage/Events/GameEvents/init.lua` | Modify — add Run + Wave to domainModules |
| `src/ReplicatedStorage/Contexts/Wave/Config/WaveConfig.lua` | Create |
| `src/ReplicatedStorage/Contexts/Wave/Types/WaveTypes.lua` | Create |
| `src/ServerScriptService/Contexts/Wave/Infrastructure/Services/WaveCompositionService.lua` | Create |
| `src/ServerScriptService/Contexts/Wave/Infrastructure/Services/WaveSpawnScheduler.lua` | Create |
| `src/ServerScriptService/Contexts/Wave/Infrastructure/Services/EndlessScalingService.lua` | Create |
| `src/ServerScriptService/Contexts/Wave/Errors.lua` | Create |
| `src/ServerScriptService/Contexts/Wave/WaveContext.lua` | Create |

## Reusable Utilities

| Utility | Path | Usage |
|---|---|---|
| `Registry` | `src/ReplicatedStorage/Utilities/Registry.lua` | Module lifecycle in KnitInit |
| `Result` | `src/ReplicatedStorage/Utilities/Result.lua` | Guards, error logging, event telemetry |
| `GameEvents` | `src/ReplicatedStorage/Events/GameEvents` | Cross-context pub/sub bus |
| Knit | `ReplicatedStorage.Packages.Knit` | Service registration and inter-context calls |

## Recommended First Build Step

**Steps 1 + 2 + 3** (GameEvents domain modules + init wiring) — unblocked; establish event contracts everything else depends on.
Then **Steps 4 + 5** (WaveConfig + WaveTypes) — unblocked, fast.
Then **Step 6** (WaveCompositionService) — depends on WaveConfig + WaveTypes.
Then **Steps 7 + 8 + 9** (EndlessScalingService + WaveSpawnScheduler + Errors) — parallel, no inter-dependencies.
Then **Step 10** (WaveContext) — wires everything; depends on all prior steps.
