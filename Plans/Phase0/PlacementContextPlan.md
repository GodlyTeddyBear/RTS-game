# PlacementContext — Structure Placement

## Context

The GDD defines a single-lane sci-fi RTS wave-defense game where the player spends Energy to place already-available structures during the Prep phase, while zone resources are used for crafting/unlocking and upgrading structure types. PlacementContext is the system that validates and executes physical placement only: it checks run state (Prep only), structure availability/unlock state, tile availability (via WorldContext), Energy sufficiency (via EconomyContext), then spawns a physical Part/Model in Workspace and marks the tile as occupied. It also replicates the placement atom (placed structure records) to all clients so UI and VFX can react.

**User decisions that shape this plan:**
- Placement initiated via **RemoteFunction** (client sends coord + structure type; server validates and responds)
- PlacementContext **spawns a Part/Model** in Workspace at the tile's worldPos
- **Replicates** placed structure data to all clients via Charm atom + Blink (global, not per-player)
- **Prep-only gating** — placement rejected if RunState ≠ "Prep"

**Dependencies (all planned, none yet implemented):**
- WorldContext → `GetTile(coord)`, `SetTileOccupied(coord, bool)`
- EconomyContext → `SpendEnergy(player, cost)` for placement/repair, generic `SpendResource` for future crafting/upgrade callers
- RunContext → `GetState()` → RunState; `StateChanged` Signal
- Structure/Crafting plan (new scope) → owns unlocks, recipes, upgrade tier rules, and calls PlacementContext only after a structure type is available

---

## Goal

Build a server-authoritative `PlacementContext` Knit service that:
1. Receives placement requests from clients via Blink RemoteFunction
2. Validates: run state == "Prep", structure type is unlocked/available, tile is compatible and available, player has sufficient Energy
3. Deducts Energy via EconomyContext
4. Spawns a structure Model in Workspace at the tile's worldPos
5. Marks the tile occupied via WorldContext
6. Replicates a `PlacementAtom` (list of StructureRecords including tier and optional resource/extractor metadata) to all clients via Charm + Blink
7. Clears all structures and atom on RunEnd
8. Exposes a server-side query API for other contexts

---

## Reconciliation Corrections (Phase 0)

This plan is reconciled against `.claude/commands/reconcile-context.md` and backend DDD/CQRS rules.

- `PlacementContext.lua` stays a pass-through boundary for public methods; orchestration lives in Application commands/queries.
- Sync service must be moved to `Infrastructure/Persistence/PlacementSyncService.lua`.
- Business rule evaluation should be represented as Domain Specs + a Placement policy consumed by the command.
- Queries stay read-only and call Infrastructure only.
- Error strings come from `Errors.lua` constants only.

Reconciliation matrix:
- [x] `Application/Commands` present
- [x] `Application/Queries` present
- [x] `PlacementDomain/` present
- [x] `Infrastructure/Persistence` present for atom sync
- [x] `Infrastructure/Services` present for model spawn/destroy work
- [x] `PlacementContext.lua` pass-through + wrapped context boundary
- [x] `Errors.lua` centralized

---

## Short Action Flow

```
Client: player selects tile coord + structure type
  → Blink PlaceStructure.InvokeServer(coord_row, coord_col, structureType)
    → Server: PlacementContext:_HandlePlaceRequest(player, data)
        → anti-exploit: validate coord and structureType are in-bounds strings
        → PlaceStructureCommand:Execute(player, coord, structureType)
            → ValidateRunState: RunContext:GetState() == "Prep"   [Domain]
            → ValidateStructureAvailable: structure type exists and is unlocked
            → ValidateTile: WorldContext:GetTile(coord) → compatible + available?
            → ValidateCapacity: #placements < MAX_STRUCTURES       [Domain]
            → EconomyContext:SpendEnergy(player, cost) → Result
                → if Err → return Err to client (no mutation)
            → PlacementService:SpawnStructure(structureType, tile.worldPos)
                → if Err (template missing) → refund energy, return Err
            → WorldContext:SetTileOccupied(coord, true)
            → PlacementSyncService:AddPlacement(record)
                → Atom updated → CharmSync delta → Blink → client atoms updated
        → return { success, errorMessage? } to client
```

