# Immutability

Use `table.freeze()` to enforce immutability on three categories of tables: config tables, result objects from domain services, and value objects.

---

## Config Tables

All configuration tables returned from `Config/` files must be frozen. This prevents accidental mutation at runtime.

```lua
-- Config/ItemConfig.lua
return table.freeze({
    Wood   = { Name = "Wood",    MaxStack = 64, Rarity = "common" },
    Stone  = { Name = "Stone",   MaxStack = 64, Rarity = "common" },
    Diamond = { Name = "Diamond", MaxStack = 1,  Rarity = "rare" },
})
```

If the config contains nested tables, freeze those too:

```lua
return table.freeze({
    Combat = table.freeze({
        BaseDamage = 10,
        CritMultiplier = 1.5,
    }),
    Movement = table.freeze({
        WalkSpeed = 16,
        SprintSpeed = 24,
    }),
})
```

---

## Result Objects from Domain Services

Domain services return immutable result objects. Freezing them enforces the rule that callers must apply results through the sync service — not mutate them in place.

```lua
function InventoryCalculator:CalculateStackSpace(item, currentStack, addedQuantity)
    local maxStack = item.MaxStack
    local newStack = math.min(maxStack, currentStack + addedQuantity)
    local overflow = (currentStack + addedQuantity) - newStack

    return table.freeze({
        ItemId = item.Id,
        NewStack = newStack,
        OverflowQuantity = overflow,
        IsFullStack = newStack == maxStack,
    })
end
```

---

## Value Objects

Value objects freeze themselves in their constructor. After construction, fields can never change.

```lua
function ItemId.new(value: string)
    assert(type(value) == "string", "Item ID must be a string")
    assert(#value > 0, "Item ID must not be empty")

    local self = setmetatable({}, ItemId)
    self.Id = value
    return table.freeze(self)  -- frozen immediately
end
```

---

## What NOT to Freeze

- **Atom state tables** — Charm atoms need to be replaceable; freeze the result objects you pass in, not the atom itself
- **Accumulator tables** — tables being built up inside a function (e.g., an `errors` array) should not be frozen until you're done writing to them
- **JECS component data** — entity component data is managed by JECS internals; don't freeze it

---

## Freeze Checklist

- [ ] Config files return `table.freeze({...})`
- [ ] Domain service result objects are frozen before returning
- [ ] Value objects call `table.freeze(self)` at the end of `.new()`
- [ ] Nested config tables are frozen individually if they contain sub-tables
