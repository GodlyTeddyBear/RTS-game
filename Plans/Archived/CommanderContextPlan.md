# CommanderContext — Player Character

## Context

The GDD defines the commander as the player character and the run's loss condition (HP = 0 ends the run). The commander is the primary tactical lever: they have a concrete v0 5-slot ability kit in GDD §6.1, cooldown tracking per slot, and spend Energy on ability use. This plan builds the server-authoritative CommanderContext in Phase 1 — owning HP, death events, ability slot definitions, cooldown state, and Energy cost hooks. Ability *implementations* (actual effects) are stubs; only the kit scaffolding and config metadata are wired. A client controller exposes HP and cooldown state to the UI via Charm atom replication.

---

## Goal

Build a server-authoritative `CommanderContext` that owns:
1. **Commander HP** — current/max, damage intake, death detection
2. **Death condition** — fires `CommanderDied` signal when HP hits 0; RunContext will subscribe
3. **Ability kit** — 5 typed slots (Mobility, SummonA, SummonB, Control, Ultimate), each a stub with name, energy cost, and cooldown duration
4. **Cooldown tracking** — per-slot server-side timestamp; query exposes remaining cooldown
5. **Energy cost hook** — `UseAbility` validates energy via EconomyContext (stub call) before triggering
6. **Client replication** — HP and per-slot cooldown state replicated via Charm atom + CharmSync

---

## Reconciliation Corrections (Phase 0)

This plan is reconciled against `.claude/commands/reconcile-context.md` and backend DDD/CQRS rules.

- Context layering remains strict: `CommanderContext` is pass-through only; all behavior lives in Application services.
- Atom sync modules must live in `Infrastructure/Persistence`, not `Infrastructure/Services`.
- Query modules are Infrastructure-read only. They must not execute Domain mutation logic.
- Domain services are calculation/validation only; mutation stays in Application -> Infrastructure.
- `Errors.lua` remains the only source of error strings.

Reconciliation matrix:
- [x] `Application/Commands` present
- [x] `Application/Queries` present
- [x] `CommanderDomain/` present
- [x] `Infrastructure/Persistence` present for sync
- [x] `Infrastructure/Services` present for non-sync runtime work
- [x] `CommanderContext.lua` is pass-through boundary with `WrapContext`
- [x] `Errors.lua` centralized

---

## Short Action Flow

```
[Server startup]
  → Knit discovers CommanderContext
  → CommanderContext:KnitInit()
      → Registry builds: CommanderSyncService, AbilityService, CooldownService
      → Atoms initialized (HP + cooldown state per player)
  → CommanderContext:KnitStart()
      → Subscribes to Players.PlayerAdded / PlayerRemoving
      → HydratePlayer on join (sends initial state)

[Player takes damage — server only]
  ApplyDamage(player, amount)
  → CommanderSyncService:ApplyDamage(userId, amount)
      → Targeted clone: current[userId].hp -= amount (clamped to 0)
      → If HP <= 0: SetHP(userId, 0) + CommanderDied:Fire(player)
  → Charm patch → CharmSync → client atom update → UI reads new HP

[Player uses ability — client fires Remote]
  Client: CommanderContext.Client:UseAbility(player, slotKey)
  → Server: validate slotKey is valid SlotKey enum
  → UseAbilityCommand:Execute(player, slotKey)
      → CooldownService:IsReady(userId, slotKey)
      → AbilityService:CanAffordAbility(userId, slotKey) [stub: true]
      → AbilityService:ExecuteStub(userId, slotKey) [no-op]
      → CommanderSyncService:SetCooldown(userId, slotKey, duration)
  → Charm patch → client atom → UI updates slot cooldown display

[Run ends — external signal]
  CommanderDied:Fire(player) → RunContext (future subscriber)
```

---

## Assumptions