---

## Assumptions

- Structure templates live in `ReplicatedStorage.Assets.Structures.[TemplateName]` as Model instances (placed in Studio manually — this plan does not create them).
- `structureType` is a string key (e.g. `"turret"`, `"wall"`, `"extractor"`). PlacementConfig maps each to an Energy placement cost, template name, valid zone types, and whether the structure requires an extraction tile.
- PlacementContext does not own crafting recipes or upgrade costs. The new structure/crafting scope owns unlock state and tier upgrades; PlacementContext consumes availability checks only.
- One structure per tile (occupancy is boolean).
- PlacementAtom is global — all players see the same placed structures.
- Structures survive into the Wave phase; they are only cleared on RunEnd.
- WorldContext is responsible for resetting its own occupancy flags on RunEnd.
- `PlacementService` parents all spawned Models to `Workspace.Placements` folder (created at startup if absent).
- Energy refund on template-missing error goes through `EconomyContext:AddResource(player, "Energy", cost)` or a dedicated refund helper.
- Extractor/resource buildings are only valid on `side_pocket` tiles with a non-nil `resourceType`; their `StructureRecord` stores that `resourceType`.

---

## Ambiguities Resolved

| Question | Decision |
|---|---|
| Multiple structures per tile? | No — one per tile; occupancy is boolean. |
| Remove/repair structures? | Repair is an Energy sink in GDD; physical repair execution remains deferred unless StructureContext needs it. |
| Client needs full tile grid? | No — atom contains only placed StructureRecords (coord + type + instanceId). |
| Missing template? | Err returned; energy refunded; no spawn. |
| Structures persist across waves? | Yes — cleared only on RunEnd. |
| Who clears WorldContext occupancy on RunEnd? | WorldContext's own RunEnd handler (not PlacementContext's concern). |
| Who owns crafting/unlocks/upgrades? | New Structure/Crafting scope; PlacementContext only places available structures. |

---

## Files to Create

### Network
```
src/Network/
  PlacementSync.blink               ← Server → Client replication event
  PlacementRemote.blink             ← Client → Server placement request/response
  Generated/
    PlacementSyncServer.luau        ← generated
    PlacementSyncClient.luau        ← generated
    PlacementRemoteServer.luau      ← generated
    PlacementRemoteClient.luau      ← generated
```

### Shared (ReplicatedStorage)
```
src/ReplicatedStorage/Contexts/Placement/
  Config/
    PlacementConfig.lua             ← STRUCTURE_PLACEMENT_COSTS, STRUCTURE_TEMPLATES, VALID_ZONE_TYPES, MAX_STRUCTURES
  Types/
    PlacementTypes.lua              ← StructureRecord, PlacementAtom types
  Sync/
    SharedAtoms.lua                 ← CreateServerAtom / CreateClientAtom
```

### Server
```
src/ServerScriptService/Contexts/Placement/
  PlacementContext.lua              ← Knit service
  Errors.lua                        ← Error constants
  Application/
    Commands/
      PlaceStructureCommand.lua     ← Full DDD stack: validate → spend → spawn → occupy → emit
    Queries/
      GetPlacedStructuresQuery.lua  ← Returns active StructureRecords
  PlacementDomain/
    Specs/
      PlacementSpecs.lua            <- Tile/rule predicates
    Policies/
      PlaceStructurePolicy.lua      <- Fetch state + evaluate specs
    Services/
      PlacementValidator.lua        <- Input validation helpers
  Infrastructure/
    Persistence/
      PlacementSyncService.lua      <- Owns PlacementAtom; Charm + CharmSync + Blink
    Services/
      PlacementService.lua          <- Spawns/destroys Model instances in Workspace
```

