# Entity Factory Rules

Method contract for the shared `EntityEntityFactory` mutation surface.

Canonical architecture references:
- [../../architecture/backend/SHARED_ENTITY_ECS_ARCHITECTURE.md](../../architecture/backend/SHARED_ENTITY_ECS_ARCHITECTURE.md)
- [ENTITY_RUNTIME_BOUNDARIES.md](ENTITY_RUNTIME_BOUNDARIES.md)

---

## Core Rules

- The shared entity factory is the only JECS mutation surface.
- Callers must not use raw `world:set`, `world:add`, `world:remove`, or `world:delete` outside the factory layer.
- Entity creation must go through factory-backed commands or archetype creation helpers, never inline at the call site.
- Systems may query through the factory's generic query API. They must not query the raw world directly.
- Immediate deletion is allowed only in the narrow runtime teardown paths explicitly owned by `EntityContext`. Normal gameplay destruction remains deferred.
- Raw component ids must not leak outside schema or factory internals.

---

## Shared Factory Model

- The repo no longer uses one gameplay factory per feature as the canonical pattern.
- `EntityEntityFactory` owns generic:
  - archetype creation
  - component get or set
  - tag add or remove
  - shared queries
  - deferred destruction queue
- Feature contexts build on top of `EntityContext` APIs rather than introducing a second factory layer for the same entity family.

---

## Creation

- Use archetypes and complete payloads.
- An entity must not be returned in a partially initialized state.
- Required runtime setup data should be written as components during creation or immediately through the same application flow.

```lua
-- Correct
local result = entityContext:CreateEntity("Enemy.Actor", {
    Identity = {
        EntityId = enemyId,
        EntityKind = "Enemy",
    },
    Health = {
        Current = maxHealth,
        Max = maxHealth,
    },
})
```

```lua
-- Wrong
local entity = world:entity()
world:set(entity, components.Health, { Current = 100, Max = 100 })
```

---

## Queries And Mutation

- Systems and commands use `EntityContext` or the shared entity factory API.
- A factory query should return entity ids only. Follow-up reads happen through component accessors or `Get`.
- Do not introduce feature-local query ownership rules that force duplicate factories.

```lua
-- Correct
local queryResult = entityFactory:Query({
    FeatureName = "Combat",
    Keys = { "HealthChangeRequest", "RequestTag" },
})
```

```lua
-- Wrong
for entity in world:query(damageRequestId, requestTagId) do
    ...
end
```

---

## Destruction

- Normal gameplay removal must be deferred through `MarkForDestruction`.
- Runtime teardown may synchronously prepare an entity for removal before the deferred delete flush.
- Cleanup side effects must be expressed through cleanup request components and systems rather than direct callback registries.

---

## Examples

```lua
-- Correct
local cleanupResult = entityContext:MarkForDestruction(entity)
if not cleanupResult.success then
    return cleanupResult
end
```

```lua
-- Wrong
world:delete(entity)
```

---

## Prohibitions

- Do not mutate JECS state outside the shared factory layer.
- Do not expose raw component ids to callers.
- Do not create feature-local factories for Entity-backed actors unless the architecture genuinely introduces a separate world.
- Do not use direct world queries in systems when the shared factory can express the same query.

---

## Failure Signals

- Feature code imports the world and mutates JECS directly.
- A context introduces a second factory for actors already owned by `EntityContext`.
- Cleanup or gameplay removal bypasses deferred destruction and runtime teardown.

---

## Checklist

- [ ] All JECS mutation flows through the shared factory layer.
- [ ] Systems query through the factory, not the raw world.
- [ ] Entity creation uses archetypes or complete factory-backed payloads.
- [ ] Gameplay destruction is deferred unless it is an explicit runtime teardown path.
