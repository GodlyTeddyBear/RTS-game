# System Rules

Method contract for ECS systems in the shared `EntityContext` runtime.

Canonical architecture references:
- [../../architecture/backend/SHARED_ENTITY_ECS_ARCHITECTURE.md](../../architecture/backend/SHARED_ENTITY_ECS_ARCHITECTURE.md)
- [REQUEST_AND_OUTCOME_PIPELINE_RULES.md](REQUEST_AND_OUTCOME_PIPELINE_RULES.md)

---

## Core Rules

- Systems are stateless. Persistent state belongs in components.
- Systems declare reads and writes explicitly at the top of `Run` or `Tick`.
- Exactly one system owns writes to any authoritative component.
- Systems communicate through components, request entities, or explicit context events. They never call other systems directly.
- Systems own orchestration. Services assist systems but do not replace them.
- Shared systems are preferred over duplicate feature-specific systems when the mechanic is the same.

---

## Services vs Systems

- A service may:
  - read across multiple components
  - cache expensive runtime data
  - run pathfinding or targeting calculations
  - bridge to Roblox objects or APIs
- A service must not:
  - own multi-step gameplay execution
  - mutate unrelated authoritative state as a hidden pipeline
  - replace request-entity or actor-state flows

---

## Request-Driven Design

- If a mechanic spans multiple responsibilities, split it across systems.
- A system may:
  - advance actor state
  - emit request entities
  - resolve request entities
  - mark outcomes as processed or failed
- A system should not perform attack, projectile spawn, damage, cleanup, and destruction as one hidden block.

---

## Examples

```lua
-- READS: Combat.AttackState [AUTHORITATIVE]
-- WRITES: Combat.ProjectileSpawnRequest [AUTHORITATIVE]
function CombatAttackSystem:Run()
    ...
end
```

```lua
-- Wrong: service owns the whole feature pipeline
self._combatService:PerformAttack(entity, target)
```

---

## Prohibitions

- Do not store mutable frame-to-frame state on system objects.
- Do not call another system directly.
- Do not let a service become the real owner of the mechanic while the system becomes a thin wrapper.
- Do not create duplicate feature systems when one shared system can own the mechanic.

---

## Failure Signals

- A service named `*Service` is effectively the gameplay system.
- Two or more systems write the same authoritative component.
- Multiple feature contexts each own their own copy of the same movement, cleanup, or damage mechanic.

---

## Checklist

- [ ] Systems are stateless.
- [ ] Reads and writes are declared explicitly.
- [ ] One system owns each authoritative component.
- [ ] Systems communicate through components, requests, or events.
- [ ] Services support systems instead of replacing them.