### Client
```
src/StarterPlayerScripts/Contexts/Placement/
  Infrastructure/
    PlacementSyncClient.lua         ← BaseSyncClient wrapper for PlacementAtom
```

---

## Implementation Plan

### Step 1 — PlacementSync.blink + PlacementRemote.blink + generate

**Objective:** Define both Blink network contracts and generate server/client modules.

**Files:** `src/Network/PlacementSync.blink`, `src/Network/PlacementRemote.blink`

**PlacementSync.blink tasks:**
- `option RemoteScope = "PLACEMENT_SYNC"`
- `event SyncPlacements { from: Server, type: Reliable, call: SingleAsync, data: buffer }` (CharmSync delta payload)

**PlacementRemote.blink tasks:**
- `option RemoteScope = "PLACEMENT_REMOTE"`
- `struct PlaceRequest { coord_row: u8, coord_col: u8, structureType: string }`
- `struct PlaceResponse { success: boolean, errorMessage: string? }`
- `function PlaceStructure { from: Client, type: Reliable, call: SingleAsync, data: PlaceRequest } -> PlaceResponse`

Run `blink` CLI → generate all four files into `src/Network/Generated/`.

**Dependencies:** None
**Exit criteria:** All four generated files exist with correct event/function signatures

---

### Step 2 — PlacementConfig (shared)

**Objective:** All placement constants in one frozen module.

**File:** `src/ReplicatedStorage/Contexts/Placement/Config/PlacementConfig.lua`

**Tasks:**
- `STRUCTURE_PLACEMENT_COSTS: { [string]: number }` — Energy-only cost to place an available structure, e.g. `{ turret = 15, wall = 5, extractor = 10 }`
- `STRUCTURE_TEMPLATES: { [string]: string }` — maps structureType to template name in `ReplicatedStorage.Assets.Structures`, e.g. `{ turret = "Turret", wall = "Wall" }`
- `VALID_ZONE_TYPES: { [string]: { string } }` — maps structureType to valid world tile zones
- `REQUIRES_RESOURCE_TILE: { [string]: boolean }` — `extractor = true`; validates `tile.zone == "side_pocket"` and `tile.resourceType ~= nil`
- `MAX_STRUCTURES: number = 20` — hard cap on total placed structures per run
- `PLACEMENT_FOLDER_NAME: string = "Placements"` — Workspace folder name
- `table.freeze` the module and all inner tables

**Module ownership:** ReplicatedStorage (shared — client readable without a Remote)
**Exit criteria:** All constants accessible; module requires without error

---

### Step 3 — PlacementTypes (shared)

**Objective:** Strict Luau types for placement records and atom shape.

**File:** `src/ReplicatedStorage/Contexts/Placement/Types/PlacementTypes.lua`

**Tasks:**
- `export type GridCoord = { row: number, col: number }`
- `export type StructureRecord = { coord: GridCoord, structureType: string, instanceId: number, tier: number, resourceType: string? }`
- `export type PlacementAtom = { placements: { StructureRecord } }`

**Module ownership:** ReplicatedStorage
**Exit criteria:** Types importable under `--!strict` with no errors

---

### Step 4 — SharedAtoms (shared)

**Objective:** Charm atom factories for server and client.

**File:** `src/ReplicatedStorage/Contexts/Placement/Sync/SharedAtoms.lua`

**Tasks:**
- `CreateServerAtom()` → `Charm.atom({ placements = {} } :: PlacementAtom)`
- `CreateClientAtom()` → `Charm.atom({ placements = {} } :: PlacementAtom)`

**Module ownership:** ReplicatedStorage
**Exit criteria:** Both factory functions callable; atoms hold correct initial shape

---

### Step 5 — Errors.lua

**Objective:** Centralized error constants for PlacementContext.

**File:** `src/ServerScriptService/Contexts/Placement/Errors.lua`

