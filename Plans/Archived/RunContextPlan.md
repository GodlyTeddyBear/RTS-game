# RunContext — Run State Machine

## Context

The GDD defines a sci-fi hybrid RTS wave-defense game with a strict per-run lifecycle: Prep → Wave → Resolution → (loop) → Climax → Endless → RunEnd. No other system (WaveContext, EnemyContext, PlacementContext, CommanderContext, EconomyContext) can gate behavior correctly without a server-authoritative state machine to react to. RunContext is the second foundational piece after WorldContext.

User answers that shape this plan:
- Run state **replicates to clients** via Charm atom + Charm-sync + Blink in Phase 1
- Timers are **config-driven countdowns** that auto-advance state (Prep → Wave, Wave → Resolution)
- Climax is a **distinct named state** in the machine
- RunContext **owns WaveNumber** (incremented each time Wave state is entered)

WorldPlan (not yet implemented) is listed as a dependency — RunContext does not depend on WorldContext data, only on the server being bootable after Runtime cleanup.

---

**GDD update 2026-04-20:** Crafting and structure upgrades are now Prep-phase systems. RunContext remains the state authority; PlacementContext and the future Structure/Crafting scope must gate placement, crafting, unlocking, and upgrades on `state == "Prep"`. Run start should initialize the full Economy wallet (Energy plus zone resources), and RunEnd should trigger cleanup for placements, structures, resource wallets, extractor state, and commander cooldown/HP state.

---

## Goal

Build a server-authoritative `RunContext` Knit service that:
1. Owns the run state machine: `Idle → Prep → Wave → Resolution → Climax → Endless → RunEnd`
2. Owns a `WaveNumber` counter (incremented on each Wave entry, including Endless waves)
3. Runs config-driven countdowns for Prep and Wave phases using `task.delay`
4. Fires server-side `Signal` events on every state transition (consumed by WaveContext, EnemyContext, etc. in future)
5. Replicates the current `RunState` and `WaveNumber` to all clients via Charm atom + Charm-sync + Blink (global atom, not per-player)
6. Exposes a server-side query API for other contexts to read current state
7. Provides the authoritative phase gate for Prep-only placement/crafting/upgrading systems

---

## Short Action Flow

```
[Server startup]
  Knit discovers RunContext
  RunContext:KnitInit()
    → Registry creates RunStateMachine, RunTimerService
    → RunSyncService initializes Charm atom { state = "Idle", waveNumber = 0 }
    → Blink RunSync event wired
  RunContext:KnitStart()
    → Players.PlayerAdded → hydrate new client
    → Existing players hydrated

[State transition: StartRun command]
  RunContext:StartRun()           ← called by future GameLoopContext or debug trigger
    → guard: state must be Idle
    → RunStateMachine:Transition("Prep")
    → WaveNumber stays 0
    → RunTimerService:StartPrepCountdown()
        → task.delay(PREP_DURATION) → RunContext:_OnPrepTimeout()
            → RunStateMachine:Transition("Wave")
            → WaveNumber += 1
            → RunTimerService:StartWaveCountdown()
                → task.delay(WAVE_DURATION) → RunContext:_OnWaveTimeout()
                    → RunStateMachine:Transition("Resolution")
                    → RunTimerService:StartResolutionCountdown()
                        → task.delay(RESOLUTION_DURATION) → RunContext:_OnResolutionTimeout()
                            → if WaveNumber == CLIMAX_WAVE → Transition("Climax")
                            → else → Transition("Prep") [loop]

[Wave cleared early]
  WaveContext calls RunContext:NotifyWaveCleared()  ← future integration
    → guard: state must be "Wave"
    → RunTimerService:CancelWaveCountdown()
    → Transition("Resolution") immediately

[Climax complete]
  RunContext:NotifyClimaxComplete()  ← called by future BossContext
    → guard: state must be "Climax"
    → Transition("Endless")
    → WaveNumber += 1
    → RunTimerService:StartWaveCountdown()  ← Endless uses same wave timer

[Commander death]
  RunContext:NotifyCommanderDeath()  ← called by future CommanderContext
    → guard: state not "Idle" or "RunEnd"
    → RunTimerService:CancelAll()
    → Transition("RunEnd")

[Each Transition]
  → RunStateMachine stores new state
  → RunSyncService atom updated: { state = newState, waveNumber = self._waveNumber }
  → Charm-sync pushes delta to all hydrated clients via Blink RunSync event
  → StateChanged Signal fires (server-side, for other contexts)
  → Economy/Placement/Structure/Commander systems react to lifecycle cleanup/init as needed
```

