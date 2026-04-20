# World Creation — WorldContext

## Context

The GDD defines a sci-fi hybrid RTS wave-defense game on a **single lane**. Phase 1 (Development-Phases.md) requires a run shell with correct authority boundaries. World creation is the foundational step: without a server-authoritative lane data model, no wave runner, enemy pathing, placement rules, or run state machine can be built.

The existing `Runtime.server.lua` imports `WorkerContext`, `LotContext`, and `NPCContext` — all from a prior project. These references must be **removed** before a WorldContext is added, or the server will crash on startup.

Scope (per user answers):
- Runtime data model only (no Roblox Part construction — physical map is placed in Studio manually)
- New `WorldContext` bounded context following the project's DDD/Knit pattern
- Grid/tile data layer only (no UI, no debug renderer, no placement execution)

---

## Goal

Build a server-authoritative `WorldContext` that owns:
1. **Lane layout config** — grid dimensions, tile size, world origin
2. **Tile grid** — flat array of tile records (position, zone type, occupancy flag)
3. **Spawn point(s)** — CFrame(s) where enemies enter
4. **Goal point** — CFrame the commander defends (enemy target)
5. **Placement zones** — which tiles allow structure placement
6. **Extraction zones** — side-pocket tiles with assigned `resourceType` values for extractor/resource buildings

The context exposes a query API for other future contexts (wave runner, enemy pathing, placement validation, extraction/crafting validation) to read world state. It does not push data to clients in Phase 1.

---

## Short Action Flow

```
Server starts
  → Knit discovers WorldContext folder
  → WorldContext:KnitInit()
      → reads WorldConfig (grid dims, tile size, origin)
      → WorldGridService builds tile grid in memory
      → WorldLayoutService resolves spawn/goal CFrames
  → WorldContext:KnitStart()
      → exposes query API (GetTile, GetSpawnPoints, GetGoalPoint, GetBuildableTiles, GetExtractionTiles, GetLaneTiles)
  → Other contexts call WorldContext queries via Knit.GetService("WorldContext")
```

No remotes needed in Phase 1 (world data is server-only).

---

## Assumptions

- The physical lane exists in Studio as a **`World` folder in Workspace** (placed manually). This plan does not create or modify that folder.
- Spawn points and goal point are defined as **config values** (CFrame constants in WorldConfig) for now. They can later be replaced with reads from named Parts inside the `World` Workspace folder.
- The lane is a **rectangular grid** of uniform square tiles.
- Tiles have a **zone type**: `"lane"`, `"side_pocket"`, or `"blocked"`.
- **[GDD UPDATE 2026-04-20]** `side_pocket` tiles must carry a `resourceType` field indicating which zone resource they produce (e.g. `"Metal"`, `"Crystal"`). Add `resourceType: ResourceType?` to the `Tile` type in `WorldTypes.lua` (nil for `lane` and `blocked`). Update `WorldConfig` zone layout table to annotate each side_pocket entry with its resource type. `ResourceType` union type to be defined once resource names are finalized in the Structure roster GDD section.
- Zone layout entries are no longer plain strings. Use tile descriptors such as `{ zone = "lane" }`, `{ zone = "side_pocket", resourceType = "Metal" }`, and `{ zone = "blocked" }`.
- Phase 1 does not replicate world state to clients.
- `Jabby` registration of WorldContext's JECS world is deferred (no ECS world needed yet — tile grid is plain Luau tables).

---

## Ambiguities Resolved

| Question | Decision |
|---|---|
| Does WorldContext need an ECS world? | No — tile grid is plain tables. JECS is for entities (enemies, structures), not static layout. |
| Where do spawn/goal CFrames come from? | WorldConfig module (hardcoded CFrame constants for now; can be replaced with Workspace Part reads later). |
| Does the client need world data? | Not in Phase 1. Deferred. |
| What tile size / grid dimensions? | Defined in WorldConfig as tunable constants. |

---

## Files to Create / Modify

### Modify
- `src/ServerScriptService/Runtime.server.lua` — remove references to WorkerContext, LotContext, NPCContext, and their Jabby registrations

### Create (Server)
```
src/ServerScriptService/Contexts/World/
  WorldContext.lua                          ← Knit service (pass-through + query API)
  Errors.lua                                ← Centralized error message constants
  Application/
    Queries/
      GetTileQuery.lua                      ← Read a single tile by grid coords
      GetSpawnPointsQuery.lua               ← Return spawn CFrames
      GetGoalPointQuery.lua                 ← Return goal CFrame
      GetBuildableTilesQuery.lua            ← Return unoccupied non-blocked build tiles
      GetExtractionTilesQuery.lua           ← Return side-pocket extraction tiles
      GetLaneTilesQuery.lua                 ← Return lane tiles for pathing
  Infrastructure/
    Services/
      WorldGridService.lua                  ← Builds and owns the tile grid table
      WorldLayoutService.lua                ← Resolves spawn/goal CFrames from config
```