- One commander per player (userId = key for all state)
- WorldContext plan already exists; CommanderContext does not depend on it in Phase 1
- RunContext does not exist yet — `CommanderDied` is a BindableEvent that RunContext subscribes to in its own plan
- EconomyContext does not exist yet — energy cost check is a **stub** returning `true` always
- Commander ability costs always use **Energy**, even after the GDD's multi-resource economy update.
- Physical Roblox character model (Humanoid) is NOT used for HP — HP is a pure data value in the atom; the Humanoid is cosmetic
- Ability effects (VFX, spawning summons, applying slows) are **not implemented** — stubs only
- Phase 1 does not include ability input UI — that is a future client feature slice
- Cooldown is server-authoritative; client reads remaining time from replicated atom
- `UseAbility` is called via Knit Client remote (not Blink) — consistent with LogContext pattern

---

## Ambiguities Resolved

| Question | Decision |
|---|---|
| Does commander HP map to Humanoid.Health? | No. Pure data atom. Humanoid is cosmetic only. |
| Where does EconomyContext integration live? | Stub in AbilityService — `CanAffordAbility(userId, cost)` always returns true until EconomyContext exists |
| Does UseAbility come from client or server? | Client fires Knit Client remote; server validates and executes |
| Does RunContext exist yet? | No — `CommanderDied` is a BindableEvent stored on `CommanderContext`; RunContext will subscribe in its own plan |
| Is state per-player or shared? | Per-player (multiplayer-ready; userId-keyed atom) |
| Are cooldowns frame-accurate or timestamp-based? | Timestamp-based (`os.clock()` diff); no per-frame ECS system needed in Phase 1 |

---

## Files to Create / Modify

### Modify
- `src/ServerScriptService/Runtime.server.lua` — no changes needed (Knit auto-discovers CommanderContext folder)

### Create (Shared)
```
src/ReplicatedStorage/Contexts/Commander/
  Config/
    CommanderConfig.lua            ← Max HP, slot definitions (name, cost, cooldown)
  Types/
    CommanderTypes.lua             ← CommanderState, CooldownState, SlotKey types
  Sync/
    SharedAtoms.lua                ← CreateServerAtom / CreateClientAtom
```

### Create (Server)
```
src/ServerScriptService/Contexts/Commander/
  CommanderContext.lua
  Errors.lua
  Application/
    Commands/
      UseAbilityCommand.lua
    Queries/
      GetCommanderStateQuery.lua
      GetCooldownQuery.lua
  CommanderDomain/
    Services/
      AbilityService.lua           ← Kit definition + stub execution
      CooldownService.lua          ← Timestamp-based cooldown tracking
    ValueObjects/
      AbilitySlot.lua              ← Immutable slot record (key, name, cost, cooldown)
  Infrastructure/
    Persistence/
      CommanderSyncService.lua     <- Atom mutations (HP, cooldown state)
    Services/
      CommanderRuntimeService.lua  <- Optional non-sync runtime orchestration (create only if needed)
```

### Create (Client)
```
src/StarterPlayerScripts/Contexts/Commander/
  CommanderController.lua          ← Knit controller; starts sync client, exposes atom
  Infrastructure/
    CommanderSyncClient.lua        ← BaseSyncClient subclass
```

---

## Implementation Plan

### Step 1 — CommanderTypes (shared)

**Objective:** Strict Luau types for all commander state.

**File:** `src/ReplicatedStorage/Contexts/Commander/Types/CommanderTypes.lua`

**Tasks:**
- `export type SlotKey = "Mobility" | "SummonA" | "SummonB" | "Control" | "Ultimate"`
- `export type AbilitySlotDef = { key: SlotKey, displayName: string, energyCost: number, cooldownDuration: number, metadata: { [string]: any }? }`
- `export type CooldownEntry = { startedAt: number, duration: number }` — `startedAt` is `os.clock()` timestamp
- `export type CooldownState = { [string]: CooldownEntry? }` — nil = not on cooldown
- `export type CommanderState = { hp: number, maxHp: number, cooldowns: CooldownState }`
- `export type CommanderAtomState = { [number]: CommanderState }` — keyed by userId

