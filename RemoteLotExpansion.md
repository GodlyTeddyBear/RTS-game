# Plan: Remote Lot Expansion — New Zone Areas

## Context

The remote lot uses Roblox Terrain (voxels), so transparency tricks cannot hide/show expansion land. New expansion areas must be **generated dynamically at runtime** (terrain stamped, model content cloned in) when purchased, not pre-placed in the template and hidden. Physical barriers in the lot model block off unowned areas; these must be destroyed on purchase.

The existing `RemoteLotRevealService` (transparency-based) is **not appropriate** for terrain-backed expansions. `PurchaseAreaExpansion` currently calls `RevealService:RevealArea()` and `EntityFactory:RegisterExpansionZones()` — the reveal step needs to be replaced or supplemented with: (1) terrain stamping, (2) barrier removal, (3) dynamic model placement.

---

## Architecture Change: Reveal → Expand

Replace `RevealService:RevealArea()` in `PurchaseAreaExpansion` with a new **`RemoteLotExpansionService`** that handles terrain-backed expansion. The old `RevealService` stays for any purely model-based content; this new service handles the terrain + barrier lifecycle.

---

## Implementation Steps

### Step 1 — Add expansion terrain templates to Studio

Each expansion area needs its own terrain template bounds in `workspace.TerrainHelper`, similar to the existing `TemplateBounds`. Name each one to match the area (e.g. `TemplateBounds_NorthMeadow`). The `RemoteLotTerrainTemplate` read/stamp logic already works generically — we'll instantiate one per expansion area.

**Alternative (simpler):** Author one combined template that includes all expansion terrain. On expansion purchase, stamp only the relevant sub-region. This avoids multiple `TerrainTemplate` instances but requires knowing each area's offset within the combined template.

**Recommended:** One `TemplateBounds_<AreaId>` Part per expansion area for clarity and independence.

### Step 2 — Add `AreaTerrainBounds` to `RemoteLotAreaConfig`

**File:** `src/ReplicatedStorage/Contexts/RemoteLot/Config/RemoteLotAreaConfig.lua`

Add a field to `TRemoteLotArea` and populate it per entry:

```lua
export type TRemoteLotArea = {
    -- existing fields ...
    AreaTerrainBoundsName: string?,  -- name of the TemplateBounds Part for this area's terrain
    AreaModelTemplate: string?,      -- name of a Model child inside TemplateBounds for zone content
}
```

Example new area entry:
```lua
SunlitGrove = {
    AreaId = "SunlitGrove",
    TargetId = "RemoteLot_SunlitGrove",
    DisplayName = "Sunlit Grove",
    Description = "A sun-warmed clearing ideal for expanded farming.",
    RevealGroupName = "SunlitGrove",
    ZoneFolders = { "Farm" },
    Conditions = { Gold = 1500 },
    SortOrder = 40,
    AreaTerrainBoundsName = "TemplateBounds_SunlitGrove",
    AreaModelTemplate = "SunlitGroveModel",
},
```

### Step 3 — Create `RemoteLotExpansionService`

**File (new):** `src/ServerScriptService/Contexts/RemoteLot/Infrastructure/Services/RemoteLotExpansionService.lua`

Responsibilities:
1. **StampExpansionTerrain(areaDef, destinationCenter)** — reads the area's `TemplateBounds_<AreaId>` Part, stamps terrain at the player's lot position (reuse `RemoteLotTerrainTemplate` logic or instantiate a second one).
2. **PlaceExpansionModel(areaDef, remoteLotModel, destinationCenter)** — clones the zone content model from inside `TemplateBounds_<AreaId>`, parents it under the remote lot model, positions it correctly.
3. **RemoveBarrier(remoteLotModel, areaDef)** — finds `remoteLotModel:FindFirstChild("Barrier")`, then finds the child named `areaDef.RevealGroupName` (or `areaDef.AreaId`) inside it, and destroys it. If the `Barrier` folder doesn't exist, `warn("[RemoteLotExpansionService] No Barrier folder on remote lot model")` and return.

