# EconomyContext — Multi-Resource Economy Management

## Context

The GDD (§7, revised 2026-04-20) defines a **multi-resource economy**. **Energy** is the primary action resource; **zone resources** are the crafting/building economy produced by extractor structures on side-pocket tiles. Every spend is a visible tradeoff between action economy, build economy, commander safety, and upgrade tempo. EconomyContext owns authoritative per-player resource balances and is the integration hub between RunContext, WaveContext/EnemyContext, PlacementContext, CommanderContext, and the now-in-scope structure/crafting systems.

This plan follows the project's DDD/Knit pattern: Knit service (pass-through) → Application layer (Commands + Queries) → Domain layer (validator) → Infrastructure layer (Charm atom + Blink sync). The complete resource wallet replicates to clients via `BaseSyncService` / `BaseSyncClient` + Blink.

User answers that shaped this plan:
- Income: **per-kill reward** + **wave-clear bonus**
- Sinks: place structure, deploy summon, repair structure, upgrade choice
- Replication: Yes — Charm atom + Blink (same pattern as RunContext)
- Scope: Per-player (solo + co-op ready)

---

## GDD Update Delta

This section supersedes any Energy-only language that remains later in the file.

- EconomyContext must own **Energy plus zone resources**, not only Energy.
- Enemy death no longer automatically means direct Energy income. Enemy deaths should emit enough facts for a future pickup/drop path; EconomyContext may expose direct add APIs for Phase 1 testing, but the design target is enemy drops/pickups.
- Zone resources are earned by extractor/resource structures placed on `side_pocket` tiles. The extractor tick/source can be stubbed in Phase 1, but the data model must support it.
- Crafting and structure upgrades are now in scope. EconomyContext should provide generic resource spend/add APIs that Structure/Crafting systems can call.
- Soft caps and overflow waste are part of the economy design and must be represented in config and validator logic.

## Goal

Build a server-authoritative `EconomyContext` Knit service that:
1. Owns a **per-player resource wallet**: `energy` plus a `resources` map keyed by zone resource type.
2. Earns resources through wave-clear Energy bonus, extractor income, and future enemy drop/pickup grants.
3. Validates and executes resource spends for Energy sinks (abilities, placement, repair) and zone-resource sinks (crafting, unlocks, upgrades).
4. Applies per-resource caps and overflow waste before mutating balances.
5. Replicates the complete wallet to each player's client via **Charm atom + Blink** (`BaseSyncService` / `BaseSyncClient`).
6. Exposes server-side query APIs for other contexts to read balances and affordability.

---

## Short Action Flow

```
[Income: resource grant]
  Extractor tick / pickup collection / wave clear
    → EconomyContext:AddResource(player, resourceType, amount)
        → ResourceValidator:ValidateEarn(resourceType, amount)
        → ResourceSyncService:AddResource(userId, resourceType, amount)
            → Applies cap/overflow rules
            → Atom updated: { [userId] = { energy = n, resources = { [resourceType] = n } } }
            → CharmSync delta → Blink SyncResources → client atom updated

[Income: wave-clear bonus]
  RunContext StateChanged fires "Resolution"
    → EconomyContext KnitStart subscription: for each player
        → AddResourceCommand:Execute(userId, "Energy", WAVE_CLEAR_BONUS)

[Spend: any sink]
  PlacementContext / CommanderContext / StructureContext calls EconomyContext:SpendResource(player, resourceType, cost)
    → SpendResourceCommand:Execute(userId, resourceType, cost)
        → ResourceSyncService:GetBalance(userId, resourceType) → currentBalance
        → ResourceValidator:ValidateSpend(resourceType, currentBalance, cost)
        → if Ok → ResourceSyncService:SubtractResource(userId, resourceType, cost)
        → Returns Result.Ok or Result.Err(INSUFFICIENT_ENERGY) to caller

[Query: read balance]
  Any server context calls EconomyContext:GetBalance(player, resourceType)
    → GetResourceBalanceQuery:Execute(userId, resourceType)
        → ResourceSyncService:GetReadOnly(userId) → deep-cloned wallet

[Run lifecycle]
  RunContext StateChanged "Prep" (from "Idle") → init all players with STARTING_WALLET
  RunContext StateChanged "RunEnd"              → clear all player resource wallets from atom
```

