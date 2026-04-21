# Placement Cursor & Tile Targeting — Implementation Plan

## Context

When a player selects a structure card in the Placement Palette during Prep phase, the client must enter a "placement mode": valid tiles are highlighted on the map, the cursor snaps to the nearest valid tile, a ghost preview model sits on the hovered tile, and clicking fires the existing `PlaceStructure` Blink remote. Pressing Escape (or re-clicking the card) cancels. The server already validates everything; the client cursor is purely for UX clarity.

---

## Assumptions

- `WorldConfig.lua` is in `ReplicatedStorage` and is accessible on the client — it contains `GRID_ROWS`, `GRID_COLS`, `TILE_SIZE`, `WORLD_ORIGIN`, and the zone-layout logic
- `PlacementConfig.VALID_ZONE_TYPES` is in `ReplicatedStorage` and accessible on the client
- The `PlacementAtom` (synced via `PlacementController`) contains `placements: { StructureRecord }` where each record has `coord.row` and `coord.col` — sufficient to derive occupied tiles client-side
- Structure template assets exist in `ReplicatedStorage/Assets/Structures/{TemplateName}` and can be cloned on the client for ghost preview
- `OmrezKeyBind` (used by `PlayerInputController`) supports adding new action contexts at runtime; Escape will cancel placement
- Placement mode is only reachable during Prep phase — the Placement Palette is already hidden during Wave phase, so no extra gate is needed in the cursor system itself
- The `PlaceStructure` Blink remote is a **RemoteFunction** (Invoke/returns response) — confirmed by the `PlaceResponse` shape with `success`, `errorMessage`, `instanceId`

## Ambiguities

- **Ghost model fidelity**: Use the actual structure template model as ghost (with transparency) or a simple coloured box placeholder? **Default: clone the real template, set all parts to 50% transparency + a colour tint.**
- **Tile highlight method**: Highlight via a `SelectionBox` on each valid tile Part, or render coloured flat Parts at each tile position? **Default: create flat highlight Parts (thin box, 8×0.1×8 studs) at tile world positions — simpler than requiring SelectionBox targets.**
- **WorldConfig client access**: Confirmed in `ReplicatedStorage` — no ambiguity.
- **Cursor snapping**: Snap to nearest tile centre using a `Workspace:Raycast` from the camera ray through a flat `RaycastParams` that hits the ground plane (Y=0), then convert the world hit to grid coordinates.

---

## Action Flow

```
Player selects structure card in PlacementPalette
  → PlacementCursorController:EnterPlacementMode(structureType)
      → Compute valid tile set from WorldConfig + PlacementAtom
      → Spawn highlight Parts for all valid tiles (green tint)
      → Spawn ghost model (clone template, transparent)
      → Connect RenderStepped: raycast camera ray → hit ground plane
          → WorldToGrid(hitPos) → snap ghost + highlight hovered tile
      → Connect InputBegan (MouseButton1 / tap):
          → If hovered tile is valid:
              → Fire PlaceStructure.Invoke({ coord_row, coord_col, structureType })
                  → Server: PlacementValidator → PlaceStructurePolicy → PlaceStructureCommand
                      → SpendEnergy → SpawnStructure → SetOccupied → Sync atom
                  → Client receives PlaceResponse
                      → success=true  → ExitPlacementMode, atom update triggers UI refresh
                      → success=false → show error toast, stay in placement mode
      → Connect InputBegan (Escape / RightMouse):
          → ExitPlacementMode (destroy ghost + highlights, disconnect events)
```

---

## File / Module Layout