---

## System Breakdown

### Gameplay
- State machine with 7 named states: `Idle`, `Prep`, `Wave`, `Resolution`, `Climax`, `Endless`, `RunEnd`
- Timers auto-advance Prep→Wave, Wave→Resolution; Resolution checks WaveNumber to branch to Prep or Climax
- WaveNumber increments each time Wave or Endless is entered
- External notify methods allow other contexts to trigger early transitions (wave cleared, commander death, climax done)

### Server
- `RunContext.lua` — Knit service; owns state machine, timer service, sync service; exposes public API
- `RunStateMachine.lua` — pure state table with transition guard and `StateChanged` Signal
- `RunTimerService.lua` — wraps `task.delay`; cancellable per-phase timers
- `RunSyncService.lua` — owns global Charm atom; CharmSync.server; hydrates players

### Shared
- `RunConfig.lua` — `PREP_DURATION`, `WAVE_DURATION`, `RESOLUTION_DURATION`, `CLIMAX_WAVE` (wave number that triggers Climax), `table.freeze`
- `RunTypes.lua` — `RunState` union type, `RunSnapshot` type
- `SharedAtoms.lua` — `CreateServerAtom()` and `CreateClientAtom()` for `RunSnapshot`

### Client
- `RunSyncClient.lua` — `BaseSyncClient` wrapper; wires Blink listener; exposes `GetAtom()`
- Client contexts/UI call `GetAtom()` to subscribe to `RunSnapshot` reactively via Charm

### Networking
- New Blink file: `src/Network/RunSync.blink`
  - One event: `SyncRunState` (Server → Client, Reliable, SingleAsync)
  - Payload: CharmSync delta payload (same pattern as LogSync)
- Generate: `RunSyncServer.luau`, `RunSyncClient.luau`

### UI
- No UI in Phase 1. Clients receive the atom and can subscribe in a future HUD feature slice.

### Data
- `RunSnapshot` atom shape: `{ state: RunState, waveNumber: number }`
- Global atom (not per-player) — all clients see the same run state
- Server atom mutated only by RunContext internal transitions
- Client atom updated only via Blink/CharmSync delta

### Security
- No client remotes on RunContext — all transitions are server-initiated
- `NotifyWaveCleared`, `NotifyCommanderDeath`, `NotifyClimaxComplete` are server-only methods (not Client table)
- Transition guards prevent illegal state jumps (e.g. cannot go Idle → Wave directly)