---

## Assumptions

- All resource balances are integers (no fractional amounts).
- Per-player atom shape: `{ [number]: ResourceWallet }`, where `ResourceWallet = { energy: number, resources: { [ResourceType]: number } }`.
- `BaseSyncService` and `BaseSyncClient` are reused directly (no subclass needed — atom shape is a simple flat map).
- RunContext exposes a `StateChanged` Signal (per RunContextPlan) that EconomyContext subscribes to in `KnitStart()`.
- EnemyContext death events should include enemy role and death position. Direct `AddKillReward` is a Phase 1 testing helper only; final drop/pickup routing belongs to a future drop/pickup integration.
- Wallet is initialized to `EconomyConfig.STARTING_WALLET` when run starts (RunContext Idle → Prep).
- Wallet atom entry is cleared when run ends (RunContext → RunEnd).
- Negative balances are never allowed; spends below 0 return `Result.Err`.
- Energy remains the resource type used for commander abilities, placement costs, and repairs.
- Zone resources are used for structure crafting/unlocks and upgrades.

---

## Ambiguities Resolved

| Question | Decision |
|---|---|
| Per-player or global pool? | Per-player wallet atom. Co-op shared pool is Phase 2. |
| Kill reward amount? | Defer final policy to pickup/drop design; expose generic add APIs for testing. |
| Wave-clear bonus amount? | Config constant `WAVE_CLEAR_BONUS` grants Energy. Tunable. |
| Starting wallet? | Config constant `STARTING_WALLET = { energy = 20, resources = {} }`. Tunable. |
| Do resources persist between runs? | No — reset to `STARTING_WALLET` on each RunStart (Idle → Prep). |
| Do resources carry over between waves? | Yes — wallet persists within a run, capped by resource cap config. |
| Does EconomyContext need ECS? | No — plain Luau atom. |

---

## Files to Create

### Create (Shared / ReplicatedStorage)
```
src/ReplicatedStorage/Contexts/Economy/
  Config/
    EconomyConfig.lua          ← STARTING_WALLET, WAVE_CLEAR_BONUS, RESOURCE_CAPS, RESOURCE_TYPES
  Types/
    EconomyTypes.lua           ← ResourceType, ResourceWallet, ResourceAtom type aliases
  Sync/
    SharedAtoms.lua            ← CreateServerAtom / CreateClientAtom
```

### Create (Network)
```
src/Network/
  ResourceSync.blink           ← Blink definition (Server → Client, Reliable, SingleAsync)
  Generated/
    ResourceSyncServer.luau    ← generated
    ResourceSyncClient.luau    ← generated
```

### Create (Server)
```
src/ServerScriptService/Contexts/Economy/
  EconomyContext.lua                      ← Knit service
  Errors.lua                              ← Error constants
  Application/
    Commands/
      AddResourceCommand.lua              ← Add Energy or zone resource
      SpendResourceCommand.lua            ← Deduct Energy or zone resource (validates first)
    Queries/
      GetResourceBalanceQuery.lua         ← Read one balance for a player
      GetResourceWalletQuery.lua          ← Read full wallet for a player
  EconomyDomain/
    Services/
      ResourceValidator.lua               ← Pure: ValidateEarn, ValidateSpend, caps
  Infrastructure/
    Persistence/
      ResourceSyncService.lua             ← Extends BaseSyncService; owns wallet atom
```

### Create (Client)
```
src/StarterPlayerScripts/Contexts/Economy/
  Infrastructure/
    ResourceSyncClient.lua                ← BaseSyncClient wrapper
```

---

## Implementation Plan

### Step 1 — ResourceSync.blink + generate

**Objective:** Define the Blink network contract for resource wallet replication. Follows the same `init` / `patch` enum pattern as `GoldSync.blink`.