```
src/StarterPlayerScripts/Contexts/Placement/
  PlacementCursorController.lua          [NEW] — Knit controller owning placement mode state + lifecycle
  Application/
    PlacementCursorService.lua           [NEW] — pure logic: valid tile computation, coord↔world math, ghost management
  Infrastructure/
    PlacementHighlightPool.lua           [NEW] — creates/recycles highlight Part instances in Workspace
    PlacementGhostModel.lua              [NEW] — clones, tints, and positions the ghost model
  Config/
    (none new — reuses PlacementConfig from ReplicatedStorage)

src/StarterPlayerScripts/Contexts/PlayerInput/Config/
  InputActions.lua                       [MODIFY] — add "Placement" context with CancelPlacement action (Escape)

src/StarterPlayerScripts/Contexts/Run/Presentation/Organisms/
  PlacementPalette.lua                   [MODIFY] — wire onStructureSelected → PlacementCursorController:EnterPlacementMode

src/ReplicatedStorage/Contexts/World/Config/
  WorldConfig.lua                        [READ-ONLY] — GRID_ROWS, GRID_COLS, TILE_SIZE, WORLD_ORIGIN, zone layout

src/ReplicatedStorage/Contexts/Placement/Config/
  PlacementConfig.lua                    [READ-ONLY] — VALID_ZONE_TYPES, costs, templates
```

**No server files are modified.** All new code is client-only.

---

## Implementation Steps

### Step 1 — `PlacementCursorService` (pure logic module)

**File:** `src/StarterPlayerScripts/Contexts/Placement/Application/PlacementCursorService.lua`

**Objective:** Centralise all coordinate math and valid-tile computation so no other module needs to know about WorldConfig directly.

**Tasks:**
- Export `CoordToWorld(row, col) → Vector3`: apply `WORLD_ORIGIN + Vector3.new((col-1)*TILE_SIZE, 0, (row-1)*TILE_SIZE)`
- Export `WorldToCoord(worldPos) → { row, col }?`: invert the formula; clamp to `[1, GRID_ROWS]` × `[1, GRID_COLS]`; return nil if out of bounds
- Export `GetZone(row, col) → "lane"|"side_pocket"|"blocked"`: replicate the WorldConfig zone-layout logic (row 3 = lane; specific col offsets = side_pocket; else blocked). This mirrors what the server computes — no new data needed.
- Export `GetValidTiles(structureType, occupiedSet) → { {row, col} }[]`:
  - `occupiedSet` is a `{ [string]: true }` keyed by `"row_col"` strings derived from the PlacementAtom
  - For each cell in the grid, check `GetZone(r,c) ∈ VALID_ZONE_TYPES[structureType]` AND `occupiedSet["r_c"] == nil`
  - Returns array of valid `{row, col}` pairs

**Data read:** `WorldConfig` (static), `PlacementConfig.VALID_ZONE_TYPES` (static)
**Inputs/outputs:** Pure functions, no side effects
**Module owner:** Client only
**Dependencies:** None (pure module, no Knit)
**Risks:** Zone layout logic must exactly mirror `WorldGridService` on the server — a mismatch causes client to show wrong tiles as valid. Mitigated: server re-validates on every PlaceStructure call anyway, so a mismatch is a UX issue only, not a security issue.
**Completion check:** Unit-testable — `GetValidTiles("turret", {})` returns exactly the 5 side_pocket tiles at cols 4,8,12,16,20 on rows 2 and 4.

---

### Step 2 — `PlacementHighlightPool`

**File:** `src/StarterPlayerScripts/Contexts/Placement/Infrastructure/PlacementHighlightPool.lua`

**Objective:** Manage a pool of flat Part instances used to highlight valid and hovered tiles.

**Tasks:**
- `PlacementHighlightPool.new(folder: Folder)` — stores a parent folder in Workspace for cleanup
- `:ShowValidTiles(coords: { {row,col} })`:
  - For each coord, create (or reuse from pool) a flat Part: `Size = Vector3.new(8, 0.05, 8)`, `CFrame` = tile world position at Y=0.05 (just above ground), `Color = Color3.fromRGB(0, 200, 100)` (green), `Transparency = 0.5`, `CanCollide = false`, `Anchored = true`
  - Store a mapping `coord_key → Part` for hover updating
- `:SetHovered(row, col, isHovered)`:
  - Look up Part by coord key; change `Color` to `Color3.fromRGB(255, 230, 0)` (yellow) when hovered, back to green when not
- `:HideAll()`: destroy all Parts (or return to pool), clear mapping

**Roblox APIs:** `Instance.new("Part")`, parent to a `Folder` in `Workspace`
**Module owner:** Client only
**State:** Internal Part instances in Workspace (client-local, not replicated)
**Dependencies:** Step 1 (`CoordToWorld` for positioning)
**Risks:** Creating up to 10 Parts (5 side_pocket rows × 2 row bands) — negligible performance impact. Parts must be `LocalTransparencyModifier` immune — use standard `Transparency`.
**Completion check:** Green highlight Parts appear at all valid side_pocket tile positions when `ShowValidTiles` is called