**Tasks:**
- `NOT_PREP_STATE = "PlacementContext: placement only allowed during Prep phase"`
- `TILE_UNAVAILABLE = "PlacementContext: tile is blocked or already occupied"`
- `UNKNOWN_STRUCTURE_TYPE = "PlacementContext: structure type not in config"`
- `TEMPLATE_NOT_FOUND = "PlacementContext: structure template missing from ReplicatedStorage"`
- `MAX_STRUCTURES_REACHED = "PlacementContext: structure cap reached for this run"`
- `INVALID_COORD = "PlacementContext: grid coord out of bounds"`
- `table.freeze`

**Exit criteria:** All constants importable; no duplicate keys

---

### Step 6 — PlacementValidator (domain service)

**Objective:** Pure, stateless domain validator. No I/O. Returns `Result` for each rule.

**File:** `src/ServerScriptService/Contexts/Placement/PlacementDomain/Services/PlacementValidator.lua`

**Constructor:** `PlacementValidator.new()` — no arguments

**Methods:**

`ValidateRunState(state: RunState): Result`
- Guard: `state == "Prep"`
- Returns `Result.Ok(nil)` or `Result.Err(Errors.NOT_PREP_STATE)`

`ValidateStructureAvailable(structureType: string, isUnlocked: boolean): Result`
- Guard: `PlacementConfig.STRUCTURE_PLACEMENT_COSTS[structureType] ~= nil`
- Guard: `isUnlocked == true` once Structure/Crafting scope provides unlock state; in Phase 1 placeholder structures may default unlocked
- Returns `Result.Ok(nil)` or `Result.Err(Errors.UNKNOWN_STRUCTURE_TYPE)`

`ValidateTile(tile: Tile?, structureType: string): Result`
- Guard: tile not nil; `tile.zone ~= "blocked"`; `tile.occupied == false`
- Guard: `tile.zone` is in `PlacementConfig.VALID_ZONE_TYPES[structureType]`
- Guard: if `REQUIRES_RESOURCE_TILE[structureType]`, `tile.zone == "side_pocket"` and `tile.resourceType ~= nil`
- Returns `Result.Ok(tile)` or `Result.Err(Errors.INVALID_COORD)` / `Result.Err(Errors.TILE_UNAVAILABLE)`

`ValidateCapacity(currentCount: number): Result`
- Guard: `currentCount < PlacementConfig.MAX_STRUCTURES`
- Returns `Result.Ok(nil)` or `Result.Err(Errors.MAX_STRUCTURES_REACHED)`

**No side effects.** All inputs are plain values.
**Exit criteria:** Each method returns correct Result for valid and invalid inputs; no mutation

---

### Step 6b — PlacementSpecs + PlaceStructurePolicy (domain layer)

**Objective:** Separate business rule evaluation from command orchestration.

**Files:**
- `src/ServerScriptService/Contexts/Placement/PlacementDomain/Specs/PlacementSpecs.lua`
- `src/ServerScriptService/Contexts/Placement/PlacementDomain/Policies/PlaceStructurePolicy.lua`

**Tasks:**
- `PlacementSpecs` exports composable predicates for prep-state, structure availability, tile compatibility, and capacity checks.
- `PlaceStructurePolicy:Check(...)` fetches required state and returns a `Result` containing resolved command context (`tile`, `cost`, `resourceType`) for `PlaceStructureCommand`.

**Exit criteria:** `PlaceStructureCommand` calls policy first and does not duplicate rule resolution logic.

---

### Step 7 — PlacementService (server infrastructure)

**Objective:** Spawns and destroys structure Model instances in Workspace. Owns the Placements folder and instanceId counter.

**File:** `src/ServerScriptService/Contexts/Placement/Infrastructure/Services/PlacementService.lua`

**Constructor:** `PlacementService.new()`

**`Init(registry, name)`:**
- Find or create `Workspace:FindFirstChild(PLACEMENT_FOLDER_NAME)` → store as `self._folder`
- `self._instanceMap: { [number]: Model } = {}`
- `self._nextId: number = 1`