**File:** `src/Network/ResourceSync.blink`

**Tasks:**
- `option RemoteScope = "RESOURCE_SYNC"`
- `option ServerOutput = "Generated/ResourceSyncServer.luau"`
- `option ClientOutput = "Generated/ResourceSyncClient.luau"`
- Payload shape represents `{ energy: u32, resources: { [string]: u32 } }` for one player's wallet; use the repo's existing Blink-supported map/table representation if available, otherwise encode as a list of `{ resourceType, amount }` records.
- `enum SyncPayload = "type" { init { data: InitPayload? }, patch { data: PatchPayload? } }`
- `event SyncResources { from: Server, type: Reliable, call: SingleAsync, data: SyncPayload }`
- Run `blink` CLI → generates `ResourceSyncServer.luau` and `ResourceSyncClient.luau` into `src/Network/Generated/`

**Dependencies:** None
**Exit criteria:** Generated files exist; `SyncResources` event present in both

---

### Step 2 — EconomyConfig (shared)

**Objective:** All Economy constants in one frozen module.

**File:** `src/ReplicatedStorage/Contexts/Economy/Config/EconomyConfig.lua`

**Tasks:**
- `STARTING_WALLET = { energy = 20, resources = {} }`
- `WAVE_CLEAR_BONUS = 10`
- `RESOURCE_TYPES = { "Metal", "Crystal" }` placeholder until resource names are locked in structure roster GDD
- `RESOURCE_CAPS = { Energy = 100, Metal = 50, Crystal = 50 }` placeholder caps; overflow is wasted
- `PICKUP_GRANTS = { default = { resourceType = "Energy", amount = 1 } }` testing helper only
- `table.freeze` module and inner tables

**Module ownership:** ReplicatedStorage (shared — client can read later without a Remote)
**Exit criteria:** All constants accessible; `RESOURCE_CAPS` and `STARTING_WALLET` are readable

---

### Step 3 — EconomyTypes (shared)

**Objective:** Luau strict-mode types for the resource wallet atom shape.

**File:** `src/ReplicatedStorage/Contexts/Economy/Types/EconomyTypes.lua`

**Tasks:**
- `export type ResourceType = "Energy" | string` — narrowed when resource names are finalized
- `export type ZoneResourceMap = { [string]: number }`
- `export type ResourceWallet = { energy: number, resources: ZoneResourceMap }`
- `export type ResourceAtom = { [number]: ResourceWallet }` — keyed by userId

**Module ownership:** ReplicatedStorage
**Exit criteria:** Type importable under `--!strict` with no errors

---

### Step 4 — SharedAtoms (shared)

**Objective:** Charm atom factories for server and client. Same pattern as Log and Run contexts.

**File:** `src/ReplicatedStorage/Contexts/Economy/Sync/SharedAtoms.lua`

**Tasks:**
- Import `Charm` from `ReplicatedStorage.Packages.Charm`
- `CreateServerAtom()` → `Charm.atom({} :: ResourceAtom)`
- `CreateClientAtom()` → `Charm.atom({} :: ResourceAtom)`
- Return `{ CreateServerAtom = CreateServerAtom, CreateClientAtom = CreateClientAtom }`

**Module ownership:** ReplicatedStorage
**Exit criteria:** Both factory functions callable; atoms hold correct initial shape (`{}`)

---

### Step 5 — Errors.lua

**Objective:** Centralized error constants for EconomyContext.

**File:** `src/ServerScriptService/Contexts/Economy/Errors.lua`

**Tasks:**
- `INSUFFICIENT_ENERGY = "EconomyContext: player does not have enough energy"`
- `INVALID_AMOUNT = "EconomyContext: energy amount must be a positive integer"`
- `PLAYER_NOT_INITIALIZED = "EconomyContext: player energy not initialized"`
- `table.freeze`

**Exit criteria:** Constants importable; module requires without error

---

### Step 6 — ResourceValidator (domain service)

**Objective:** Pure, stateless domain service. No infrastructure dependencies. Returns `Result`.

