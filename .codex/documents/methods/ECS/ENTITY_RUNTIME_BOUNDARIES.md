# Entity Runtime Boundaries

Method contract for shared runtime ownership in the `EntityContext` ECS architecture.

Canonical architecture references:
- [../../architecture/backend/SHARED_ENTITY_ECS_ARCHITECTURE.md](../../architecture/backend/SHARED_ENTITY_ECS_ARCHITECTURE.md)
- [ENTITY_FACTORY_RULES.md](ENTITY_FACTORY_RULES.md)
- [REQUEST_AND_OUTCOME_PIPELINE_RULES.md](REQUEST_AND_OUTCOME_PIPELINE_RULES.md)

---

## Core Rules

- `EntityContext` owns model binding, unbinding, runtime polling, projection, replication transport, and destruction preparation.
- Feature contexts write setup data through components and register systems. They do not own duplicate runtime infrastructure.
- Services may support runtime projection or polling, but they must be called by systems or `EntityContext` runtime orchestration rather than owning gameplay flow directly.
- Cleanup effects must run through ECS requests and systems, not per-feature destruction callbacks.
- Reveal metadata may exist for discovery, but gameplay state must not depend on attributes or tags as its authoritative transport.

---

## Ownership Split

### EntityContext

- Owns:
  - shared JECS world
  - schema compilation
  - entity creation and generic mutation surface
  - runtime phase execution
  - model spawn or bind lifecycle
  - runtime projection and polling hooks
  - replication schema generation and transport
  - destruction preparation and cleanup request orchestration
- Does not own:
  - feature-specific business rules
  - feature AI profiles or behavior definitions
  - combat, mining, movement, or construction gameplay semantics

### Feature Contexts

- Own:
  - feature schemas
  - spawn-time payload construction
  - behavior trees and AI profiles where applicable
  - feature-specific read APIs and events
  - domain systems for feature rules that are not yet shared
- Do not own:
  - parallel instance factories
  - sync contributor callback trees as a gameplay substitute
  - custom replication channels for Entity-backed actors

### Systems

- Own:
  - authoritative writes to their designated components
  - request creation or resolution
  - outcome projection when explicitly assigned
- Do not own:
  - long-lived mutable state outside components
  - direct system-to-system calls

---

## Runtime Data Contract

- Model selection belongs in components such as `Entity.ModelAsset` and `Entity.ModelBinding`.
- Polling and projection behavior belongs in components such as `Entity.TransformProjection`, `Entity.TransformPoll`, and related runtime components.
- Cleanup and outcome selection belong in components such as `Entity.CleanupOutcomes`, `Entity.HealthDepletedOutcome`, and `Entity.GoalReachedOutcome`.
- Feature contexts provide these components at spawn or setup time. `EntityContext` consumes them generically.

---

## Examples

```lua
-- Correct: feature spawn writes runtime setup data
local entity = entityContext:CreateEntity("Enemy.Actor", {
    ModelAsset = {
        AssetDomain = "Enemies",
        AssetId = "Swarm",
    },
    CleanupOutcomes = {
        OutcomeIds = { "AICleanup", "MovementCleanup", "TeamUnassign" },
    },
})
```

```lua
-- Wrong: feature context owns destruction side effects through callbacks.
local cleanupCallbacks = {
    EnemyTeamCleanup = function(entity)
        ...
    end,
}
```

---

## Prohibitions

- Do not create feature-local instance factories for Entity-backed actors.
- Do not register feature-specific cleanup callbacks when the effect can be expressed as cleanup requests plus systems.
- Do not use services as the hidden owner of attack, movement, cleanup, or outcome pipelines.
- Do not make attributes or tags the canonical replication mechanism for gameplay state.
- Do not split runtime ownership across both `EntityContext` and a feature context.

---

## Failure Signals

- A feature context owns model lifecycle outside `EntityContext`.
- A service performs multi-step gameplay execution without state or request components.
- Cleanup behavior is wired through callback registries instead of request entities and systems.
- Client-visible gameplay state depends on attributes rather than replicated ECS component data.

---

## Checklist

- [ ] `EntityContext` is the only runtime infrastructure owner for Entity-backed actors.
- [ ] Feature contexts provide runtime setup through components, not callback registries.
- [ ] Cleanup behavior is request-driven and system-resolved.
- [ ] Runtime projection and polling are generic `EntityContext` concerns.
- [ ] Reveal metadata, if present, is not treated as gameplay state replication.