---

### Step 3 — `PlacementGhostModel`

**File:** `src/StarterPlayerScripts/Contexts/Placement/Infrastructure/PlacementGhostModel.lua`

**Objective:** Clone the structure template, apply ghost appearance, and move it to follow the hovered tile.

**Tasks:**
- `PlacementGhostModel.new(structureType: string)`:
  - Look up `PlacementConfig.STRUCTURE_TEMPLATES[structureType]` → template name (e.g. `"Turret"`)
  - Clone from `ReplicatedStorage/Assets/Structures/{templateName}`
  - For every `BasePart` in the clone: set `Transparency = 0.5`, `CanCollide = false`, `CastShadow = false`
  - Set `Model.PrimaryPart` if not already set (find first BasePart)
  - Parent to `Workspace` (client-local)
- `:MoveTo(worldPos: Vector3)`: call `Model:PivotTo(CFrame.new(worldPos))` to snap to tile centre
- `:SetValid(isValid: boolean)`: tint all parts green (`Color3.fromRGB(0,200,100)`) if valid, red (`Color3.fromRGB(200,50,50)`) if invalid (hovered but occupied/wrong zone)
- `:Destroy()`: remove the cloned model from Workspace

**Roblox APIs:** `Instance:Clone()`, `Model:PivotTo()`, `BasePart.Transparency`, `BasePart.Color`
**Module owner:** Client only
**Dependencies:** `PlacementConfig`, `ReplicatedStorage/Assets/Structures/`
**Risks:** Template missing → `PlacementGhostModel.new` should guard with a nil check and fall back to a simple coloured box placeholder rather than erroring.
**Completion check:** Ghost model appears at tile position, moves with cursor, turns red over invalid tiles

---

### Step 4 — `PlacementCursorController` (Knit controller)

**File:** `src/StarterPlayerScripts/Contexts/Placement/PlacementCursorController.lua`

**Objective:** Own placement mode state, connect input and render loop, fire the server remote on confirm.

**State machine:**
```
Idle ──EnterPlacementMode(type)──► Active(type, hoveredCoord, isHoveredValid)
Active ──confirm click on valid tile──► Idle (after server response)
Active ──Escape / cancel──► Idle
Active ──phase leaves Prep──► Idle (forced exit)
```

**Tasks:**

**KnitInit:**
- Require `PlacementCursorService`, `PlacementHighlightPool`, `PlacementGhostModel`
- Create a `Folder` named `"PlacementCursor"` under `Workspace` for highlight Parts
- Initialise `self._state = "Idle"`

**KnitStart:**
- Subscribe to `RunController:GetAtom()` via `Charm.observe` — if `runState` leaves `"Prep"` while `_state == "Active"`, call `:_ExitPlacementMode()`

**`:EnterPlacementMode(structureType)`:**
- Guard: only if `_state == "Idle"` and `runState == "Prep"`
- Read `PlacementController:GetAtom()` snapshot → derive `occupiedSet` from `placements` array
- Call `PlacementCursorService.GetValidTiles(structureType, occupiedSet)` → `validTiles`
- Call `PlacementHighlightPool:ShowValidTiles(validTiles)` — spawn green Parts
- Call `PlacementGhostModel.new(structureType)` — spawn ghost
- Connect `RunService.RenderStepped` → `self:_OnRenderStepped()`
- Connect `UserInputService.InputBegan` → `self:_OnInputBegan(input)`
- Set `self._state = "Active"`, store `structureType`, `validTiles` set, ghost, pool refs

**`:_OnRenderStepped()`:**
- Cast a ray from `Camera:ScreenPointToRay(mouse.X, mouse.Y)` with `RaycastParams` ignoring highlight Parts and ghost
- Hit test against a flat ground plane at Y=0 (use `Workspace:Raycast` with a thin invisible ground Part, or compute plane intersection manually: `t = -ray.Origin.Y / ray.Direction.Y`, `hitPos = ray.Origin + ray.Direction * t`)
- `WorldToCoord(hitPos)` → `hoveredCoord`
- If `hoveredCoord` changed:
  - Clear previous hovered highlight; set new hovered highlight yellow
  - `isHoveredValid = validTilesSet[coord_key] ~= nil`
  - `ghost:MoveTo(CoordToWorld(row, col))`
  - `ghost:SetValid(isHoveredValid)`
