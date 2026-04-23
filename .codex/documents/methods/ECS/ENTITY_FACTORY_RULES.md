# Entity Factory Rules


---
## Core Rules

- Factories are the only surface for JECS mutations — never call `world:set`, `world:add`, `world:remove`, or `world:delete` outside a factory
- Each factory owns all queries for its context — systems never query the world directly
- Entity creation goes through a named factory method, never inline at the call site
- Destruction is always deferred — factories queue removal, never destroy mid-tick
- Factories expose typed getter and setter methods per component — callers never touch raw component IDs
- A factory owns exactly one entity type
- Derived factories use the shared base helper surface for standard JECS operations (`_CreateEntity`, `_Set`, `_Add`, `_Remove`, `_Get`, `_Has`) instead of calling raw world mutation methods directly


---
## Creation

Entity creation must go through a dedicated factory method. The method is responsible for setting all required components before returning the entity. An entity must never be returned in a partially initialized state.

```lua
-- CORRECT
function EnemyEntityFactory:CreateEnemy(config: EnemyConfig): number
    local entity = self._world:entity()
    self._world:set(entity, self._components.Health, {
        current = config.maxHp,
        max = config.maxHp,
    })
    self._world:add(entity, self._components.AliveTag)
    return entity
end

-- WRONG: inline construction at the call site
local entity = world:entity()
world:set(entity, components.Health, { current = 100, max = 100 })
```


---
## Reads and Writes

Factories expose typed getter and setter methods. No caller ever accesses a raw component ID. Raw world access inside a factory is reserved for JECS features not yet wrapped by the shared base helper surface, and those cases should be rare and intentional.

```lua
-- CORRECT: typed accessors
function EnemyEntityFactory:GetHealth(entity: number): HealthComponent
    return self._world:get(entity, self._components.Health)
end

function EnemyEntityFactory:SetHealth(entity: number, health: HealthComponent)
    self._world:set(entity, self._components.Health, health)
end

-- WRONG: raw component ID exposed to caller
return self._components.Health -- never expose this
```


---
## Queries

All queries are owned by the factory. Systems call factory query methods — they never iterate the world themselves.

```lua
-- CORRECT: factory owns the query
function EnemyEntityFactory:QueryAliveEntities(): { number }
    local entities = {}
    for entity in self._world:query(self._components.AliveTag) do
        table.insert(entities, entity)
    end
    return entities
end

-- WRONG: system queries the world directly
for entity in world:query(components.AliveTag) do ... end
```


---
## Destruction

Destruction is deferred. Factories never call `world:delete` mid-tick. Instead, they queue the entity for removal and a teardown system flushes the queue at the phase boundary. If a factory exposes a convenience delete method, it must still route through `MarkForDestruction` and `FlushDestructionQueue`.

```lua
-- CORRECT: deferred destruction
function EnemyEntityFactory:MarkForDestruction(entity: number)
    table.insert(self._destructionQueue, entity)
end

function EnemyEntityFactory:FlushDestructionQueue()
    for _, entity in ipairs(self._destructionQueue) do
        self._world:delete(entity)
    end
    table.clear(self._destructionQueue)
end

-- WRONG: immediate destruction mid-tick
self._world:delete(entity)
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

