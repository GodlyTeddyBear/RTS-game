# World Isolation Rules

Method contract for JECS world ownership in the current shared ECS architecture.

Canonical architecture references:
- [../../architecture/backend/SHARED_ENTITY_ECS_ARCHITECTURE.md](../../architecture/backend/SHARED_ENTITY_ECS_ARCHITECTURE.md)
- [ENTITY_FACTORY_RULES.md](ENTITY_FACTORY_RULES.md)

---

## Core Rules

- `EntityContext` owns the shared gameplay JECS world.
- Feature contexts that run on the shared ECS stack must not create a second JECS world for the same actors.
- Only Infrastructure code interacts with JECS directly.
- Domain and Application layers remain decoupled from raw world access.
- Cross-context logic must go through context APIs, shared components, or request entities. It must not bypass ownership with direct world access.

---

## Shared World Model

- The canonical model is one shared world for Entity-backed gameplay actors.
- Feature isolation is expressed through:
  - feature-prefixed schemas
  - owner-scoped systems
  - component and tag ownership
  - context APIs
- World isolation now means protecting the shared world boundary from leaking into non-Infrastructure code, not spinning up one world per feature by default.

---

## Layer Boundary

```text
Infrastructure -> world ownership, schema, factory, systems
Application    -> commands and queries over EntityContext or feature context APIs
Domain         -> pure rules, no JECS imports
```

```lua
-- Correct
local result = self._entityContext:Query({
    FeatureName = "Enemy",
    Keys = { "AliveTag" },
})
```

```lua
-- Wrong
for entity in world:query(enemyAliveTagId) do
    ...
end
```

---

## Exceptions

- A separate JECS world is acceptable only when the repo intentionally introduces a distinct runtime boundary with separate ownership, scheduling, and lifecycle.
- That exception must be explicit. It is not the default pattern for feature migration.

---

## Prohibitions

- Do not create feature-local worlds for Entity-backed actors.
- Do not let Application or Domain code import the raw JECS world.
- Do not perform cross-context queries by reaching into another context's internals.

---

## Failure Signals

- A migrated feature still owns `*ECSWorldService` or a private world for actors now backed by `EntityContext`.
- A command or policy imports JECS types or the raw world.
- A feature context reads another feature's data by bypassing context APIs or shared component contracts.

---

## Checklist

- [ ] `EntityContext` is the only shared gameplay world owner for migrated actors.
- [ ] Only Infrastructure code touches JECS directly.
- [ ] Feature isolation is expressed through schemas, systems, and APIs rather than extra worlds.
- [ ] Cross-context access respects ownership boundaries.
