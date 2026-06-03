# Entity Implementation Pipeline

This document defines the current backend pipeline for adding or extending an Entity-backed actor family.

Canonical references:
- [BACKEND.md](BACKEND.md)
- [SHARED_ENTITY_ECS_ARCHITECTURE.md](SHARED_ENTITY_ECS_ARCHITECTURE.md)
- [../../methods/ECS/COMPONENT_RULES.md](../../methods/ECS/COMPONENT_RULES.md)
- [../../methods/ECS/ENTITY_FACTORY_RULES.md](../../methods/ECS/ENTITY_FACTORY_RULES.md)
- [../../methods/ECS/SYSTEM_RULES.md](../../methods/ECS/SYSTEM_RULES.md)
- [../../methods/ECS/ENTITY_RUNTIME_BOUNDARIES.md](../../methods/ECS/ENTITY_RUNTIME_BOUNDARIES.md)
- [../../methods/ECS/REQUEST_AND_OUTCOME_PIPELINE_RULES.md](../../methods/ECS/REQUEST_AND_OUTCOME_PIPELINE_RULES.md)

---

## Overview

- Use this pipeline when adding or migrating `Enemy`, `Structure`, `Unit`, `Summon`, or another actor family that should live in the shared `EntityContext` world.
- Start from the owning feature context.
- Keep the order: config and types first, schema second, spawn payload third, systems fourth, persistence or projection last.
- Prefer extending shared movement, attack, cleanup, and outcome pipelines over creating new feature-specific executor services.

---

## Rules

### 1. Choose the owning feature context

- The owning feature context keeps config, public APIs, AI profiles, behavior trees, and feature events.
- `EntityContext` owns the shared ECS runtime.
- Shared domain contexts such as `Combat` own shared mechanics, not feature identity.

### 2. Start with config and types

- Add stable feature data in `ReplicatedStorage/Contexts/<Context>/Config` and `Types`.
- Put role or variant selectors in config rather than spreading them across systems.
- Keep AI profiles and behavior trees in the owning feature context.

### 3. Register or extend feature schema

- Add only the feature-specific authoritative or derived components that the actor family needs.
- Reuse shared `Entity.*`, `Movement.*`, `Combat.*`, and other shared schemas where they already cover the mechanic.
- Do not recreate shared state under a feature prefix unless the meaning is genuinely different.

### 4. Spawn through EntityContext

- Use `EntityContext:CreateEntity(...)` with the correct shared or feature archetype.
- Write model selection, runtime projection, cleanup outcomes, and other setup through components.
- Do not introduce a feature-local entity factory or world for actors already owned by `EntityContext`.

### 5. Route AI through AIContext

- Register feature behavior definitions and profiles from the owning context.
- Keep evaluations, actions, and fact providers in `AIContext` when they are generic and reusable.
- AI should write intent and actor state only. It should not execute gameplay effects.

### 6. Use shared systems where the mechanic is shared

- Movement should use `Movement.*` systems.
- Attacks and damage should use `Combat.*` state and request systems.
- Cleanup should use cleanup outcome requests and cleanup resolution systems.
- Add feature systems only when the logic is genuinely feature-specific and not a duplicate shared mechanic.

### 7. Treat services as helpers

- Services may provide registries, calculations, caches, or Roblox integration.
- Systems must own the gameplay pipeline.
- If a service is effectively performing the whole movement, attack, or cleanup flow, the design is wrong.

### 8. Keep runtime projection generic

- Model binding, transform projection, humanoid projection, and polling belong to `EntityContext`.
- Feature spawn/setup writes the components that select those behaviors.
- Reveal metadata may exist temporarily for discovery, but gameplay state should rely on component replication rather than attributes.

### 9. Express outcomes as data

- Use components such as cleanup outcomes, goal-reached outcomes, and health-depleted outcomes to select behavior.
- Systems consume those outcomes and emit requests or perform the bounded effect.
- Do not register per-feature destruction callbacks when a request-driven outcome system can own the work.

---

## Current Pipeline

```text
Feature config/types
    -> feature schema registration
    -> feature spawn command builds entity payload
    -> EntityContext creates entity
    -> AIContext configures behavior where needed
    -> shared and feature systems run by phase
    -> shared runtime projection and replication
    -> cleanup outcomes resolved before deletion
```

---

## Example

### Enemy or Structure migration shape

1. Add or extend feature schema components.
2. Add or extend feature AI behaviors and profiles.
3. Spawn with `EntityContext:CreateEntity(...)` and feature setup components.
4. Use shared `Movement.*` and `Combat.*` systems for generic mechanics.
5. Add only narrow feature systems for residual feature logic.
6. Select cleanup and outcome behavior through components, not callback registration.

---

## Anti-Patterns

- Do not create a new `*ECSWorldService` for an actor family that belongs in the shared Entity runtime.
- Do not create feature-local movement, attack, or cleanup executor services when the mechanic is already shared.
- Do not put cleanup, damage, or outcome behavior behind callback registries.
- Do not replicate gameplay state by attributes when shared ECS replication should own it.
- Do not split the same mechanic across both a service-owned runtime and ECS systems.

---

## Cross-References

- Use [SYSTEMS.md](SYSTEMS.md) for runtime and library context.
- Use [UTILITY_USE.md](UTILITY_USE.md) when deciding whether logic belongs in a shared helper or in a system.