Debug logging uses `Result.MentionSuccess` / `Result.MentionEvent` at meaningful milestones — no `DebugLogger.lua` (that pattern is legacy).

### Create (Shared / ReplicatedStorage)
```
src/ReplicatedStorage/Contexts/World/
  Config/
    WorldConfig.lua                         ← Grid dimensions, tile size, origin CFrame, spawn/goal CFrames
  Types/
    WorldTypes.lua                          ← Tile, ZoneType, GridCoord type exports
```

---

## Implementation Plan

### Step 1 — Clean up Runtime.server.lua

**Objective:** Remove all references to non-existent contexts so the server starts cleanly.

**File:** `src/ServerScriptService/Runtime.server.lua`

**Tasks:**
- Delete the `Knit.GetService("WorkerContext")` block and its Jabby registration
- Delete the `Knit.GetService("LotContext")` block and its Jabby registration
- Delete the `Knit.GetService("NPCContext")` block and its Jabby registration
- Keep the `Jabby.set_check_function` call
- Keep `PlayerCollisionService:Initialize()` and `ServerScheduler:Initialize()`

**Data:** No data changes — purely a deletion of dead references.

**Trigger:** Immediate (prerequisite for all other steps).

**Exit criteria:** Server starts without errors in Studio Play mode. Only LogContext loads.

---

### Step 2 — WorldConfig (shared)

**Objective:** Define all world constants in one place so every module reads from a single source of truth.

**File:** `src/ReplicatedStorage/Contexts/World/Config/WorldConfig.lua`

**Tasks:**
- Define `GRID_COLS` (number of tiles along lane length, e.g. 20)
- Define `GRID_ROWS` (number of tiles across lane width, e.g. 5)
- Define `TILE_SIZE` (stud size of each tile, e.g. 8)
- Define `WORLD_ORIGIN` as a `CFrame` (top-left corner of the grid in world space)
- Define `SPAWN_POINTS` as `{ CFrame }` (array, supporting future multi-spawn)
- Define `GOAL_POINT` as a `CFrame`
- Define the zone layout as a 2D array of tile descriptor tables — `GRID_ROWS × GRID_COLS`
  - `{ zone = "lane" }`
  - `{ zone = "side_pocket", resourceType = "Metal" }`
  - `{ zone = "blocked" }`
- `side_pocket` descriptors must include `resourceType`; `lane` and `blocked` descriptors must not.
- `table.freeze` the entire config

**Data output:** A frozen table consumed by WorldGridService and WorldLayoutService.

**Module ownership:** `ReplicatedStorage` (shared — server reads it; client can read it later without a Remote).

**Exit criteria:** Module requires without error; all constants accessible.

---

### Step 3 — WorldTypes (shared)

**Objective:** Export Luau strict-mode types for tile records and coordinates.

**File:** `src/ReplicatedStorage/Contexts/World/Types/WorldTypes.lua`

**Tasks:**
- Export `type ZoneType = "lane" | "side_pocket" | "blocked"`
- Export `type ResourceType = string` — placeholder until resource names finalized in Structure roster GDD section
- Export `type GridCoord = { row: number, col: number }`
- Export `type Tile = { coord: GridCoord, worldPos: Vector3, zone: ZoneType, occupied: boolean, resourceType: ResourceType? }` — `resourceType` is non-nil only for `side_pocket` tiles
- Export `type TileGrid = { [number]: Tile }` (flat array, row-major order)

**Module ownership:** `ReplicatedStorage` (shared).

**Exit criteria:** Types importable with `--!strict` and no type errors.

---

### Step 4 — WorldGridService (server infrastructure)

**Objective:** Build and own the in-memory tile grid. Provides tile lookup and mutation (occupancy).

**File:** `src/ServerScriptService/Contexts/World/Infrastructure/Services/WorldGridService.lua`

**Tasks:**
- Constructor `WorldGridService.new()` — takes no arguments; reads `WorldConfig` internally
- `Build()` method — iterates `GRID_ROWS × GRID_COLS`, computes each tile's `worldPos` as:
  `WORLD_ORIGIN * CFrame.new(col * TILE_SIZE, 0, row * TILE_SIZE)` (adjust axis to match lane orientation)
  Reads zone type from `WorldConfig`'s zone layout table. Stores tiles in flat array (index = `(row-1)*GRID_COLS + col`).
