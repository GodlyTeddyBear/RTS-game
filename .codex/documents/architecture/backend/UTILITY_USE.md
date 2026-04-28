# Utility Use

This document defines how shared utilities should be used in this codebase, when they belong in `ReplicatedStorage/Utilities/`, and how to decide whether a helper is a shared utility or a context-owned service.

Use this as the default reference when introducing or reviewing a helper such as `ModelPlus`, `SpatialQuery`, `Specification`, or `BaseContext`.

---

## Related Docs

- [BACKEND.md](BACKEND.md) for the backend architecture overview.
- [SYSTEMS.md](SYSTEMS.md) for JECS, ProfileStore, and shared runtime context.
- [ECS_OVERVIEW.md](ECS_OVERVIEW.md) for ECS ownership boundaries.
- [STATE_SYNC.md](STATE_SYNC.md) for sync placement and cloning rules.

---

## Purpose

- Utilities are shared technical helpers that provide reusable behavior across multiple contexts or layers.
- Utilities are not business services.
- Utilities are not ECS ownership layers.
- Utilities are not persistence or sync services.
- If a module owns runtime state, world lifetime, entity lifecycle, persistence writes, or client-facing workflows, it is usually not a utility.

---

## Where Utilities Live

- Shared utilities belong in `src/ReplicatedStorage/Utilities/` when they are intended to be required by multiple contexts or reused by infrastructure code.
- Utilities may still have narrow purpose boundaries, but they are shared technical helpers rather than feature services.

Examples of utility-style modules in this project:

- `BaseContext`
- `Result`
- `Specification`
- `AssetFetcher`
- `ModelPlus`
- `SpatialQuery`

---

## Utility Categories

### Shared Core Helpers

- General-purpose helpers used by many systems or contexts.
- Examples: result helpers, cloning helpers, formatting helpers, and predicate or spec utilities.

### ECS Support Utilities

- Helpers that support ECS infrastructure without owning ECS world behavior.
- Examples: `ModelPlus` for model or instance-related ECS support, and `SpatialQuery` for reusable spatial lookup or selection logic.
- These helpers should support ECS code, not replace the ECS ownership layers.

### Infrastructure Helpers

- Shared helpers used by backend infrastructure code.
- Examples: registry helpers, asset fetchers, and wrapper utilities.
- These should still avoid owning full feature flow.

---

## Boundary Rules

- Utilities should be reusable and narrowly focused.
- Utilities may encapsulate technical behavior, but should not become feature services.
- Utilities should not own domain decisions.
- Utilities should not own JECS world lifetime.
- Utilities should not own instance creation or cleanup.
- Utilities should not own persistence lifecycle.
- Utilities should not replace a context service when the behavior belongs to a specific bounded context.
- If a helper starts owning orchestration, move it into the appropriate context layer or service folder.

---

## How To Decide

Use a utility when the module:

- provides a reusable technical helper
- has no bounded-context business ownership
- is safe to share across unrelated contexts
- does not need lifecycle wiring specific to one context

Do not use a utility when the module:

- must own context-specific state
- needs application commands or domain rules
- creates or destroys ECS entities
- creates or destroys live instances
- reads or writes `profile.Data`

---

## ECS-Specific Guidance

- `ModelPlus` and `SpatialQuery` are useful when they support ECS code, but they should remain helpers rather than owners.
- Use them when a context needs a reusable way to work with models or instance metadata, when ECS code needs a reusable spatial selection or query helper, or when the logic is technical and reusable across more than one call site.
- Do not use them when the helper starts deciding entity ownership, becomes the source of truth for ECS state, performs instance lifecycle work that belongs in an instance factory, or performs world mutation that belongs in an entity factory or system.
- `ModelPlus` can support ECS runtime object work, but it should not own the runtime object lifecycle.
- `SpatialQuery` can support selection and lookup workflows, but it should not own ECS world access or become the business decision maker.

---

## Examples

```text
Good utility:
- `SpatialQuery` accepts positions, bounds, or filters and returns query results.
- It does not create entities.
- It does not mutate the world.
- It does not decide who owns the result.
```

```text
Good ECS helper:
- `ModelPlus` helps standardize model-related lookups or setup.
- `InstanceFactory` still owns model lifecycle.
- `SyncService` still owns projection.
```

```text
Not a utility:
- a module that validates placement, spends resources, spawns models, and writes ECS state
```

---

## Prohibitions

- Do not place feature-specific orchestration in a utility module.
- Do not use a utility to bypass ECS, persistence, or context boundaries.
- Do not let a utility own lifecycle that should belong to a context service.
- Do not treat a shared helper as an excuse to mix responsibilities.

---

## Failure Signals

- A utility starts containing feature logic instead of reusable technical helpers.
- A utility owns the lifecycle of ECS entities, live instances, or persisted data.
- A utility becomes context-specific but remains in `ReplicatedStorage/Utilities/`.
- A caller uses a utility as a substitute for a proper ECS or persistence owner.

---

## Checklist

- [ ] The helper is reusable and technically focused.
- [ ] The helper does not own ECS, instance, or persistence lifecycle.
- [ ] The helper fits in `ReplicatedStorage/Utilities/` without becoming a feature service.
- [ ] ECS helpers like `ModelPlus` and `SpatialQuery` support ownership layers instead of replacing them.