### Performance
- `task.delay` is fire-and-forget; one active timer per phase maximum
- CharmSync interval: 0.1s (faster than LogSync's 0.33s — run state changes matter immediately for UI)
- No per-frame work; RunContext is entirely event/timer driven

### Testing
- Studio Play: manually call `RunContext:StartRun()` via server console; verify state transitions in output
- Verify atom replicates to client: check `RunSyncClient:GetAtom()()` matches server state
- Verify WaveNumber increments correctly through full loop
- Verify `NotifyCommanderDeath()` in any non-terminal state → RunEnd

### Refactor/Migration Impact
- `Phases.lua` — add no phases (RunContext has no per-frame ECS work)
- `Runtime.server.lua` — already needs cleanup (WorldPlan Step 1); RunContext auto-discovered by existing `Contexts:GetChildren()` loop — no Runtime changes needed beyond WorldPlan cleanup
- Jabby — no JECS world to register (RunContext has no ECS)

---

## Proposed Architecture

### File / Module Layout

```
src/Network/
  RunSync.blink                                    ← New Blink definition
  Generated/
    RunSyncServer.luau                             ← Generated (run: blink)
    RunSyncClient.luau                             ← Generated (run: blink)

src/ReplicatedStorage/Contexts/Run/
  Config/
    RunConfig.lua                                  ← Durations, CLIMAX_WAVE constant
  Types/
    RunTypes.lua                                   ← RunState union, RunSnapshot type
  Sync/
    SharedAtoms.lua                                ← CreateServerAtom / CreateClientAtom

src/ServerScriptService/Contexts/Run/
  RunContext.lua                                   ← Knit service (owns everything)
  Errors.lua                                       ← Error constants
  Infrastructure/
    Services/
      RunStateMachine.lua                          ← State + transition guard + Signal
      RunTimerService.lua                          ← task.delay wrappers, cancellable
      RunSyncService.lua                           ← Charm atom, CharmSync.server, hydrate

src/StarterPlayerScripts/Contexts/Run/
  Infrastructure/
    RunSyncClient.lua                              ← BaseSyncClient wrapper
```

### Data Flow

```
RunConfig (shared) ──→ RunTimerService (reads durations)
RunTypes (shared)  ──→ RunStateMachine (type-checked states)
                       RunSyncService (atom shape)
                       RunSyncClient (atom shape)

RunContext
  ├── RunStateMachine  → StateChanged Signal → (future: WaveContext, EnemyContext listeners)
  ├── RunTimerService  → task.delay callbacks → RunContext internal methods
  └── RunSyncService   → Charm atom → CharmSync → Blink → Client atom
                                                         → UI hooks (future)
```

### Network Flow

```
Server: RunSyncService.Syncer:connect(player, payload)
  → Blink RunSyncServer.SyncRunState.Fire(player, payload)
    → Client: Blink RunSyncClient.SyncRunState.On(payload)
      → CharmSync.client:sync(payload)
        → RunSyncClient.Atom updated
          → Charm subscribers notified (React hooks, future UI)
```

---

## Implementation Plan

### Step 1 — RunSync.blink + generate

**Objective:** Define the Blink network contract for run state replication.

**Files:**
- Create `src/Network/RunSync.blink`
- Run `blink` to generate `RunSyncServer.luau` and `RunSyncClient.luau`

**Tasks:**
- Define `option RemoteScope = "RUN_SYNC"`
- Define `struct RunSnapshot { state: string, waveNumber: u32 }`
- Define event `SyncRunState { from: Server, type: Reliable, call: SingleAsync, data: buffer }` — uses raw buffer for CharmSync delta payload (same pattern as LogSync)
- Run `blink` CLI to generate server/client modules into `src/Network/Generated/`

**Trigger:** Manual (prerequisite for RunSyncService)

**Dependencies:** None — standalone Blink file

**Exit criteria:** `RunSyncServer.luau` and `RunSyncClient.luau` exist in `Generated/` with `SyncRunState` event

---

### Step 2 — RunConfig (shared)

**Objective:** All run timing and wave constants in one frozen module.

**File:** `src/ReplicatedStorage/Contexts/Run/Config/RunConfig.lua`

**Tasks:**
- `PREP_DURATION = 30` (seconds; tunable)
- `WAVE_DURATION = 90` (seconds max before auto-resolution; tunable)
- `RESOLUTION_DURATION = 5` (seconds before next Prep or Climax)
- `CLIMAX_WAVE = 10` (wave number that triggers Climax instead of next Prep loop)
- `table.freeze` the module

**Exit criteria:** Module requires without error; all constants readable

---

### Step 3 — RunTypes (shared)

**Objective:** Strict Luau types for run state and snapshot.

**File:** `src/ReplicatedStorage/Contexts/Run/Types/RunTypes.lua`

**Tasks:**
- `export type RunState = "Idle" | "Prep" | "Wave" | "Resolution" | "Climax" | "Endless" | "RunEnd"`
- `export type RunSnapshot = { state: RunState, waveNumber: number }`

**Exit criteria:** Types importable under `--!strict` with no errors

---

### Step 4 — SharedAtoms (shared)

**Objective:** Charm atom factories for server and client, same pattern as Log context.

**File:** `src/ReplicatedStorage/Contexts/Run/Sync/SharedAtoms.lua`

**Tasks:**
- Import `Charm`
- `CreateServerAtom()` → `Charm.atom({ state = "Idle", waveNumber = 0 } :: RunSnapshot)`
- `CreateClientAtom()` → `Charm.atom({ state = "Idle", waveNumber = 0 } :: RunSnapshot)`

**Exit criteria:** Both factory functions callable; atoms hold correct initial shape

---

### Step 5 — RunStateMachine (server infrastructure)

**Objective:** Pure state table with legal transition map and `StateChanged` Signal.

**File:** `src/ServerScriptService/Contexts/Run/Infrastructure/Services/RunStateMachine.lua`

**Tasks:**
- Constructor `RunStateMachine.new()` → initial state `"Idle"`
- Define legal transitions table:
  ```
  Idle        → Prep
  Prep        → Wave
  Wave        → Resolution
  Resolution  → Prep, Climax
  Climax      → Endless
  Endless     → Resolution, RunEnd
  RunEnd      → (none — terminal)
  ```
- `Transition(newState: RunState): Result` — guard checks legal transitions; returns `Err` if illegal; on success sets `self._state = newState` and fires `self.StateChanged`
- `GetState(): RunState` — read current state
- `StateChanged` — `Signal.new()` (use `sleitnick_signal` package already in wally); fires with `(newState: RunState, previousState: RunState)`
- `Init(registry, name)` lifecycle hook

**Guards:** Assert `newState` is in legal transitions for `self._state`; return `Result.Err(Errors.ILLEGAL_TRANSITION)` if not

**Exit criteria:** `Transition("Prep")` from Idle succeeds; `Transition("Wave")` from Idle returns Err; `StateChanged` fires on valid transition

---

### Step 6 — RunTimerService (server infrastructure)

**Objective:** Cancellable `task.delay` wrappers for each phase timer.

**File:** `src/ServerScriptService/Contexts/Run/Infrastructure/Services/RunTimerService.lua`

**Tasks:**
- Constructor `RunTimerService.new(config: RunConfig)`
- Internal `_activeThread: thread?` — stores the current `task.delay` coroutine handle
- `StartPrepCountdown(onExpire: () -> ())` — `task.delay(config.PREP_DURATION, onExpire)`; stores thread
- `StartWaveCountdown(onExpire: () -> ())` — `task.delay(config.WAVE_DURATION, onExpire)`; stores thread
- `StartResolutionCountdown(onExpire: () -> ())` — `task.delay(config.RESOLUTION_DURATION, onExpire)`; stores thread
- `Cancel()` — if `_activeThread` is non-nil, `task.cancel(_activeThread)`; clears handle
- `Init(registry, name)` lifecycle hook

**Guards:** `Cancel()` is a no-op if no active thread; new `Start*` calls cancel any existing timer first (no double-timers)

**Exit criteria:** Starting a countdown then cancelling it does not fire the callback; a non-cancelled countdown fires after the configured delay

---

### Step 7 — RunSyncService (server infrastructure)

**Objective:** Global Charm atom owned by server; CharmSync.server wires delta pushes to all clients via Blink.

**File:** `src/ServerScriptService/Contexts/Run/Infrastructure/Services/RunSyncService.lua`

**Tasks:**
- Constructor `RunSyncService.new()`
- `Init(registry, name)`:
  - `self.BlinkServer = registry:Get("BlinkServer")`
  - `self.Atom = SharedAtoms.CreateServerAtom()`
  - `self.Syncer = CharmSync.server({ atoms = { runState = self.Atom }, interval = 0.1, preserveHistory = false, autoSerialize = false })`
  - `self.Cleanup = self.Syncer:connect(function(player, payload) BlinkServer.SyncRunState.Fire(player, payload) end)`
- `HydratePlayer(player: Player)` — `self.Syncer:hydrate(player)`
- `SetState(snapshot: RunSnapshot)` — `self.Atom(function() return snapshot end)`
- `Destroy()` — `self.Cleanup()`

**Exit criteria:** After `HydratePlayer`, the client receives the initial atom state; after `SetState`, the next Charm-sync interval pushes the delta

---

### Step 8 — Errors.lua

**Objective:** Centralized error constants for RunContext.

**File:** `src/ServerScriptService/Contexts/Run/Errors.lua`

**Tasks:**
- `ILLEGAL_TRANSITION = "RunContext: illegal state transition attempted"`
- `INVALID_STATE_FOR_NOTIFY = "RunContext: notify called from invalid state"`
- `table.freeze`

**Exit criteria:** Constants importable; no typos

---

### Step 9 — RunContext Knit service (server)

**Objective:** Wire all infrastructure together; expose public server API and player hydration.

**File:** `src/ServerScriptService/Contexts/Run/RunContext.lua`

**Tasks:**

**KnitInit:**
- `Registry.new("Run")`
- `registry:Register("BlinkServer", BlinkRunSyncServer)` (generated Blink server module)
- `registry:Register("RunStateMachine", RunStateMachine.new(), "Infrastructure")`
- `registry:Register("RunTimerService", RunTimerService.new(RunConfig), "Infrastructure")`
- `registry:Register("RunSyncService", RunSyncService.new(), "Infrastructure")`
- `registry:InitAll()`
- Store refs: `self._machine`, `self._timer`, `self._sync`
- Wire `self._machine.StateChanged:Connect(self:_OnStateChanged())` to push atom updates

**KnitStart:**
- `Players.PlayerAdded:Connect(player → self._sync:HydratePlayer(player))`
- Hydrate any players already in server

**Public server API** (called by other server contexts via `Knit.GetService("RunContext")`):
- `RunContext:StartRun()` — guard: state == "Idle"; transition to "Prep"; start prep countdown
- `RunContext:GetState(): RunState`
- `RunContext:GetWaveNumber(): number`
- `RunContext:NotifyWaveCleared()` — guard: state == "Wave"; cancel wave timer; transition to "Resolution"; start resolution countdown
- `RunContext:NotifyClimaxComplete()` — guard: state == "Climax"; transition to "Endless"; increment WaveNumber; start wave countdown
- `RunContext:NotifyCommanderDeath()` — guard: state not "Idle" and not "RunEnd"; cancel all timers; transition to "RunEnd"

**Internal timer callbacks:**
- `_OnPrepTimeout()` → transition "Wave"; WaveNumber += 1; start wave countdown
- `_OnWaveTimeout()` → transition "Resolution"; start resolution countdown
- `_OnResolutionTimeout()` → if WaveNumber >= CLIMAX_WAVE → transition "Climax"; else → transition "Prep"; start prep countdown

**`_OnStateChanged(newState, prevState)`:**
- `self._sync:SetState({ state = newState, waveNumber = self._waveNumber })`
- `Result.MentionEvent("RunContext:RunStateMachine", "State → " .. newState, { waveNumber = self._waveNumber })`
- Entering `"Prep"` from `"Idle"` is the canonical RunStart hook for EconomyContext wallet initialization and future Structure/Crafting runtime-state initialization.
- Entering `"RunEnd"` is the canonical cleanup hook for EconomyContext wallets, PlacementContext placed structures, Structure/Crafting unlock/tier runtime state, CommanderContext HP/cooldowns, and extractor runtime state.

**No Client remotes** — all replication is via Charm-sync/Blink; no `RunContext.Client` methods

**Exit criteria:** `RunContext:StartRun()` → state becomes "Prep" → after PREP_DURATION → state becomes "Wave", WaveNumber == 1 → after WAVE_DURATION → state becomes "Resolution" → loops or climaxes correctly

---

### Step 10 — RunSyncClient (client infrastructure)

**Objective:** Client-side Charm atom that stays in sync with server run state.

**File:** `src/StarterPlayerScripts/Contexts/Run/Infrastructure/RunSyncClient.lua`

**Tasks:**
- `RunSyncClient.new(blinkClient)` → calls `BaseSyncClient.new(blinkClient, "SyncRunState", "runState", SharedAtoms.CreateClientAtom)`
- `RunSyncClient:Start()` → calls `BaseSyncClient:Start()` (wires Blink listener → CharmSync:sync)
- `RunSyncClient:GetAtom()` → returns the client Charm atom

**Ownership:** Client — instantiated in a future `RunController` or directly by client contexts that need run state

**Exit criteria:** After server transitions to "Prep", client atom reads `{ state = "Prep", waveNumber = 0 }` within one Charm-sync interval (≤0.1s)

---

## Verification Checklist

### Functional Tests
- [ ] Server starts cleanly (after WorldPlan Runtime cleanup); RunContext loads without error
- [ ] `RunContext:StartRun()` from Idle → state == "Prep", atom replicates to client
- [ ] After `PREP_DURATION` seconds → state == "Wave", WaveNumber == 1
- [ ] After `WAVE_DURATION` seconds → state == "Resolution"
- [ ] After `RESOLUTION_DURATION` seconds (WaveNumber < CLIMAX_WAVE) → state == "Prep"
- [ ] After `RESOLUTION_DURATION` seconds (WaveNumber == CLIMAX_WAVE) → state == "Climax"
- [ ] `NotifyWaveCleared()` during Wave → immediate Resolution (timer cancelled)
- [ ] `NotifyClimaxComplete()` → state == "Endless", WaveNumber incremented
- [ ] `NotifyCommanderDeath()` from any non-terminal state → state == "RunEnd", all timers cancelled
- [ ] Client atom matches server state within 0.1s of each transition
- [ ] `StartRun()` while state != "Idle" → returns Err (no transition)

### Edge Cases
- [ ] `NotifyCommanderDeath()` during Prep (before first wave) → RunEnd
- [ ] `NotifyCommanderDeath()` when state == "Idle" → no-op / Err (should not crash)
- [ ] Player joins mid-run → hydrated with current state (not "Idle")
- [ ] Double `StartRun()` call → second call returns Err, no duplicate timers
- [ ] `NotifyWaveCleared()` when state == "Resolution" → Err, no crash

### Security Checks
- [ ] No Client remotes on RunContext — no player can trigger state transitions
- [ ] `NotifyCommanderDeath`, `NotifyWaveCleared`, `NotifyClimaxComplete` are server-only methods

### Performance Checks
- [ ] No per-frame polling — all transitions are timer or event driven
- [ ] CharmSync interval 0.1s — at most one delta push per 100ms per connected player
- [ ] No memory leak from `task.delay` — cancelled threads are cleaned up

---

## Critical Files

| File | Action |
|---|---|
| `src/Network/RunSync.blink` | Create |
| `src/Network/Generated/RunSyncServer.luau` | Generate (blink CLI) |
| `src/Network/Generated/RunSyncClient.luau` | Generate (blink CLI) |
| `src/ReplicatedStorage/Contexts/Run/Config/RunConfig.lua` | Create |
| `src/ReplicatedStorage/Contexts/Run/Types/RunTypes.lua` | Create |
| `src/ReplicatedStorage/Contexts/Run/Sync/SharedAtoms.lua` | Create |
| `src/ServerScriptService/Contexts/Run/Infrastructure/Services/RunStateMachine.lua` | Create |
| `src/ServerScriptService/Contexts/Run/Infrastructure/Services/RunTimerService.lua` | Create |
| `src/ServerScriptService/Contexts/Run/Infrastructure/Services/RunSyncService.lua` | Create |
| `src/ServerScriptService/Contexts/Run/Errors.lua` | Create |
| `src/ServerScriptService/Contexts/Run/RunContext.lua` | Create |
| `src/StarterPlayerScripts/Contexts/Run/Infrastructure/RunSyncClient.lua` | Create |

## Reusable Utilities

| Utility | Path | Usage |
|---|---|---|
| `Registry` | `src/ReplicatedStorage/Utilities/Registry.lua` | Module lifecycle in KnitInit |
| `Result` | `src/ReplicatedStorage/Utilities/Result.lua` | Transition guards + event logging |
| `BaseSyncClient` | `src/ReplicatedStorage/Utilities/BaseSyncClient.lua` | RunSyncClient base |
| `Signal` | `ReplicatedStorage.Packages.Signal` | StateChanged on RunStateMachine |
| Knit | `ReplicatedStorage.Packages.Knit` | Service registration |
| Charm | `ReplicatedStorage.Packages.Charm` | Global run state atom |
| Charm-sync | `ReplicatedStorage.Packages.Charm-sync` | Server→client delta sync |

## Recommended First Build Step

**Step 1** (RunSync.blink + generate) — unblocked, establishes the network contract.
Then **Steps 2 + 3 + 4** (config + types + atoms) — all unblocked and fast.
Then **Step 5** (RunStateMachine) — the core logic.
Then **Steps 6 + 7 + 8** (timer + sync + errors) — parallel, no dependencies between them.
Then **Step 9** (RunContext) — wires everything.
Then **Step 10** (RunSyncClient) — client side, needs generated Blink client.