**File:** `src/ServerScriptService/Contexts/Economy/EconomyDomain/Services/ResourceValidator.lua`

**Constructor:** `ResourceValidator.new()` — no arguments

**Methods:**
- `ValidateEarn(resourceType: string, amount: number): Result`
  - Guards: `resourceType` is known or allowed by config; `amount` must be an integer > 0
  - Returns `Result.Ok(amount)` or `Result.Err(Errors.INVALID_AMOUNT)`
- `ValidateSpend(resourceType: string, currentBalance: number, cost: number): Result`
  - Guards: `resourceType` is known or allowed by config; `cost` must be integer > 0; `currentBalance >= cost`
  - Returns `Result.Ok(cost)` or `Result.Err(Errors.INSUFFICIENT_ENERGY)` / `Result.Err(Errors.INVALID_AMOUNT)`
- `ApplyCap(resourceType: string, currentBalance: number, addAmount: number): number`
  - Returns the accepted amount after cap; overflow is wasted per GDD anti-snowball rule.

**Data inputs:** plain numbers
**Data outputs:** `Result.Ok` or `Result.Err`
**No side effects** — pure function
**Module ownership:** Server domain layer
**Exit criteria:** All valid inputs return Ok; all invalid inputs return correct Err type without mutation

---

### Step 7 — ResourceSyncService (server infrastructure)

**Objective:** Owns per-player resource wallet atom. Extends `BaseSyncService`. Provides init, add, subtract, remove operations.

**File:** `src/ServerScriptService/Contexts/Economy/Infrastructure/Persistence/ResourceSyncService.lua`

**Pattern:** `setmetatable({}, { __index = BaseSyncService })` — inherits `Init`, `HydratePlayer`, `GetReadOnly`, `LoadUserData`, `RemoveUserData`, `Destroy`

**Class fields (set before `new`):**
- `ResourceSyncService.AtomKey = "resources"`
- `ResourceSyncService.BlinkEventName = "SyncResources"`
- `ResourceSyncService.CreateAtom = SharedAtoms.CreateServerAtom`

**Constructor:** `ResourceSyncService.new()` → `setmetatable({}, ResourceSyncService)`

**Additional methods:**
- `InitPlayer(userId: number, startingWallet: ResourceWallet)` → calls `self:LoadUserData(userId, startingWallet)`
- `AddResource(userId: number, resourceType: string, amount: number)` → targeted clone; Energy writes `wallet.energy`, zone resources write `wallet.resources[resourceType]`
- `SubtractResource(userId: number, resourceType: string, cost: number)` → targeted clone; never allows negative values because command validates first
- `GetBalance(userId: number, resourceType: string): number?` → reads Energy or zone resource balance
- `GetWallet(userId: number): ResourceWallet?` → read full wallet for queries
- `RemovePlayer(userId: number)` → calls `self:RemoveUserData(userId)`

**`Init(registry, name)`:** calls `BaseSyncService.Init(self, registry, name)` — wires CharmSync.server + Blink

**Trigger:** Called during `EconomyContext:KnitInit()` via Registry
**Exit criteria:** `InitPlayer` sets atom to `STARTING_WALLET`; `AddResource` increments correct balance with cap behavior; `SubtractResource` decrements correct balance; `RemovePlayer` removes key; `GetReadOnly` returns deep clone

---

### Step 8 — AddResourceCommand (application layer)

**Objective:** Write command — validates then adds Energy or zone resources. Full DDD stack: Application → Domain → Infrastructure.

**File:** `src/ServerScriptService/Contexts/Economy/Application/Commands/AddResourceCommand.lua`

**Constructor:** `AddResourceCommand.new(validator: ResourceValidator, syncService: ResourceSyncService)`

**Method:** `Execute(userId: number, resourceType: string, amount: number): Result`
1. `self._validator:ValidateEarn(resourceType, amount)` → if Err, return early (no mutation)
2. `self._syncService:AddResource(userId, resourceType, amount)`
3. `Result.MentionSuccess("EconomyContext:AddResourceCommand", "Resource earned", { userId = userId, resourceType = resourceType, amount = amount })`
4. `return Result.Ok(nil)`