**Methods:**

`SpawnStructure(structureType: string, worldPos: Vector3): Result<number>`
1. Resolve template: `ReplicatedStorage.Assets.Structures[PlacementConfig.STRUCTURE_TEMPLATES[structureType]]`
2. If nil → `return Result.Err(Errors.TEMPLATE_NOT_FOUND)`
3. `instance = template:Clone()`
4. `instance:SetPrimaryPartCFrame(CFrame.new(worldPos))`
5. `instance.Parent = self._folder`
6. `instanceId = self._nextId; self._nextId += 1`
7. `self._instanceMap[instanceId] = instance`
8. Return `Result.Ok(instanceId)`

`DestroyStructure(instanceId: number)`
- Look up `self._instanceMap[instanceId]`; if present, call `:Destroy()` and remove key

`DestroyAll()`
- Iterate map, destroy each instance, clear map, reset `self._nextId = 1`

**Trigger:** Called by `PlaceStructureCommand` (spawn) and `PlacementContext` RunEnd handler (destroy all)
**Exit criteria:** Spawned Model appears at correct worldPos in `Workspace.Placements`; DestroyAll removes all instances cleanly

---

### Step 8 — PlacementSyncService (server infrastructure)

**Objective:** Owns the global PlacementAtom. Handles CharmSync + Blink replication and player hydration.

**File:** `src/ServerScriptService/Contexts/Placement/Infrastructure/Persistence/PlacementSyncService.lua`

**Note:** Direct implementation (not BaseSyncService subclass — atom is global, not per-player).

**Constructor:** `PlacementSyncService.new()`

**`Init(registry, name)`:**
- `self.BlinkServer = registry:Get("BlinkServer")` (generated PlacementSyncServer)
- `self.Atom = SharedAtoms.CreateServerAtom()`
- `self.Syncer = CharmSync.server({ atoms = { placements = self.Atom }, interval = 0.1 })`
- `self.Cleanup = self.Syncer:connect(function(player, payload) self.BlinkServer.SyncPlacements.Fire(player, payload) end)`

**Methods:**

`HydratePlayer(player: Player)` → `self.Syncer:hydrate(player)`

`AddPlacement(record: StructureRecord)`
- Atom mutation: `self.Atom(function(current) local next = table.clone(current); next.placements = table.clone(next.placements); table.insert(next.placements, record); return next end)`

`ClearAll()`
- Atom mutation: `self.Atom(function() return { placements = {} } end)`

`Destroy()` → `self.Cleanup()`

**Exit criteria:** After `AddPlacement`, next CharmSync interval pushes delta to all clients; `ClearAll` resets client atoms to `{}`

---

### Step 9 — PlaceStructureCommand (application layer)

**Objective:** Full DDD write command. Orchestrates validation → spend → spawn → occupy → replicate.

**File:** `src/ServerScriptService/Contexts/Placement/Application/Commands/PlaceStructureCommand.lua`

**Constructor:** `PlaceStructureCommand.new(validator, placementService, syncService, runContext, worldContext, economyContext)`

**`Execute(player: Player, coord: GridCoord, structureType: string): Result`**

Steps (abort at first Err; no partial mutation):
1. `state = runContext:GetState()` → `validator:ValidateRunState(state)` → Err if not Prep
2. `validator:ValidateStructureType(structureType)` → Err if unknown
3. `tile = worldContext:GetTile(coord)` → `validator:ValidateTile(tile)` → Err if unavailable
4. `currentCount = #syncService.Atom().placements` → `validator:ValidateCapacity(currentCount)` → Err if at cap
5. `cost = PlacementConfig.STRUCTURE_PLACEMENT_COSTS[structureType]`
6. `economyContext:SpendEnergy(player, cost)` → if Err, return Err (no spawn)
7. `spawnResult = placementService:SpawnStructure(structureType, tile.worldPos)`
   - If Err (template missing): call `economyContext` earn path to refund `cost`; return Err