- Store `hoveredCoord` and `isHoveredValid`

**`:_OnInputBegan(input)`:**
- If `input.UserInputType == Enum.UserInputType.MouseButton1`:
  - If `_state ~= "Active"` or `not isHoveredValid` → return
  - Call `self:_ConfirmPlacement()`
- If `input.KeyCode == Enum.KeyCode.Escape` or `input.UserInputType == Enum.UserInputType.MouseButton2`:
  - Call `self:_ExitPlacementMode()`

**`:_ConfirmPlacement()`:**
- Disable input briefly (set `_confirming = true`) to prevent double-fire
- Fire `PlacementRemoteClient.PlaceStructure.Invoke({ coord_row = row, coord_col = col, structureType = type })`
- Await response:
  - `success = true` → call `self:_ExitPlacementMode()`; placement atom update (from server sync) will update the UI automatically
  - `success = false` → show toast with `errorMessage`; re-enable input; stay in Active state
- Clear `_confirming`

**`:_ExitPlacementMode()`:**
- Disconnect `RenderStepped` and `InputBegan` connections
- Call `PlacementHighlightPool:HideAll()`
- Call `ghost:Destroy()`
- Set `self._state = "Idle"`
- Fire `self.PlacementCancelled` signal (for PlacementPalette to deselect the card)

**Roblox APIs:** `RunService.RenderStepped`, `UserInputService.InputBegan`, `Camera:ScreenPointToRay`, `Workspace:Raycast`, `Players.LocalPlayer:GetMouse()`
**Module owner:** Client only (Knit controller)
**Client↔Server handoff:** `PlacementRemoteClient.PlaceStructure.Invoke(request)` → returns `PlaceResponse`
**Dependencies:** Steps 1–3, `RunController`, `PlacementController`, `PlacementRemoteClient` (already generated)
**Risks:**
- `RenderStepped` + raycast every frame: use a `lastHoveredKey` dirty check to skip work when coord hasn't changed
- Rapid clicks: `_confirming` flag prevents double-invoke
- Server rejects due to race (another player occupies tile between highlight and click): show error toast, refresh valid tiles, stay in mode
**Completion check:** Full placement flow works: enter mode → hover tiles → click valid tile → server accepts → ghost and highlights removed → new structure appears via atom sync

---

### Step 5 — Wire `PlacementPalette` → `PlacementCursorController`

**File:** `src/StarterPlayerScripts/Contexts/Run/Presentation/Organisms/PlacementPalette.lua` (modify)

**Objective:** Connect card selection to cursor mode entry/exit.

**Tasks:**
- Import `Knit` and get `PlacementCursorController` in a `useEffect` or via a hook
- `onStructureSelected(type)` callback:
  - If already selected (same type) → call `PlacementCursorController:_ExitPlacementMode()` (toggle off)
  - Else → call `PlacementCursorController:EnterPlacementMode(type)`
- Subscribe to `PlacementCursorController.PlacementCancelled` signal → clear local `selectedType` state in the component (so the card visually deselects when Escape is pressed)

**State:** Local `selectedType: string?` React state in the organism
**Trigger:** User click on `StructureCard`; `PlacementCancelled` signal from controller
**Completion check:** Selecting a card enters placement mode; pressing Escape deselects the card; re-clicking the same card exits placement mode

---

### Step 6 — Cancel keybind in `InputActions`

**File:** `src/StarterPlayerScripts/Contexts/PlayerInput/Config/InputActions.lua` (modify)

**Objective:** Register a "Placement" context with a `CancelPlacement` action bound to Escape.

**Tasks:**
- Add a `"Placement"` context entry with action `CancelPlacement = Enum.KeyCode.Escape`
- `PlacementCursorController:KnitStart` activates this context on `EnterPlacementMode` and deactivates on `_ExitPlacementMode`
- This ensures Escape is consumed by placement when active and doesn't bleed into other systems

