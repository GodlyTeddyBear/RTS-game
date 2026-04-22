# Tag Rules


---
## Core Rules

- Tags are zero-field components used as state markers or capability markers
- Prefer a tag over a boolean field on a data component
- Tags are created with `world:entity()`, not `world:component()`
- Tags are added and removed with `world:add` / `world:remove`, not `world:set`
- Tag naming convention: `PascalCase` + `Tag` suffix (e.g. `AliveTag`, `ActiveTag`, `SelectedTag`)
- A tag represents a binary state — if the state has associated data, use a data component instead
- Systems use tags as primary query filters; data components as secondary reads


---
## Creation

```lua
-- CORRECT: tag created with world:entity()
local aliveTag = world:entity()
_nameComponent(world, aliveTag, "Enemy.AliveTag")

-- WRONG: tag created with world:component()
local aliveTag = world:component() -- component() is for data components
```


---
## Adding and Removing

```lua
-- CORRECT
world:add(entity, aliveTag)      -- entity is now alive
world:remove(entity, aliveTag)   -- entity is now dead

-- WRONG: using world:set for a tag
world:set(entity, aliveTag, true)
```


---
## Tags vs Boolean Fields

```lua
-- CORRECT: binary alive state as a tag
local aliveTag = world:entity()
world:add(entity, aliveTag)

-- WRONG: boolean field on a data component
world:set(entity, statusComponent, { isAlive = true, isActive = false })
-- split into AliveTag and ActiveTag instead
```


---
## Tags vs Data Components

A tag is only appropriate when the state is purely binary. If the state carries any associated data, use a data component.

```lua
-- CORRECT: tag for binary "is selected" state
local selectedTag = world:entity()
world:add(entity, selectedTag)

-- CORRECT: data component for "is damaged" because it carries an amount
local damageComponent = world:component() -- { amount: number, source: number }
world:set(entity, damageComponent, { amount = 50, source = attackerEntity })

-- WRONG: tag with data attached
world:set(entity, damagedTag, { amount = 50 }) -- this should be a data component
```


---
## Querying

Tags are the primary filter in queries. Data components are read after the query narrows the set.

```lua
-- CORRECT: tag as primary filter, data component read inside
for entity in self._world:query(self._components.AliveTag) do
    local health = self._world:get(entity, self._components.Health)
    -- ...
end

-- WRONG: no tag filter, boolean check inside
for entity in self._world:query(self._components.Health) do
    local status = self._world:get(entity, self._components.Status)
    if not status.isAlive then continue end -- use AliveTag instead
end
```

---

## Examples

<!-- Add context-specific correct usage examples here when updating this contract. -->

---

## Prohibitions

- Do not violate the required rules defined in this document's Core Rules and contract sections.

---

## Failure Signals

- Implementation behavior contradicts one or more required rules in this contract.

---

## Checklist

- [ ] All required rules in this contract are satisfied.