**Guards:** Validation runs before any mutation
**Module ownership:** Server application layer
**Exit criteria:** Returns Ok and atom is updated; returns Err with no mutation if amount invalid

---

### Step 9 — SpendResourceCommand (application layer)

**Objective:** Write command — validates sufficient balance, then deducts. No partial state.

**File:** `src/ServerScriptService/Contexts/Economy/Application/Commands/SpendResourceCommand.lua`

**Constructor:** `SpendResourceCommand.new(validator: ResourceValidator, syncService: ResourceSyncService)`

**Method:** `Execute(userId: number, resourceType: string, cost: number): Result`
1. `currentBalance = self._syncService:GetBalance(userId, resourceType)` → if nil, return `Result.Err(Errors.PLAYER_NOT_INITIALIZED)`
2. `self._validator:ValidateSpend(resourceType, currentBalance, cost)` → if Err, return Err (no mutation)
3. `self._syncService:SubtractResource(userId, resourceType, cost)`
4. `Result.MentionSuccess("EconomyContext:SpendResourceCommand", "Resource spent", { userId = userId, resourceType = resourceType, cost = cost })`
5. `return Result.Ok(nil)`

**Guards:** Balance check before mutation; negative balance impossible
**Module ownership:** Server application layer
**Exit criteria:** Deducts only when valid; balance unchanged on any Err return

---

### Step 10 — Resource queries (application layer)

**Objective:** Read-only queries returning current resource balances for a player.

**Files:** `src/ServerScriptService/Contexts/Economy/Application/Queries/GetResourceBalanceQuery.lua`, `GetResourceWalletQuery.lua`

**Constructor:** `GetResourceBalanceQuery.new(syncService: ResourceSyncService)`, `GetResourceWalletQuery.new(syncService: ResourceSyncService)`

**Methods:**
- `GetResourceBalanceQuery:Execute(userId: number, resourceType: string): number?`
- `GetResourceWalletQuery:Execute(userId: number): ResourceWallet?`

**Data outputs:** `number?` — no Result wrapper (CQRS convention: queries return plain values)
**Module ownership:** Server application layer
**Exit criteria:** Returns correct balance; returns nil for uninitialized userId

---

### Step 11 — EconomyContext Knit service

**Objective:** Wire all infrastructure. Subscribe to RunContext StateChanged. Expose public server API.

**File:** `src/ServerScriptService/Contexts/Economy/EconomyContext.lua`

**`KnitInit()`:**
- `Registry.new("Economy")`
- `registry:Register("BlinkServer", BlinkResourceSyncServer)`
- `registry:Register("ResourceSyncService", ResourceSyncService.new(), "Infrastructure")`
- `registry:InitAll()`
- Store ref: `self._sync = registry:Get("ResourceSyncService")`
- Instantiate: `self._validator = ResourceValidator.new()`
- Instantiate: `self._addResourceCmd = AddResourceCommand.new(self._validator, self._sync)`
- Instantiate: `self._spendResourceCmd = SpendResourceCommand.new(self._validator, self._sync)`
- Instantiate: `self._getBalanceQuery = GetResourceBalanceQuery.new(self._sync)`
- Instantiate: `self._getWalletQuery = GetResourceWalletQuery.new(self._sync)`

**`KnitStart()`:**
- `Players.PlayerAdded:Connect(player → self._sync:HydratePlayer(player))`
- Hydrate any already-present players
- `Players.PlayerRemoving:Connect(player → self._sync:RemovePlayer(player.UserId))`
- Subscribe to RunContext state changes:
  ```
  RunContext.StateChanged:Connect(function(newState, prevState)
      if newState == "Prep" and prevState == "Idle" then
          for _, player in Players:GetPlayers() do
              self._sync:InitPlayer(player.UserId, EconomyConfig.STARTING_WALLET)
          end
      elseif newState == "Resolution" then
          for _, player in Players:GetPlayers() do
              self._earnCmd:Execute(player.UserId, EconomyConfig.WAVE_CLEAR_BONUS)
          end
      elseif newState == "RunEnd" then
          for _, player in Players:GetPlayers() do
              self._sync:RemovePlayer(player.UserId)
          end
      end
  end)
  ```