**Note:** `RightMouse` cancel is handled directly in `UserInputService.InputBegan` inside the controller (outside OmrezKeyBind) since it's a mouse button, not a key.

**Dependencies:** Step 4
**Completion check:** Escape cancels placement without triggering other keybind actions

---

## Validation Checklist

### Functional Tests
- [ ] Selecting a structure card enters placement mode: green highlights appear on all valid `side_pocket` tiles
- [ ] Ghost model follows cursor, snapping to tile centres
- [ ] Ghost turns yellow/green over valid unoccupied tiles; red over invalid/occupied tiles
- [ ] Clicking a valid tile fires `PlaceStructure.Invoke` with correct `coord_row`, `coord_col`, `structureType`
- [ ] On server success: ghost and highlights removed, new structure appears in world via atom sync
- [ ] On server rejection (`NOT_PREP_STATE`, `TILE_UNAVAILABLE`, etc.): toast message shown, placement mode stays active
- [ ] Escape key cancels placement mode: ghost and highlights removed, palette card deselects
- [ ] Right-click cancels placement mode
- [ ] Re-clicking the same structure card toggles placement mode off
- [ ] Phase transition Prep→Wave force-exits placement mode cleanly

### Edge Cases
- [ ] All valid tiles already occupied (capacity or all side_pockets full): `GetValidTiles` returns empty array; ghost still follows cursor but always shows red; click does nothing
- [ ] Player clicks during `_confirming` (server round-trip in progress): second click ignored
- [ ] Server race: another player (future co-op) occupies tile between client highlight and click → server returns `TILE_UNAVAILABLE` → toast shown, valid tiles refreshed
- [ ] Template asset missing from `ReplicatedStorage/Assets/Structures/` → ghost falls back to placeholder box, no error thrown
- [ ] Cursor moves off the grid (hits sky or off-map): `WorldToCoord` returns nil; ghost hides or stays at last valid position; no crash
- [ ] Run ends during placement (`RunEnd` state): `_ExitPlacementMode` triggered by atom subscription; no lingering highlights or ghost

### Security Checks
- [ ] No new server validation added or removed — `PlaceStructurePolicy` re-validates everything server-side
- [ ] Client only derives visual state from `WorldConfig` + `PlacementAtom`; cannot bypass server checks
- [ ] `coord_row` and `coord_col` are sent as numbers; Blink schema enforces `u8` type on both sides
- [ ] `_confirming` flag prevents rapid-fire remote invocations from the same client

### Performance Checks
- [ ] `RenderStepped` handler uses dirty-check (`lastHoveredKey`) — full work only when hovered tile changes, not every frame
- [ ] Maximum ~10 highlight Parts created (5 side_pocket columns × 2 rows) — negligible
- [ ] Ghost model is a single cloned Model — one clone per placement mode session, destroyed on exit
- [ ] `Workspace:Raycast` with a narrow params list (2 ignore instances) — fast

---

## Critical Files

| File | Role |
|---|---|
| [WorldConfig.lua](src/ReplicatedStorage/Contexts/World/Config/WorldConfig.lua) | Grid dimensions, tile size, zone layout — read-only |
| [PlacementConfig.lua](src/ReplicatedStorage/Contexts/Placement/Config/PlacementConfig.lua) | Valid zone types, costs, template names — read-only |
| [PlacementController.lua](src/StarterPlayerScripts/Contexts/Placement/PlacementController.lua) | Provides PlacementAtom for occupied tile set |
| [PlacementRemoteClient.luau](src/Network/Generated/PlacementRemoteClient.luau) | Generated Blink client — fires PlaceStructure.Invoke |
| [PlacementPalette.lua](src/StarterPlayerScripts/Contexts/Run/Presentation/Organisms/PlacementPalette.lua) | Modified to wire onStructureSelected |
| [InputActions.lua](src/StarterPlayerScripts/Contexts/PlayerInput/Config/InputActions.lua) | Modified to add Placement cancel context |
| [PlaceStructurePolicy.lua](src/ServerScriptService/Contexts/Placement/PlacementDomain/Policies/PlaceStructurePolicy.lua) | Server validation — read-only reference |