- `GetTile(coord: GridCoord): Tile?` — returns tile or nil for out-of-bounds
- `GetTileByIndex(index: number): Tile?` — direct flat-array access
- `GetAllTiles(): { Tile }` — returns the grid array (read-only intent)
- `GetBuildableTiles(): { Tile }` — returns all tiles where `zone ~= "blocked"` and `occupied == false`
- `GetExtractionTiles(): { Tile }` — returns all tiles where `zone == "side_pocket"` and `resourceType ~= nil`
- `GetLaneTiles(): { Tile }` — returns all tiles where `zone == "lane"` for EnemyContext waypoint building
- `SetOccupied(coord: GridCoord, occupied: boolean)` — mutates tile occupancy (called by future PlacementContext)
- `Init(registry, name)` lifecycle hook (called by Registry:InitAll)

**Data:** Flat `{ Tile }` array owned by the service instance.

**Trigger:** Called during `WorldContext:KnitInit()` via Registry.

**Guards:** Assert `coord.row` and `coord.col` are within grid bounds before lookup.

**Exit criteria:** `Build()` produces exactly `GRID_ROWS * GRID_COLS` tiles with correct `worldPos` values and zone types matching the config layout.

---

### Step 5 — WorldLayoutService (server infrastructure)

**Objective:** Resolve and own spawn/goal CFrames. Thin wrapper over WorldConfig for now; can be replaced with Workspace Part reads later.

**File:** `src/ServerScriptService/Contexts/World/Infrastructure/Services/WorldLayoutService.lua`

**Tasks:**
- Constructor `WorldLayoutService.new()`
- `GetSpawnPoints(): { CFrame }` — returns `WorldConfig.SPAWN_POINTS`
- `GetGoalPoint(): CFrame` — returns `WorldConfig.GOAL_POINT`
- `Init(registry, name)` lifecycle hook

**Data:** Reads from WorldConfig (no state of its own in Phase 1).

**Trigger:** Called during `WorldContext:KnitInit()` via Registry.

**Exit criteria:** Returns correct CFrames from config without error.

---

### Step 6 — Query modules (server application layer)

**Objective:** Thin CQRS query objects that wrap infrastructure service calls. Follow project's query pattern (read-only, no domain logic).

**Files:**
- `GetTileQuery.lua` — wraps `WorldGridService:GetTile(coord)`
- `GetSpawnPointsQuery.lua` — wraps `WorldLayoutService:GetSpawnPoints()`
- `GetGoalPointQuery.lua` — wraps `WorldLayoutService:GetGoalPoint()`
- `GetBuildableTilesQuery.lua` — wraps `WorldGridService:GetBuildableTiles()`
- `GetExtractionTilesQuery.lua` — wraps `WorldGridService:GetExtractionTiles()`
- `GetLaneTilesQuery.lua` — wraps `WorldGridService:GetLaneTiles()`

**Each query pattern:**
```
Query.new(gridService, layoutService)
Query:Execute(...args) → result value or nil
```

**Module ownership:** Server application layer.

**Exit criteria:** Each query returns correct data when called with valid inputs.

---

### Step 7 — WorldContext Knit service

**Objective:** Wire everything together as a Knit service. Exposes the query API as public methods for other server contexts.

**File:** `src/ServerScriptService/Contexts/World/WorldContext.lua`

**Tasks:**
- `Knit.CreateService({ Name = "WorldContext", Client = {} })`
- `KnitInit()`:
  - Create Registry with context `"World"`
  - Register `WorldGridService.new()` under `"Infrastructure"`
  - Register `WorldLayoutService.new()` under `"Infrastructure"`
  - Call `registry:InitAll()` → triggers `Build()` on WorldGridService
  - Instantiate query objects, store as `self._queries`
- `KnitStart()`: no-op for now (no subscriptions needed in Phase 1)
- Public API methods (called by other server services via `Knit.GetService("WorldContext")`):
  - `WorldContext:GetTile(coord: GridCoord): Tile?`
  - `WorldContext:GetSpawnPoints(): { CFrame }`
  - `WorldContext:GetGoalPoint(): CFrame`
  - `WorldContext:GetBuildableTiles(): { Tile }`
  - `WorldContext:GetExtractionTiles(): { Tile }`
  - `WorldContext:GetLaneTiles(): { Tile }`
  - `WorldContext:GetPlacementZones(): { Tile }` — optional compatibility alias for `GetBuildableTiles()` only if needed by older plans
  - `WorldContext:SetTileOccupied(coord: GridCoord, occupied: boolean)` — proxies to WorldGridService
- No `Client` remotes in Phase 1

**Module ownership:** Server — auto-discovered by Knit via `Contexts:GetChildren()` loop in Runtime.server.lua.

**Exit criteria:** `Knit.GetService("WorldContext")` returns the service; all query methods return expected data in a test run.

---

### Step 8 — Errors.lua

**Objective:** Centralized error message constants for WorldContext per DDD convention.

**File:** `src/ServerScriptService/Contexts/World/Errors.lua`