**Exit criteria:** All types importable under `--!strict` with no errors.

---

### Step 2 — CommanderConfig (shared)

**Objective:** Single source of truth for all commander constants.

**File:** `src/ReplicatedStorage/Contexts/Commander/Config/CommanderConfig.lua`

**Tasks:**
- Define `MAX_HP: number` (placeholder: 100)
- Define `SLOTS: { AbilitySlotDef }` from GDD §6.1:
  - `Mobility`: `displayName = "Blink Step"`, `energyCost = 15`, `cooldownDuration = 10`, metadata `{ maxRange = 18 }`
  - `SummonA`: `displayName = "Swarm Drones"`, `energyCost = 20`, `cooldownDuration = 18`, metadata `{ summonCount = 5, lifetime = 20 }`
  - `SummonB`: `displayName = "Elite Guardian"`, `energyCost = 45`, `cooldownDuration = 25`, metadata `{ lifetime = 30, stationary = true }`
  - `Control`: `displayName = "Gravity Pulse"`, `energyCost = 25`, `cooldownDuration = 14`, metadata `{ radius = 10, knockbackStuds = 8, slowDuration = 1.5 }`
  - `Ultimate`: `displayName = "Overcharge Field"`, `energyCost = 70`, `cooldownDuration = 55`, metadata `{ channelTime = 1, interruptibleByDamage = true, radius = 25, stunDuration = 3, structureAttackSpeedMultiplier = 1.5, buffDuration = 8 }`
- Numbers are v0 balance values from the GDD, not placeholders. Ability effects can still be stubbed in Phase 1.
- `table.freeze` the entire config (freeze inner tables too)

**Exit criteria:** Module requires cleanly; all slot defs accessible.

---

### Step 3 — SharedAtoms (shared)

**Objective:** Charm atom factories for server and client.

**File:** `src/ReplicatedStorage/Contexts/Commander/Sync/SharedAtoms.lua`

**Tasks:**
- Import `Charm` from packages
- `CreateServerAtom()` — returns `Charm.atom({} :: CommanderAtomState)`
- `CreateClientAtom()` — returns `Charm.atom({} :: CommanderAtomState)`
- Export both factory functions

**Exit criteria:** Both factory functions callable; atom holds typed `CommanderAtomState`.

---

### Step 4 — Errors.lua

**File:** `src/ServerScriptService/Contexts/Commander/Errors.lua`

**Tasks:**
- `INVALID_SLOT = "CommanderContext: invalid ability slot key"`
- `ABILITY_ON_COOLDOWN = "CommanderContext: ability is on cooldown"`
- `INSUFFICIENT_ENERGY = "CommanderContext: not enough energy to use this ability"`
- `COMMANDER_NOT_FOUND = "CommanderContext: commander state not found for player"`
- `table.freeze`

**Exit criteria:** All constants importable; no duplicate keys.

---

### Step 5 — AbilitySlot ValueObject (domain)

**Objective:** Immutable record wrapping a slot definition. Ensures slot data is never mutated in flight.

**File:** `src/ServerScriptService/Contexts/Commander/CommanderDomain/ValueObjects/AbilitySlot.lua`

**Tasks:**
- `AbilitySlot.new(def: AbilitySlotDef): AbilitySlot`
- Fields: `Key`, `DisplayName`, `EnergyCost`, `CooldownDuration`, `Metadata`
- `table.freeze` the returned instance

**Exit criteria:** `AbilitySlot.new(def)` returns frozen record; all fields readable.

---

### Step 6 — CommanderSyncService (server infrastructure)

**Objective:** Owns the Charm atom. The only place that writes commander state. Provides deep-clone getters.

**File:** `src/ServerScriptService/Contexts/Commander/Infrastructure/Persistence/CommanderSyncService.lua`

