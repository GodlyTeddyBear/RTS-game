# Request And Outcome Pipeline Rules

Method contract for actor-state, request-entity, and outcome-driven ECS design.

Canonical architecture references:
- [../../architecture/backend/SHARED_ENTITY_ECS_ARCHITECTURE.md](../../architecture/backend/SHARED_ENTITY_ECS_ARCHITECTURE.md)
- [COMPONENT_RULES.md](COMPONENT_RULES.md)
- [SYSTEM_RULES.md](SYSTEM_RULES.md)
- [PHASE_AND_EXECUTION_RULES.md](PHASE_AND_EXECUTION_RULES.md)

---

## Core Rules

- Persistent actor state lives on the actor entity as components.
- Transient work lives in request entities as components and tags.
- Systems advance state, emit requests, resolve requests, or mark outcomes. They do not execute an entire multi-domain feature in one place.
- Cleanup, damage, projectiles, hitboxes, build contributions, and similar work should be expressed as request pipelines when multiple systems or domains participate.
- Services may help a system compute or bridge Roblox APIs, but systems must remain the owners of orchestration.

---

## Actor State vs Request Entities

### Actor State

Use actor-owned components when the data answers:

- what is this entity currently doing
- what state is this entity currently in
- what authoritative long-lived value should other systems read

Examples:

- `Combat.AttackState`
- `Movement.MoveIntent`
- `Mining.MiningState`
- `AI.ActionState`

### Request Entities

Use transient request entities when the data answers:

- what work needs to happen now
- what downstream system should process next
- what short-lived outcome should be resolved and then discarded

Examples:

- `Combat.HealthChangeRequest`
- `Combat.HitboxRequest`
- `Entity.CleanupOutcomeRequest`
- `Combat.HealthDepletedRequest`

---

## Pipeline Rules

- AI or player input writes an actor-level request such as `AI.ActionIntent`.
- Action start systems convert that intent into actor state.
- Domain systems read actor state and emit request entities when side effects or downstream work are needed.
- Resolver systems consume request entities and write the next authoritative component or next request.
- Cleanup systems mark processed or failed requests and destruction happens only after validation passes.

---

## Outcome Rules

- Outcomes are selected through components or data, not ad hoc callback registration.
- A selected outcome should produce a request entity or drive a dedicated outcome system.
- Cleanup outcomes must be resolved before runtime unbind and deletion.
- Unknown outcomes are failures. Silent success is not allowed.

---

## Examples

```text
AI.ActionIntent(Attack)
    -> ActionStartSystem
    -> Combat.AttackState
    -> CombatAttackSystem
    -> Combat.ProjectileRequest
    -> ProjectileImpactSystem
    -> Combat.HealthChangeRequest
    -> HealthChangeResolveSystem
    -> Entity.Health
```

```text
Entity.CleanupOutcomes
    -> Entity.CleanupOutcomeRequest
    -> CleanupResolve systems
    -> CleanupProcessedTag or CleanupFailedTag
    -> runtime unbind/delete only after all requests succeed
```

---

## Prohibitions

- Do not let a single service perform the full gameplay pipeline behind the scenes.
- Do not resolve cleanup, damage, or other multi-step work through callback registries when request entities and systems can own it.
- Do not store persistent action state in services or system objects.
- Do not let multiple systems write the same authoritative state component.
- Do not use request entities as long-lived actor state.

---

## Failure Signals

- A service named `*Service` is effectively the attack system, movement system, or cleanup system.
- A feature has duplicate per-entity execution systems where one shared domain system should exist.
- Cleanup or damage effects bypass request entities and directly perform all work in one callback.
- Actor state and transient work are mixed into one component without a clear lifecycle.

---

## Checklist

- [ ] Persistent actor state is stored on the actor entity.
- [ ] Transient work is expressed as request entities.
- [ ] Systems own orchestration and authoritative writes.
- [ ] Services only assist with reads, caches, calculations, or Roblox integration.
- [ ] Outcome resolution is component-selected and system-executed.