8. `instanceId = spawnResult:Unwrap()`
9. `worldContext:SetTileOccupied(coord, true)`
10. `syncService:AddPlacement({ coord = coord, structureType = structureType, instanceId = instanceId, tier = 1, resourceType = tile.resourceType })`
11. `Result.MentionSuccess("PlacementContext:PlaceStructureCommand", "Structure placed", { structureType, coord, userId = player.UserId })`
12. Return `Result.Ok(instanceId)`

**Guards:** All validation before any mutation (steps 1–5). Energy deducted before spawn (step 6). Template failure refunds energy to preserve consistency.
**Exit criteria:** Success → Model in Workspace + occupied tile + updated atom + deducted energy; any Err → all state unchanged (or refunded)

---

### Step 10 — GetPlacedStructuresQuery (application layer)

**Objective:** Read-only query returning the current list of placed structure records.

**File:** `src/ServerScriptService/Contexts/Placement/Application/Queries/GetPlacedStructuresQuery.lua`

**Constructor:** `GetPlacedStructuresQuery.new(syncService: PlacementSyncService)`

**`Execute(): { StructureRecord }`**
- Returns `table.clone(syncService.Atom().placements)`

**Module ownership:** Server application layer
**Exit criteria:** Returns correct list after placements; returns `{}` initially

---

### Step 11 — PlacementContext Knit service

**Objective:** Wire all infrastructure. Handle the Blink RemoteFunction. Subscribe to RunEnd for cleanup.

**File:** `src/ServerScriptService/Contexts/Placement/PlacementContext.lua`

**`KnitInit()`:**
- `Registry.new("Placement")`
- `registry:Register("BlinkSyncServer", BlinkPlacementSyncServer)`
- `registry:Register("PlacementService", PlacementService.new(), "Infrastructure")`
- `registry:Register("PlacementSyncService", PlacementSyncService.new(), "Infrastructure")`
- `registry:InitAll()`
- Store refs: `self._placer`, `self._sync`
- Resolve cross-context deps: `self._runCtx = Knit.GetService("RunContext")`, `self._worldCtx = Knit.GetService("WorldContext")`, `self._economyCtx = Knit.GetService("EconomyContext")`
- Instantiate: `self._validator = PlacementValidator.new()`
- Instantiate: `self._placeCmd = PlaceStructureCommand.new(self._validator, self._placer, self._sync, self._runCtx, self._worldCtx, self._economyCtx)`
- Instantiate: `self._getPlacedQuery = GetPlacedStructuresQuery.new(self._sync)`

Wire RemoteFunction (in KnitInit, before KnitStart):
```
BlinkPlacementRemoteServer.PlaceStructure.SetCallback(function(player, data)
    -- anti-exploit guards
    if type(data.coord_row) ~= "number" or type(data.coord_col) ~= "number" then
        return { success = false, errorMessage = Errors.INVALID_COORD }
    end
    if type(data.structureType) ~= "string" then
        return { success = false, errorMessage = Errors.UNKNOWN_STRUCTURE_TYPE }
    end
    local coord = { row = data.coord_row, col = data.coord_col }
    local result = self._placeCmd:Execute(player, coord, data.structureType)
    return { success = result:IsOk(), errorMessage = result:IsErr() and result:UnwrapErr() or nil }
end)
```

**`KnitStart()`:**
- `Players.PlayerAdded:Connect(player → self._sync:HydratePlayer(player))`
- Hydrate all existing players
- Subscribe to `self._runCtx.StateChanged`:
  ```
  if newState == "RunEnd" then
      self._placer:DestroyAll()
      self._sync:ClearAll()
  end
  ```

**Public server API:**
- `PlacementContext:GetPlacedStructures(): { StructureRecord }` → `GetPlacedStructuresQuery:Execute()`