**Public server API** (called via `Knit.GetService("EconomyContext")`):
- `EconomyContext:GetBalance(player: Player, resourceType: string): number?` → wraps `GetResourceBalanceQuery:Execute(userId, resourceType)`
- `EconomyContext:GetWallet(player: Player): ResourceWallet?` → wraps `GetResourceWalletQuery:Execute(userId)`
- `EconomyContext:AddResource(player: Player, resourceType: string, amount: number): Result` → wraps `AddResourceCommand:Execute(userId, resourceType, amount)`
- `EconomyContext:SpendResource(player: Player, resourceType: string, cost: number): Result` → wraps `SpendResourceCommand:Execute(userId, resourceType, cost)`
- `EconomyContext:GetEnergy(player: Player): number?` → convenience wrapper for `GetBalance(player, "Energy")`
- `EconomyContext:SpendEnergy(player: Player, cost: number): Result` → convenience wrapper for commander abilities, placement, and repairs
- `EconomyContext:AddPickupGrant(player: Player, grant: { resourceType: string, amount: number }): Result` → testing hook for future pickup/drop integration

**No Client remotes** — replication is via Charm-sync/Blink only
**Exit criteria:** On RunStart → each player initialized with STARTING_WALLET; wave clear → Energy bonus added; zone resources can be added/spent by resource type; `SpendEnergy` remains available as a convenience wrapper; client atom updates within CharmSync interval

---

### Step 12 — ResourceSyncClient (client infrastructure)

**Objective:** Client-side Charm atom that stays in sync with the server resource wallet.

**File:** `src/StarterPlayerScripts/Contexts/Economy/Infrastructure/ResourceSyncClient.lua`

**Pattern:** Direct `BaseSyncClient.new()` — no subclass needed.

**Constructor:** `ResourceSyncClient.new(blinkClient)`
- Calls `BaseSyncClient.new(blinkClient, "SyncResources", "resources", SharedAtoms.CreateClientAtom)`

**`Start()`:** calls `BaseSyncClient:Start()` — wires Blink listener → CharmSync:sync

**`GetAtom()`:** returns client Charm atom; consumers read `atom()[localUserId]`

**Module ownership:** Client — instantiated in a future `EconomyController`
**Exit criteria:** After server adds 10 Energy, client atom reflects update within one CharmSync interval

---

## Verification Checklist

### Functional Tests
- [ ] Server starts cleanly; EconomyContext loads without error
- [ ] On RunStart (Idle → Prep): every player's wallet = `STARTING_WALLET`
- [ ] Client atom matches server value within CharmSync interval after initialization
- [ ] `AddResource(player, "Energy", 10)` adds Energy up to cap
- [ ] `AddResource(player, "Metal", 5)` adds zone resource up to cap
- [ ] On wave clear (→ Resolution): every player receives `WAVE_CLEAR_BONUS` Energy
- [ ] `SpendResource(player, resourceType, cost)` when balance ≥ cost: deducts and returns `Result.Ok`
- [ ] `SpendResource(player, resourceType, cost)` when balance < cost: returns `Result.Err`, balance unchanged
- [ ] `GetBalance(player, resourceType)` returns correct current balance
- [ ] Player leaving removes their atom entry (no memory leak)
- [ ] Player joining mid-run is hydrated with their current balance
- [ ] On RunEnd: all player entries removed from atom

### Edge Cases
- [ ] `SpendEnergy` with cost = 0 → `Result.Err(INVALID_AMOUNT)`
- [ ] `SpendEnergy` with cost exactly equal to balance → succeeds, balance = 0
- [ ] Two sequential spend calls: second call sees updated balance from first (Charm mutation is sequential)
- [ ] `GetEnergy` for player not yet initialized → returns nil (no crash)
- [ ] New run starts after previous RunEnd → players re-initialized to STARTING_WALLET cleanly