Inherits from `BaseSyncService` (`src/ReplicatedStorage/Utilities/BaseSyncService.lua`).

**Tasks:**
- Set `AtomKey = "commander"`, `BlinkEventName = "SyncCommander"`, `CreateAtom = SharedAtoms.CreateServerAtom`
- `LoadPlayer(userId: number)` — initializes atom entry:
  `{ hp = CommanderConfig.MAX_HP, maxHp = CommanderConfig.MAX_HP, cooldowns = {} }`
  New entry = new table; no cloning needed.
- `RemovePlayer(userId: number)` — clears atom entry (inherited `RemoveUserData`)
- `SetHP(userId: number, newHp: number)` — targeted clone path: `updated[userId] = table.clone(updated[userId]); updated[userId].hp = newHp`
- `ApplyDamage(userId: number, amount: number): number` — reads current HP via `GetStateReadOnly`, computes `math.max(0, hp - amount)`, calls `SetHP`, returns new HP value
- `SetCooldown(userId: number, slotKey: string, duration: number)` — 3-level targeted clone: `updated[userId] = clone; updated[userId].cooldowns = clone; updated[userId].cooldowns[slotKey] = { startedAt = os.clock(), duration = duration }`
- `ClearCooldown(userId: number, slotKey: string)` — 2-level targeted clone; sets `cooldowns[slotKey] = nil`
- `GetStateReadOnly(userId: number): CommanderState?` — returns deep clone (inherited BaseSyncService pattern)
- `HydratePlayer(player: Player)` — inherited; sends full atom state to joining client

**Exit criteria:** All mutations use targeted cloning. `GetStateReadOnly` returns a deep clone. Atom grows/shrinks per player join/leave.

---

### Step 7 — CooldownService (domain service)

**Objective:** Pure cooldown logic — reads state and computes readiness only.

**File:** `src/ServerScriptService/Contexts/Commander/CommanderDomain/Services/CooldownService.lua`

**Tasks:**
- Constructor `CooldownService.new()`
- `Init(registry, _name)` — `self._sync = registry:Get("CommanderSyncService")`
- `IsReady(userId: number, slotKey: string): boolean`
  - Reads `self._sync:GetStateReadOnly(userId)`
  - Returns true if `cooldowns[slotKey]` is nil OR `os.clock() - startedAt >= duration`
- `GetRemainingTime(userId: number, slotKey: string): number`
  - Returns seconds remaining (clamped to 0 if ready)

**Data:** Reads state via SyncService deep clone; no writes.

**Exit criteria:** `IsReady` returns true for fresh state; returns false immediately after sync cooldown is written; returns true once duration elapses.

---

### Step 8 — AbilityService (domain service)

**Objective:** Owns kit slot definitions. Executes stub ability logic. Validates energy (stub).

**File:** `src/ServerScriptService/Contexts/Commander/CommanderDomain/Services/AbilityService.lua`

**Tasks:**
- Constructor `AbilityService.new()`
- `Init(registry, _name)` — builds `self._slots: { [string]: AbilitySlot }` map from `CommanderConfig.SLOTS` using `AbilitySlot.new(def)` for each entry
- `GetSlot(slotKey: string): AbilitySlot?` — returns frozen slot def or nil
- `CanAffordAbility(userId: number, slotKey: string): boolean`
  - **Stub**: always returns `true`
  - Add inline comment: `-- TODO: replace with EconomyContext:SpendEnergy(player, slot.EnergyCost) when EconomyContext exists`
- `ExecuteStub(userId: number, slotKey: string)` — **no-op stub**: logs `Result.MentionEvent` with slot name and userId; no game effect

**Exit criteria:** `_slots` map built from config. `GetSlot("Mobility")` returns correct frozen record. `ExecuteStub` logs without error.

---

### Step 9 — UseAbilityCommand (application layer)

**Objective:** Full CQRS command — validate cooldown + affordability, execute stub, start cooldown.

