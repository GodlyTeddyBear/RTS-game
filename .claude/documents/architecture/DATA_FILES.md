# Data File Organization

Large data files (configs, event registries, dialogue trees) must be **split into a folder module** once they grow beyond a single logical category. This keeps files scannable and avoids merge conflicts in large tables.

---

## When to Split

Split a data file into a folder module when it contains **more than one logical category** of entries, or when a single category has grown large enough that scrolling past it obscures the rest of the file.

Do **not** split a file that contains only one cohesive group of entries — a flat file is simpler and preferred.

---

## Two Splitting Patterns

### Pattern A — Partitioned Data (no aggregator logic)

Used when the data is a flat dictionary keyed by ID and callers require the full merged table. Each child file owns one category slice. The `init.lua` merges all slices and returns the unified table.

**Example: RecipeConfig**

```
Config/
└── RecipeConfig/
    ├── init.lua          ← merges all slices, returns unified table
    ├── Weapons.lua       ← { [RecipeId.X]: RecipeDef, ... }
    ├── Armor.lua
    ├── Accessories.lua
    ├── Materials.lua
    └── Consumables.lua
```

`init.lua` structure:
```lua
--!strict
local config = {}

for _, mod in {
    require(script.Weapons),
    require(script.Armor),
    require(script.Accessories),
    require(script.Materials),
    require(script.Consumables),
} do
    for k, v in mod do
        config[k] = v
    end
end

return table.freeze(config)
```

Each slice file returns a plain table — no freeze, no aggregation:
```lua
--!strict
local RecipeId = require(script.Parent.Parent.Types.RecipeId)
local ItemId   = require(...)

return {
    [RecipeId.IronSword] = { ... },
    [RecipeId.SteelSword] = { ... },
}
```

---

### Pattern B — Structured Aggregation (typed merge)

Used when child modules carry internal structure that must be assembled before returning (e.g. nodes merged across chapters, or an `init.lua` that applies types and validation). The aggregator `init.lua` performs meaningful logic beyond a flat merge.

**Example: GuideTree (dialogue nodes split by chapter)**

```
DialogueTrees/
├── init.lua              ← returns { [NPCId]: TDialogueTree }
└── GuideTree/
    ├── init.lua          ← assembles TDialogueTree from chapters
    └── Chapter1.lua      ← returns { [nodeId]: TDialogueNode }
```

Outer `init.lua` (registry):
```lua
local GuideTree = require(script.GuideTree)

return table.freeze({
    Eldric = GuideTree,
})
```

Inner `init.lua` (assembler):
```lua
local Chapter1 = require(script.Chapter1)

local function mergeNodes(...): { [string]: TDialogueNode }
    local merged = {}
    for _, chapter in { ... } do
        for id, node in chapter do merged[id] = node end
    end
    return merged
end

local GuideTree: TDialogueTree = {
    NPCId = "Eldric",
    RootNodeId = "root",
    Nodes = mergeNodes(Chapter1),
}

return GuideTree
```

**Example: GameEvents (domain slices merged into a registry)**

```
Events/
└── GameEvents/
    ├── init.lua              ← wires Bus, merges all domain event modules
    ├── Contexts/             ← server bounded-context events
    │   ├── Combat.lua
    │   ├── Worker.lua
    │   └── ...
    ├── Dialogue/             ← dialogue-driven events
    │   └── Guide.lua
    └── Misc/                 ← cross-cutting events
        ├── UI.lua
        └── Persistence.lua
```

Each domain module exports `{ events: {...}, schemas: {...} }`. The `init.lua` aggregates them into a single `Events` table and wires the `EventBus`.

---

## Rules

| Rule | Details |
|------|---------|
| **Flat files are default** | Only split when a file spans multiple logical categories or is objectively large. |
| **One category per file** | Each child file owns exactly one slice. Never let a child file pull from siblings. |
| **`init.lua` is the only public surface** | Callers always `require` the folder (which resolves to `init.lua`). Children are internal. |
| **Children do not freeze** | Only the `init.lua` calls `table.freeze` on the final export. |
| **Group by semantics, not size** | Split along logical boundaries (weapon recipes, combat events) — not at an arbitrary line count. |
| **Subfolder categories for large registries** | When an aggregator contains multiple distinct groupings (Contexts vs Dialogue vs Misc), use subfolders rather than flat siblings. |

---

## Choosing the Right Pattern

| Situation | Use Pattern |
|-----------|-------------|
| Flat dictionary keyed by ID (configs, item tables) | A — Partitioned Data |
| Typed domain objects assembled from sub-parts (dialogue trees, chapter nodes) | B — Structured Aggregation |
| Registry that wires runtime infrastructure (event bus, validators) | B — Structured Aggregation |