**No Knit `.Client` table** — RemoteFunction is Blink-wired directly
**Exit criteria:** Client invokes remote during Prep → available structure spawns on compatible tile, atom replicates with tier/resource metadata, Energy deducted; invalid requests return error string with no state change

---

### Step 12 — PlacementSyncClient (client infrastructure)

**Objective:** Client-side Charm atom that mirrors server PlacementAtom.

**File:** `src/StarterPlayerScripts/Contexts/Placement/Infrastructure/PlacementSyncClient.lua`

**Pattern:** Direct `BaseSyncClient.new()` — no subclass needed (global atom).

**Constructor:** `PlacementSyncClient.new(blinkClient)`
- `BaseSyncClient.new(blinkClient, "SyncPlacements", "placements", SharedAtoms.CreateClientAtom)`

**`Start()`:** calls `BaseSyncClient:Start()`
**`GetAtom()`:** returns client Charm atom (consumers read `.placements` array)

**Module ownership:** Client — instantiated in a future PlacementController
**Exit criteria:** After server places a structure, client atom reflects new StructureRecord within one CharmSync interval (≤0.1s)

---

## Verification Checklist

### Functional Tests
- [ ] Server starts cleanly; PlacementContext loads without error
- [ ] During Prep: valid tile + sufficient energy → Model appears in `Workspace.Placements` at correct worldPos
- [ ] Extractor placement on `side_pocket` tile records that tile's `resourceType`
- [ ] Extractor placement on `lane` or `blocked` tile returns tile unavailable / invalid zone error
- [ ] `WorldContext:GetTile(coord).occupied == true` after placement
- [ ] `EconomyContext:GetEnergy(player)` decreases by Energy placement cost after placement
- [ ] Client atom updates within 0.1s: `atom().placements` contains new StructureRecord
- [ ] Second placement on same tile → `Err(TILE_UNAVAILABLE)`, no spawn, no energy deduct
- [ ] Placement during Wave state → `Err(NOT_PREP_STATE)`, no mutation
- [ ] Placement with insufficient energy → Err from EconomyContext, no spawn
- [ ] Unknown structureType → `Err(UNKNOWN_STRUCTURE_TYPE)`
- [ ] Placement at `MAX_STRUCTURES` cap → `Err(MAX_STRUCTURES_REACHED)`
- [ ] On RunEnd: all Models destroyed, `Workspace.Placements` empty, client atom reset to `{ placements = {} }`
- [ ] `GetPlacedStructures()` returns correct list after multiple placements

### Edge Cases
- [ ] Missing template: energy refunded, no spawn, Err returned to client
- [ ] Out-of-bounds coord (row < 1 or col < 1): anti-exploit guard fires before WorldContext query
- [ ] Player disconnects mid-Prep: in-progress remote invocation completes normally (no player-alive check needed for placement)
- [ ] New run after RunEnd: first placement of new run succeeds; `GetPlacedStructures()` returns `{}`

### Security Checks
- [ ] `coord_row`, `coord_col` type-checked server-side as numbers before coord construction
- [ ] `structureType` type-checked as string before command execution
- [ ] No raw atom writes from client path — only `PlacementSyncService:AddPlacement` mutates the atom
- [ ] Energy deduction is server-authoritative — client cannot skip the spend step
- [ ] No Knit `Client` table on PlacementContext — no unintended remote exposure

### Performance Checks
- [ ] `GetTile(coord)` is O(1) flat-array lookup in WorldContext
- [ ] `AddPlacement` clones the placements array once — O(n) where n ≤ MAX_STRUCTURES (acceptable)
- [ ] CharmSync interval 0.1s — fast enough for placement feel; at most one delta push per 100ms per player
- [ ] `DestroyAll` runs once on RunEnd — not per-frame

---

## Critical Files