**File:** `src/ServerScriptService/Contexts/Commander/Application/Commands/UseAbilityCommand.lua`

**Tasks:**
- Constructor `UseAbilityCommand.new()`
- `Init(registry, _name)`:
  - `self._abilityService = registry:Get("AbilityService")`
  - `self._cooldownService = registry:Get("CooldownService")`
  - `self._syncService = registry:Get("CommanderSyncService")`
- `Execute(player: Player, slotKey: string): Result`
  1. `local slot = Result.Ensure(self._abilityService:GetSlot(slotKey), "InvalidSlot", Errors.INVALID_SLOT)` — validate slotKey
  2. `Result.Ensure(self._cooldownService:IsReady(player.UserId, slotKey), "OnCooldown", Errors.ABILITY_ON_COOLDOWN)`
  3. `Result.Ensure(self._abilityService:CanAffordAbility(player.UserId, slotKey), "InsufficientEnergy", Errors.INSUFFICIENT_ENERGY)`
  4. Later integration: spend Energy through `EconomyContext:SpendEnergy(player, slot.EnergyCost)` before execution; Phase 1 stub can keep affordability true until EconomyContext exists
  5. `self._abilityService:ExecuteStub(player.UserId, slotKey)` — stub execution
  6. `self._syncService:SetCooldown(player.UserId, slotKey, slot.CooldownDuration)`
  7. Return `Result.Ok({ slotKey = slotKey })`

**Guards:** All validation before any mutation. Steps 1–3 are pure checks; steps 5–6 are writes.

**Exit criteria:** Command rejects invalid slot; rejects during active cooldown; calls stub and writes cooldown on success.

---

### Step 10 — Query modules (application layer)

**Objective:** Thin CQRS read wrappers. No domain logic.

**Files:**

`GetCommanderStateQuery.lua`
- Constructor `GetCommanderStateQuery.new()`
- `Init(registry, _name)` — `self._sync = registry:Get("CommanderSyncService")`
- `Execute(userId: number): CommanderState?` — returns `self._sync:GetStateReadOnly(userId)`

`GetCooldownQuery.lua`
- Constructor `GetCooldownQuery.new()`
- `Init(registry, _name)` — `self._cooldownService = registry:Get("CooldownService")`
- `Execute(userId: number, slotKey: string): number` — returns `self._cooldownService:GetRemainingTime(userId, slotKey)`

**Exit criteria:** Queries return correct data; no domain logic; no mutations.

---

### Step 11 — CommanderContext Knit service

**Objective:** Wire all services. Expose server API for other contexts. Expose Client remote for `UseAbility`. Fire `CommanderDied` on HP = 0.

**File:** `src/ServerScriptService/Contexts/Commander/CommanderContext.lua`

**`KnitInit()`:**
- `local registry = Registry.new("Commander")`
- Register `CommanderSyncService.new()` → `"Infrastructure"`
- Register `AbilityService.new()` → `"Domain"`
- Register `CooldownService.new()` → `"Domain"`
- Register `UseAbilityCommand.new()` → `"Application"`
- Register `GetCommanderStateQuery.new()` → `"Application"`
- Register `GetCooldownQuery.new()` → `"Application"`
- `registry:InitAll()` — injects dependencies via `Init(registry, name)` on each module
- Store references: `self._sync`, `self._useAbilityCmd`, `self._getStateQuery`, `self._getCooldownQuery`
- Create `self.CommanderDied = Instance.new("BindableEvent")` — RunContext subscribes to `.Event`

**`KnitStart()`:**
- `Players.PlayerAdded:Connect(function(player) self._sync:LoadPlayer(player.UserId); self._sync:HydratePlayer(player) end)`
- `Players.PlayerRemoving:Connect(function(player) self._sync:RemovePlayer(player.UserId) end)`
- Iterate `Players:GetPlayers()` for late-join safety
- Subscribe to atom to detect HP = 0:
  ```
  Charm.effect(function()
      local state = self._sync.Atom()
      for userId, commander in state do
          if commander.hp <= 0 then
              local player = Players:GetPlayerByUserId(userId)
              if player then self.CommanderDied:Fire(player) end
          end
      end
  end)
  ```
  *(Alternative: check inside `ApplyDamage` directly — simpler and avoids Charm.effect overhead. Preferred.)*

