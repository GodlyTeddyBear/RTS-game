# State Synchronization

State is managed via **Charm** atoms on the server and replicated to clients via **Charm-sync**. Two rules govern all state work: centralized mutation and correct cloning.

---

## Rule 1: All Mutations Go Through the Sync Service

The sync service is the **only** place that modifies atoms. Application services never touch atoms directly.
Sync service modules must live in `src/ServerScriptService/Contexts/<ContextName>/Infrastructure/Persistence/`.

```
✅ Correct:
Application Service → Sync Service → Atom

❌ Anti-Pattern:
Application Service → Atom (direct)
```

**Why:** Direct atom access bypasses the cloning discipline enforced by the sync service, causing CharmSync to miss changes.

---

## Rule 2: Getters Must Return Deep Clones

Any getter that returns atom state must return a deep clone, not a direct reference. Returning a reference lets callers mutate the atom in-place, which CharmSync cannot detect.

**The failure sequence without deep clone:**
1. Caller receives direct reference to atom state
2. Caller modifies the returned object (thinking it's a copy)
3. Modification happens directly inside the atom
4. Sync service is called to update — but old and new state are the same reference
5. No change detected → no patches sent → client never updates

**Implementation:**

```lua
local function deepClone(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end
    local clone = {}
    for key, value in pairs(tbl) do
        clone[key] = deepClone(value)
    end
    return clone
end

-- Wrong
function SyncService:GetStateReadOnly(entityId)
    local states = self.StatesAtom()
    return states[entityId]  -- Direct reference!
end

-- Correct
function SyncService:GetStateReadOnly(entityId)
    local states = self.StatesAtom()
    return states[entityId] and deepClone(states[entityId]) or nil
end
```

**When to deep clone:**
- Returning complex state from `GetXReadOnly()` methods
- Returning arrays of state objects

**When not to deep clone:**
- Returning the atom itself for subscriptions (`GetStatesAtom()` returns `self.StatesAtom`)
- Returning primitive values
- Inside mutation methods — use targeted cloning instead

---

## Nested Table Synchronization

Charm detects changes by **reference comparison**. For nested tables, you must create new references at every level along the path you modify.

### The shallow clone problem

```lua
self.Atom(function(current)
    local updated = table.clone(current)   -- Only clones top level
    updated[userId].Stats.HP = 75          -- Modifies the ORIGINAL nested table!
    return updated
end)
```

`table.clone()` is shallow — nested tables are still the same references.

### Targeted cloning (correct)

Clone every level along the path you're modifying. For N levels deep, you need N clones.

```lua
self.Atom(function(current)
    local updated = table.clone(current)
    updated[userId] = table.clone(updated[userId])
    updated[userId].Stats = table.clone(updated[userId].Stats)
    updated[userId].Stats.HP = 75   -- New reference all the way up
    return updated
end)
```

**4 levels deep example:**
```lua
-- Path: current → [userId] → Inventory → Items → [itemId]
local updated = table.clone(current)
updated[userId] = table.clone(updated[userId])
updated[userId].Inventory = table.clone(updated[userId].Inventory)
updated[userId].Inventory.Items = table.clone(updated[userId].Inventory.Items)
updated[userId].Inventory.Items[itemId] = newItemData
```

### Exception: adding entirely new structures

When adding a new entry, you create new tables — no cloning needed.

```lua
self.Atom(function(current)
    local updated = table.clone(current)
    updated[userId] = {          -- Brand new table
        Stats = { HP = 100 },
    }
    return updated
end)
```