| File | Action |
|---|---|
| `src/Network/PlacementSync.blink` | Create |
| `src/Network/PlacementRemote.blink` | Create |
| `src/Network/Generated/PlacementSyncServer.luau` | Generate (blink CLI) |
| `src/Network/Generated/PlacementSyncClient.luau` | Generate (blink CLI) |
| `src/Network/Generated/PlacementRemoteServer.luau` | Generate (blink CLI) |
| `src/Network/Generated/PlacementRemoteClient.luau` | Generate (blink CLI) |
| `src/ReplicatedStorage/Contexts/Placement/Config/PlacementConfig.lua` | Create |
| `src/ReplicatedStorage/Contexts/Placement/Types/PlacementTypes.lua` | Create |
| `src/ReplicatedStorage/Contexts/Placement/Sync/SharedAtoms.lua` | Create |
| `src/ServerScriptService/Contexts/Placement/Errors.lua` | Create |
| `src/ServerScriptService/Contexts/Placement/PlacementDomain/Specs/PlacementSpecs.lua` | Create |
| `src/ServerScriptService/Contexts/Placement/PlacementDomain/Policies/PlaceStructurePolicy.lua` | Create |
| `src/ServerScriptService/Contexts/Placement/PlacementDomain/Services/PlacementValidator.lua` | Create |
| `src/ServerScriptService/Contexts/Placement/Infrastructure/Services/PlacementService.lua` | Create |
| `src/ServerScriptService/Contexts/Placement/Infrastructure/Persistence/PlacementSyncService.lua` | Create |
| `src/ServerScriptService/Contexts/Placement/Application/Commands/PlaceStructureCommand.lua` | Create |
| `src/ServerScriptService/Contexts/Placement/Application/Queries/GetPlacedStructuresQuery.lua` | Create |
| `src/ServerScriptService/Contexts/Placement/PlacementContext.lua` | Create |
| `src/StarterPlayerScripts/Contexts/Placement/Infrastructure/PlacementSyncClient.lua` | Create |

## Reusable Utilities

| Utility | Path | Usage |
|---|---|---|
| `Registry` | `src/ReplicatedStorage/Utilities/Registry.lua` | Module lifecycle in KnitInit |
| `Result` | `src/ReplicatedStorage/Utilities/Result.lua` | Command returns + event logging |
| `BaseSyncClient` | `src/ReplicatedStorage/Utilities/BaseSyncClient.lua` | PlacementSyncClient |
| Knit | `ReplicatedStorage.Packages.Knit` | Service registration + cross-context calls |
| Charm | `ReplicatedStorage.Packages.Charm` | Global placement atom |
| Charm-sync | `ReplicatedStorage.Packages["Charm-sync"]` | Server→client delta sync |

---

## Applied Reconcile Delta (Authoritative)

When this section conflicts with earlier step text, this section wins.

- `PlacementSyncService` location is authoritative:
  - `src/ServerScriptService/Contexts/Placement/Infrastructure/Persistence/PlacementSyncService.lua`
- Domain completeness is required for placement behavior:
  - `PlacementDomain/Specs/PlacementSpecs.lua`
  - `PlacementDomain/Policies/PlaceStructurePolicy.lua`
- `PlaceStructureCommand` executes policy check first, then spend/spawn/mutate on success.
- `PlacementContext.lua` remains pass-through for public API and ends with `WrapContext(PlacementContext, "PlacementContext")`.

---

## Recommended First Build Step

**Step 1** (blink files + generate) — unblocked; establishes both network contracts.
Then **Steps 2 + 3 + 4 + 5** (config + types + atoms + errors) — all unblocked, no dependencies between them.
Then **Step 6** (PlacementValidator) — pure domain, no dependencies.
Then **Step 6b** (PlacementSpecs + PlaceStructurePolicy) — depends on config/types; no infrastructure mutation.
Then **Steps 7 + 8** (PlacementService + PlacementSyncService) — parallel, no dependency on each other.
Then **Steps 9 + 10** (command + query) — depend on validator + services.
Then **Step 11** (PlacementContext) — wires everything; depends on all prior steps.
Then **Step 12** (PlacementSyncClient) — client side, needs generated Blink client module.