```lua
function RemoteLotExpansionService:RemoveBarrier(model: Model, areaDef: any)
    local barrierFolder = model:FindFirstChild("Barrier")
    if not barrierFolder then
        warn("[RemoteLotExpansionService] No Barrier folder found on remote lot model — skipping barrier removal")
        return
    end
    local barrier = barrierFolder:FindFirstChild(areaDef.RevealGroupName)
    if barrier then
        barrier:Destroy()
    end
end
```

### Step 4 — Update `PurchaseAreaExpansion` command

**File:** `src/ServerScriptService/Contexts/RemoteLot/Application/Commands/PurchaseAreaExpansion.lua`

Replace the `RevealService:RevealArea()` call with `ExpansionService:Expand()` (or call the three methods in sequence). Remove the `Ensure(self._revealService:GetAreaGroup(model, areaDef), ...)` guard — there is no pre-placed area group to check anymore.

```lua
-- Before:
Ensure(self._revealService:GetAreaGroup(model, areaDef), "AreaModelMissing", Errors.AREA_MODEL_MISSING)
Try(self._unlockContext:PurchaseUnlock(player, areaDef.TargetId))
self._revealService:RevealArea(model, areaDef)

-- After:
Try(self._unlockContext:PurchaseUnlock(player, areaDef.TargetId))
self._expansionService:StampExpansionTerrain(areaDef, lotCFrame.Position)
self._expansionService:PlaceExpansionModel(areaDef, model, lotCFrame)
self._expansionService:RemoveBarrier(model, areaDef)
```

Also inject `RemoteLotExpansionService` via `registry:Get("RemoteLotExpansionService")` in `Init`.

### Step 5 — Register `RemoteLotExpansionService` in the context

**File:** `src/ServerScriptService/Contexts/RemoteLot/RemoteLotContext.lua`

Add `RemoteLotExpansionService` to the service registry alongside the existing infrastructure services.

### Step 6 — Author the Barrier folder in Studio

In the remote lot template model, add a `Barrier/` folder. Inside it, place one child per expansion area named exactly `areaDef.RevealGroupName` (e.g. `Barrier/NorthMeadow`, `Barrier/StoneRidge`). These are the physical wall/fence models blocking off unowned terrain. They are destroyed on purchase.

---

## Files to Modify

| File | Change |
|------|--------|
| `src/ReplicatedStorage/Contexts/RemoteLot/Config/RemoteLotAreaConfig.lua` | Add `AreaTerrainBoundsName`, `AreaModelTemplate` fields; add new area entries |
| `src/ServerScriptService/Contexts/RemoteLot/Application/Commands/PurchaseAreaExpansion.lua` | Replace RevealService call with ExpansionService; remove area-group existence guard |
| `src/ServerScriptService/Contexts/RemoteLot/RemoteLotContext.lua` | Register `RemoteLotExpansionService` |
| Remote lot template model (Studio) | Add `Barrier/<RevealGroupName>` folders per expansion area |
| `workspace.TerrainHelper` (Studio) | Add `TemplateBounds_<AreaId>` Parts with terrain + model per expansion area |

**New file:**
| `src/ServerScriptService/Contexts/RemoteLot/Infrastructure/Services/RemoteLotExpansionService.lua` | Terrain stamp + model placement + barrier removal |

**Unchanged:**
- `RemoteLotRevealService` — keep as-is for any non-terrain uses
- `RemoteLotEntityFactory:RegisterExpansionZones()` — still called after expand; zone folder must exist on the dynamically placed model
- `RemoteLotAreaUnlockConfig.lua` — auto-derived, no change
- `LandCustomizerScreen` / UI — generic, no change

---

## Verification

1. Set a new area's `Gold` condition to `1` for testing.
2. In Studio with `rojo serve`, open the Land Customizer — the card should appear.
3. Purchase it — terrain should stamp into the world at the lot's position.
4. The barrier model for that area should be destroyed.
5. Zone content model should appear correctly positioned.
6. `EntityFactory:RegisterExpansionZones` should register the new zone; verify buildings can be placed there.
7. Restore real Gold value when done.
