# Shared Entity ECS Architecture

High-level reference for the current ECS architecture in this repo.

Related contracts:
- [../../methods/ECS/COMPONENT_RULES.md](../../methods/ECS/COMPONENT_RULES.md)
- [../../methods/ECS/ENTITY_FACTORY_RULES.md](../../methods/ECS/ENTITY_FACTORY_RULES.md)
- [../../methods/ECS/SYSTEM_RULES.md](../../methods/ECS/SYSTEM_RULES.md)
- [../../methods/ECS/PHASE_AND_EXECUTION_RULES.md](../../methods/ECS/PHASE_AND_EXECUTION_RULES.md)
- [../../methods/ECS/ENTITY_RUNTIME_BOUNDARIES.md](../../methods/ECS/ENTITY_RUNTIME_BOUNDARIES.md)
- [../../methods/ECS/REQUEST_AND_OUTCOME_PIPELINE_RULES.md](../../methods/ECS/REQUEST_AND_OUTCOME_PIPELINE_RULES.md)

---

## Overview

- ECS runtime ownership is centralized in `EntityContext`.
- Feature contexts do not own separate JECS worlds, component registries, or entity factories.
- `AIContext` decides behavior and writes intent only.
- Shared domain systems advance actor state or resolve request entities.
- Services support systems with reads, caches, registries, math, and Roblox integration. Services do not own gameplay orchestration.

---

## Ownership Model

| Owner | Owns | Does Not Own |
|------|------|--------------|
| `EntityContext` | Shared ECS world, compiled schema, entity factory, runtime phases, destruction gating, model binding, sync, replication transport | Feature-specific game rules |
| Feature context | Feature schema, spawn/setup payloads, AI profiles/behaviors, feature queries, feature events | Private ECS world, duplicate runtime infrastructure |
| `AIContext` | Evaluations, actions, fact providers, action start, behavior execution | Combat, movement, mining, construction, cleanup effects |
| Shared domain contexts such as `Combat` | Actor state systems, request resolution systems, derived presentation and outcomes | AI decision ownership |

---

## Runtime Flow

```text
Feature command
    -> EntityContext creates entity from archetype
    -> feature writes standardized components
    -> AIContext writes AI.ActionIntent
    -> shared ActionStart system writes actor state
    -> domain systems advance actor state
    -> domain systems emit request entities
    -> resolver systems consume requests
    -> cleanup systems resolve transient requests and outcomes
```

The intended rule is:

- Actor state lives on the actor entity.
- Work requests live in transient request entities.
- Systems own progression.
- Services assist systems but do not replace them.

---

## Runtime Infrastructure

- Model spawning, binding, polling, projection, cleanup orchestration, and replication belong to `EntityContext`.
- Feature contexts register runtime setup through `EntityContext:RegisterEntityFeature`; feature-facing binding, sync, and replication callback APIs are not part of the public architecture.
- Feature contexts provide data through components such as model asset or outcome selectors.
- Gameplay state should replicate through ECS component replication, not through ad hoc instance attributes.
- Reveal attributes and tags are transitional discovery metadata only. They are not a gameplay state channel.

---

## Design Rules

- Prefer one shared system per mechanic category over duplicate feature-specific systems.
- Use feature configuration and component-selected outcomes instead of hardcoded per-context registration methods.
- If work can be expressed as `state -> request -> resolver`, use that pipeline instead of a service that performs the full action internally.
- A service may compute, cache, query, or bridge Roblox APIs. A service must not secretly own multi-step gameplay flow.

---

## Example

```text
AI.ActionIntent(Attack)
    -> ActionStartSystem
    -> Combat.AttackState on actor
    -> CombatAttackSystem
    -> Combat.HitboxRequest or Combat.ProjectileRequest
    -> CombatImpactSystem
    -> Combat.HealthChangeRequest
    -> HealthChangeResolveSystem
    -> Entity.Health
```

Cleanup follows the same pattern:

```text
Entity.CleanupOutcomes
    -> Entity.CleanupOutcomeRequest entities
    -> CleanupResolve systems
    -> processed or failed cleanup requests
    -> entity unbind/delete only after success
```

---

## Cross-References

- Use [ENTITY_IMPLEMENTATION_PIPELINE.md](ENTITY_IMPLEMENTATION_PIPELINE.md) for end-to-end entity migration and feature setup.
- Use [SYSTEMS.md](SYSTEMS.md) for backend runtime and library references.