**Tasks:**
- Define string constants for all expected error cases (e.g. `OUT_OF_BOUNDS`, `TILE_NOT_FOUND`)
- `table.freeze` the module
- Debug logging within WorldContext uses `Result.MentionSuccess` / `Result.MentionEvent` at milestone points — no DebugLogger module

**Exit criteria:** Errors importable; no DebugLogger file created.

---

### Step 9 — Phases.lua additions (if needed)

**Objective:** Add a `WorldTick` phase to the Planck scheduler if WorldContext needs per-frame work in a future step.

**Decision:** **Defer.** Phase 1 WorldContext is purely reactive (query-only). No ECS systems. Do not add phases until a system actually needs them.

---

## Verification Checklist

### Functional
- [ ] Server starts in Studio Play mode with no errors after Runtime cleanup (Step 1)
- [ ] WorldConfig loads and all constants are accessible
- [ ] `WorldGridService:Build()` produces `GRID_ROWS * GRID_COLS` tiles
- [ ] `GetTile({row=1, col=1})` returns a tile with correct `worldPos` and `zone`
- [ ] `GetTile({row=0, col=0})` returns `nil` (out of bounds guard)
- [ ] `GetBuildableTiles()` excludes `"blocked"` tiles and occupied tiles
- [ ] `GetExtractionTiles()` returns only `side_pocket` tiles with non-nil `resourceType`
- [ ] `GetLaneTiles()` returns only lane tiles for EnemyContext path construction
- [ ] `side_pocket` tiles carry `resourceType`; `lane` and `blocked` tiles do not
- [ ] `GetSpawnPoints()` returns the configured CFrame(s)
- [ ] `GetGoalPoint()` returns the configured CFrame
- [ ] `SetTileOccupied` toggles tile occupancy and is reflected in next `GetBuildableTiles()` call
- [ ] Another server service can call `Knit.GetService("WorldContext"):GetSpawnPoints()` and receive data

### Edge Cases
- [ ] Grid with 1 row and 1 col builds without error
- [ ] Zone layout table in WorldConfig with all `"blocked"` tiles → `GetBuildableTiles()` returns empty table
- [ ] `SetTileOccupied` on an out-of-bounds coord does not error (guard or assert)

### Security
- [ ] No Client remotes on WorldContext in Phase 1 — world data is server-only
- [ ] `SetTileOccupied` is not accessible from any remote; only internal server services call it

### Performance
- [ ] Grid build is O(GRID_ROWS × GRID_COLS) — runs once at startup, not per frame
- [ ] `GetBuildableTiles()` / `GetExtractionTiles()` iterate the grid once; acceptable for Phase 1 call frequency (not called per frame)

---

## Critical Files

| File | Action |
|---|---|
| `src/ServerScriptService/Runtime.server.lua` | Modify — remove dead context references |
| `src/ReplicatedStorage/Contexts/World/Config/WorldConfig.lua` | Create |
| `src/ReplicatedStorage/Contexts/World/Types/WorldTypes.lua` | Create |
| `src/ServerScriptService/Contexts/World/Infrastructure/Services/WorldGridService.lua` | Create |
| `src/ServerScriptService/Contexts/World/Infrastructure/Services/WorldLayoutService.lua` | Create |
| `src/ServerScriptService/Contexts/World/Application/Queries/GetTileQuery.lua` | Create |
| `src/ServerScriptService/Contexts/World/Application/Queries/GetSpawnPointsQuery.lua` | Create |
| `src/ServerScriptService/Contexts/World/Application/Queries/GetGoalPointQuery.lua` | Create |
| `src/ServerScriptService/Contexts/World/Application/Queries/GetBuildableTilesQuery.lua` | Create |
| `src/ServerScriptService/Contexts/World/Application/Queries/GetExtractionTilesQuery.lua` | Create |
| `src/ServerScriptService/Contexts/World/Application/Queries/GetLaneTilesQuery.lua` | Create |
| `src/ServerScriptService/Contexts/World/WorldContext.lua` | Create |
| `src/ServerScriptService/Contexts/World/Errors.lua` | Create |

## Reusable Utilities

| Utility | Path | Usage |
|---|---|---|
| `Registry` | `src/ReplicatedStorage/Utilities/Registry.lua` | Module lifecycle (Init/Start) inside WorldContext:KnitInit |
| `Result` | `src/ReplicatedStorage/Utilities/Result.lua` | Wrap query returns if error handling is needed |
| Knit | `ReplicatedStorage.Packages.Knit` | Service registration and discovery |

---

## Recommended First Build Step

**Step 1 (Runtime cleanup)** — makes the server bootable. Then **Step 2 + 3** (config + types) — unblocked and fast. Then **Step 4** (WorldGridService) — the core data structure. Everything else follows in order.