**Public server API** (called by other server contexts via `Knit.GetService("CommanderContext")`):
- `CommanderContext:ApplyDamage(player: Player, amount: number): number` — proxies to SyncService
- `CommanderContext:GetCommanderState(userId: number): CommanderState?` — proxies to GetCommanderStateQuery
- `CommanderContext:GetCooldownRemaining(userId: number, slotKey: string): number` — proxies to GetCooldownQuery

**Client remote** (called by client via Knit):
- `CommanderContext.Client:UseAbility(player: Player, slotKey: string): Result`
  - Validates `slotKey` is a known string before passing to command (anti-exploit)
  - Calls `self.Server._useAbilityCmd:Execute(player, slotKey)` wrapped in `Result.Catch`

**Bottom of file:** `WrapContext(CommanderContext, "CommanderContext")`

**Exit criteria:** Server starts cleanly. Player join populates atom. `ApplyDamage` to 0 fires `CommanderDied`. Client remote rejects bad slotKey. `Knit.GetService("CommanderContext")` works from other server contexts.

---

### Step 12 — CommanderSyncClient (client infrastructure)

**Objective:** Client-side Charm atom that receives server patches.

**File:** `src/StarterPlayerScripts/Contexts/Commander/Infrastructure/CommanderSyncClient.lua`

**Tasks:**
- Subclass `BaseSyncClient` (`src/ReplicatedStorage/Utilities/BaseSyncClient.lua`)
- Set `BlinkEventName = "SyncCommander"`, `AtomKey = "commander"`, `CreateAtom = SharedAtoms.CreateClientAtom`
- Expose `GetAtom(): () -> CommanderAtomState` (inherited)

**Exit criteria:** After server hydration, local atom reflects server state.

---

### Step 13 — CommanderController (client)

**Objective:** Knit controller; starts sync, exposes atom to future UI hooks.

**File:** `src/StarterPlayerScripts/Contexts/Commander/CommanderController.lua`

**Tasks:**
- `Knit.CreateController({ Name = "CommanderController" })`
- `KnitInit()` — `self._syncClient = CommanderSyncClient.new()`
- `KnitStart()` — `self._syncClient:Start()`
- `GetAtom()` — returns client Charm atom (consumed by future UI hooks)

**Exit criteria:** Client atom updates when server fires damage or ability use.

---

## Verification Checklist

### Functional
- [ ] Server starts with no errors; CommanderContext auto-discovered by Knit
- [ ] Player join creates atom entry: full HP, empty cooldowns
- [ ] Player leave removes atom entry
- [ ] `ApplyDamage(player, 30)` reduces HP from 100 to 70; Charm patch reaches client
- [ ] `ApplyDamage(player, 200)` clamps HP to 0; `CommanderDied` fires
- [ ] `UseAbility("Mobility")` succeeds on fresh state; cooldown entry written to atom
- [ ] Second `UseAbility("Mobility")` within cooldown window → `OnCooldown` error returned
- [ ] After `cooldownDuration` seconds, `IsReady("Mobility")` returns true again
- [ ] Invalid slotKey from client remote → `INVALID_SLOT` error; no mutation
- [ ] Client atom reflects HP change after server damage call
- [ ] Client atom reflects cooldown start after UseAbility

### Edge Cases
- [ ] `ApplyDamage` with amount > currentHp clamps to 0 (no negative HP)
- [ ] `UseAbility` called with empty string → rejects at `GetSlot` guard
- [ ] Late-joining player receives hydrated state (existing HP/cooldowns from atom)
- [ ] `ApplyDamage` while player HP is already 0 does not double-fire `CommanderDied`