### Security Checks
- [ ] No Client remotes on EconomyContext — no player can add or spend Energy from client
- [ ] `SpendEnergy` and `AddKillReward` are server-only methods (not in `.Client` table)
- [ ] All income paths go through `AddResourceCommand` → `ResourceValidator` — no raw atom writes outside ResourceSyncService

### Performance Checks
- [ ] No per-frame work — EconomyContext is entirely event-driven
- [ ] CharmSync interval: 0.33s (BaseSyncService default) — acceptable for Energy UI display
- [ ] Atom mutation is O(1) per player (table.clone of flat `[userId]: number` map)

---

## Critical Files

| File | Action |
|---|---|
| `src/Network/ResourceSync.blink` | Create |
| `src/Network/Generated/ResourceSyncServer.luau` | Generate (blink CLI) |
| `src/Network/Generated/ResourceSyncClient.luau` | Generate (blink CLI) |
| `src/ReplicatedStorage/Contexts/Economy/Config/EconomyConfig.lua` | Create |
| `src/ReplicatedStorage/Contexts/Economy/Types/EconomyTypes.lua` | Create |
| `src/ReplicatedStorage/Contexts/Economy/Sync/SharedAtoms.lua` | Create |
| `src/ServerScriptService/Contexts/Economy/Errors.lua` | Create |
| `src/ServerScriptService/Contexts/Economy/EconomyDomain/Services/ResourceValidator.lua` | Create |
| `src/ServerScriptService/Contexts/Economy/Infrastructure/Persistence/ResourceSyncService.lua` | Create |
| `src/ServerScriptService/Contexts/Economy/Application/Commands/AddResourceCommand.lua` | Create |
| `src/ServerScriptService/Contexts/Economy/Application/Commands/SpendResourceCommand.lua` | Create |
| `src/ServerScriptService/Contexts/Economy/Application/Queries/GetResourceBalanceQuery.lua` | Create |
| `src/ServerScriptService/Contexts/Economy/Application/Queries/GetResourceWalletQuery.lua` | Create |
| `src/ServerScriptService/Contexts/Economy/EconomyContext.lua` | Create |
| `src/StarterPlayerScripts/Contexts/Economy/Infrastructure/ResourceSyncClient.lua` | Create |

## Reusable Utilities

| Utility | Path | Usage |
|---|---|---|
| `BaseSyncService` | `src/ReplicatedStorage/Utilities/BaseSyncService.lua` | ResourceSyncService base class |
| `BaseSyncClient` | `src/ReplicatedStorage/Utilities/BaseSyncClient.lua` | ResourceSyncClient (direct instantiation) |
| `Registry` | `src/ReplicatedStorage/Utilities/Registry.lua` | Module lifecycle in KnitInit |
| `Result` | `src/ReplicatedStorage/Utilities/Result.lua` | Command returns + event logging |
| Knit | `ReplicatedStorage.Packages.Knit` | Service registration and discovery |
| Charm | `ReplicatedStorage.Packages.Charm` | Per-player resource wallet atom |
| Charm-sync | `ReplicatedStorage.Packages["Charm-sync"]` | Server→client delta sync (via BaseSyncService) |

## Recommended First Build Step

**Step 1** (ResourceSync.blink + generate) — unblocked, establishes the network contract.
Then **Steps 2 + 3 + 4 + 5** (config + types + atoms + errors) — all unblocked, no dependencies.
Then **Step 6** (ResourceValidator) — pure domain, no dependencies.
Then **Step 7** (ResourceSyncService) — needs SharedAtoms + BaseSyncService.
Then **Steps 8 + 9 + 10** (commands + query) — need validator + sync service; can be written in parallel.
Then **Step 11** (EconomyContext) — wires everything; depends on all prior steps.
Then **Step 12** (ResourceSyncClient) — client side, needs generated Blink client.