### Security
- [ ] `UseAbility` client remote validates slotKey before any logic
- [ ] HP is never set by client remote — server-only via `ApplyDamage`
- [ ] No client remote exposes `SetHP`, `SetCooldown`, or `LoadPlayer`
- [ ] `CommanderDied` BindableEvent is server-only (not a Knit Client remote)

### Performance
- [ ] No per-frame ECS system — cooldowns are timestamp-based `os.clock()` diffs
- [ ] Atom mutations use targeted cloning (not full-table clones)
- [ ] Grid build (WorldContext) is unrelated — no coupling

---

## Critical Files

| File | Action |
|---|---|
| `src/ReplicatedStorage/Contexts/Commander/Types/CommanderTypes.lua` | Create |
| `src/ReplicatedStorage/Contexts/Commander/Config/CommanderConfig.lua` | Create |
| `src/ReplicatedStorage/Contexts/Commander/Sync/SharedAtoms.lua` | Create |
| `src/ServerScriptService/Contexts/Commander/Errors.lua` | Create |
| `src/ServerScriptService/Contexts/Commander/CommanderDomain/ValueObjects/AbilitySlot.lua` | Create |
| `src/ServerScriptService/Contexts/Commander/Infrastructure/Persistence/CommanderSyncService.lua` | Create |
| `src/ServerScriptService/Contexts/Commander/CommanderDomain/Services/CooldownService.lua` | Create |
| `src/ServerScriptService/Contexts/Commander/CommanderDomain/Services/AbilityService.lua` | Create |
| `src/ServerScriptService/Contexts/Commander/Application/Commands/UseAbilityCommand.lua` | Create |
| `src/ServerScriptService/Contexts/Commander/Application/Queries/GetCommanderStateQuery.lua` | Create |
| `src/ServerScriptService/Contexts/Commander/Application/Queries/GetCooldownQuery.lua` | Create |
| `src/ServerScriptService/Contexts/Commander/CommanderContext.lua` | Create |
| `src/StarterPlayerScripts/Contexts/Commander/Infrastructure/CommanderSyncClient.lua` | Create |
| `src/StarterPlayerScripts/Contexts/Commander/CommanderController.lua` | Create |

## Reusable Utilities

| Utility | Path | Usage |
|---|---|---|
| `BaseSyncService` | `src/ReplicatedStorage/Utilities/BaseSyncService.lua` | CommanderSyncService base class |
| `BaseSyncClient` | `src/ReplicatedStorage/Utilities/BaseSyncClient.lua` | CommanderSyncClient base class |
| `Registry` | `src/ReplicatedStorage/Utilities/Registry.lua` | Dependency injection in KnitInit |
| `Result` | `src/ReplicatedStorage/Utilities/Result.lua` | Error propagation in commands |
| `WrapContext` | `src/ReplicatedStorage/Utilities/WrapContext.lua` | Client remote error wrapping |
| Knit | `ReplicatedStorage.Packages.Knit` | Service/controller lifecycle |
| Charm | `ReplicatedStorage.Packages.Charm` | Atom creation in SharedAtoms |

---

## Recommended First Build Step

**Steps 1 + 2 + 3 + 4** (Types + Config + SharedAtoms + Errors) — all unblocked, no dependencies between them, can be done in parallel.
Then **Step 5** (AbilitySlot ValueObject) — depends on types only.
Then **Step 6** (CommanderSyncService) — the core state owner; depends on SharedAtoms + Config.
Then **Steps 7 + 8** (CooldownService + AbilityService) — depend on SyncService; can be done in parallel.
Then **Steps 9 + 10** (UseAbilityCommand + Queries) — depend on domain services.
Then **Step 11** (CommanderContext) — wires everything together.
Then **Steps 12 + 13** (client side) — depend on SharedAtoms only; can be written earlier but tested after server is up.



