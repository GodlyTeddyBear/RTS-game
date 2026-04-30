# Utility Use

This document defines how shared utilities should be used in this codebase, when they belong in `ReplicatedStorage/Utilities/`, and how to decide whether a helper is a shared utility or a context-owned service.

Use this as the default reference when introducing or reviewing a helper such as `ModelPlus`, `SpatialQuery`, `PlacementPlus`, `Specification`, `BaseContext`, `BaseApplication`, or `BasePersistenceService`.

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
- When a reusable helper already exists for the job, prefer it over direct Roblox API calls or one-off math/helpers in both backend and frontend code.
- When the work is in the same family as an existing utility, treat that utility as the default starting point before writing new helper logic.
- `Orient`, `SpatialQuery`, `ModelPlus`, and `PlacementPlus` own their respective shared technical use cases and must be used when a call site fits those cases.

---

## Where Utilities Live

- Shared utilities belong in `src/ReplicatedStorage/Utilities/` when they are intended to be required by multiple contexts or reused by infrastructure code.
- Utilities may still have narrow purpose boundaries, but they are shared technical helpers rather than feature services.

Examples of utility-style modules in this project:

- `BaseContext`
- `BaseApplication` (`BaseCommand` / `BaseQuery`)
- `BasePersistenceService`
- `Result`
- `Specification`
- `AssetFetcher`
- `Orient`
- `ModelPlus`
- `PlacementPlus`
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
- `BaseApplication` and `BasePersistenceService` are infrastructure helpers:
  - `BaseApplication` standardizes dependency and event-name resolution for commands and queries.
  - `BasePersistenceService` standardizes profile-path read/write helpers and Result-based persistence failures.

---

## Boundary Rules

- Utilities should be reusable and narrowly focused.
- Utilities may encapsulate technical behavior, but should not become feature services.
- Utilities should not own domain decisions.
- Utilities should not own JECS world lifetime.
- Utilities should not own instance creation or cleanup.
- Utilities should not own persistence lifecycle.
- Utilities may provide persistence helper methods, but context infrastructure still owns lifecycle wiring.
- Utilities should not replace a context service when the behavior belongs to a specific bounded context.
- If a helper starts owning orchestration, move it into the appropriate context layer or service folder.
- If a related utility already covers the technical behavior, use it rather than duplicating the logic in a feature-specific helper.

---

## How To Decide

Start by checking whether the task matches an existing utility category or preferred use below. If it does, use the utility unless it would force the utility to own lifecycle, orchestration, or domain decisions.

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

Use `BaseApplication` (`BaseCommand` / `BaseQuery`) when:

- multiple commands or queries in a context need consistent dependency registration and GameEvents resolution
- the helper stays technical and reusable across contexts

Do not use `BaseApplication` when:

- the module starts encoding context-specific domain eligibility, branching, or orchestration
- event ownership and wiring belongs in a context runtime service instead of command/query helpers

Use `BasePersistenceService` when:

- infrastructure persistence modules need shared profile-path traversal and explicit Result-based boundary behavior
- contexts still own profile lifecycle wiring (`ProfileLoaded`, `ProfileSaving`, loader registration)

Do not use `BasePersistenceService` when:

- the module starts owning lifecycle events directly
- policy/spec/domain decisions are embedded into the persistence helper

---

## ECS-Specific Guidance

- `ModelPlus` and `SpatialQuery` are useful when they support ECS code, but they should remain helpers rather than owners.
- Use them when a context needs a reusable way to work with models or instance metadata, when ECS code needs a reusable spatial selection or query helper, or when the logic is technical and reusable across more than one call site.
- Do not use them when the helper starts deciding entity ownership, becomes the source of truth for ECS state, performs instance lifecycle work that belongs in an instance factory, or performs world mutation that belongs in an entity factory or system.
- `ModelPlus` can support ECS runtime object work, but it should not own the runtime object lifecycle.
- `SpatialQuery` can support selection and lookup workflows, but it should not own ECS world access or become the business decision maker.


## Preferred Utility Uses

- `Orient`, `SpatialQuery`, `PlacementPlus`, and `ModelPlus` are the required path for their matching shared scenarios.
- Use `Orient` when you need one of these scenarios:
  - facing, look-at, yaw adjustment, interpolation, translation, snapping, or projection helpers
  - reusable movement or transform helpers that would otherwise duplicate `CFrame` math
- Use `SpatialQuery` when you need one of these scenarios:
  - raycasting from a position or cursor
  - overlap or occupancy checks around a model footprint
  - range checks for combat, targeting, or detection
  - visibility or line-of-sight checks
  - nearest-candidate selection from a filtered set
  - sorting candidates by distance before picking one
- Use `PlacementPlus` when you need one of these scenarios:
  - building a placement preview from cursor or world input
  - snapping a candidate to a grid or surface
  - deriving a footprint from a model or bounds
  - computing support points or clearance volumes
  - validating whether a placement is legal before commit
  - resolving ground alignment for a structure, ghost, or preview
- Use `ModelPlus` when you need one of these scenarios:
  - reading model pivot, bounds, center, top, or bottom values
  - moving a model to a world position or CFrame
  - aligning a model to the ground or another reference point
  - rotating a model around its own pivot or another point
  - finding children or descendants inside a model by selector or predicate
  - reusing model search or traversal logic across more than one call site
- Use these utilities before raw `workspace` queries, manual `CFrame` math, or repeated model traversal when a shared helper already covers the case.
- If a call site is only "close enough" to one of these scenarios, bias toward the utility and keep any feature-specific differences at the caller.
- Do not use them when the logic is unique to one feature and would become a thin wrapper around a shared helper with feature-specific branching.
- Do not use them when the helper would need to own the lifecycle, state, or validation decision instead of returning data for the caller.

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
Good placement flow:
- `PlacementPlus` builds the candidate.
- `SpatialQuery` handles the clearance and support checks.
- `ModelPlus` handles the pivot and alignment math.
- The context still owns orchestration and business rules.
```

```text
Good client-side placement preview:
- `PlacementPlus` builds the preview candidate from the cursor hit.
- `SpatialQuery` checks local clearance or line of sight.
- `ModelPlus` moves the ghost model to the aligned preview pivot.
- The UI/controller still decides when to show or confirm the preview.
```

```text
Good combat targeting:
- `SpatialQuery` finds the nearest visible target in range.
- `ModelPlus` reads model position or center when a target is represented by a model.
- The combat service still decides whether the target is valid for the action.
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
- Do not let `BasePersistenceService` own profile lifecycle event wiring.
- Do not add domain policy/spec logic to `BaseApplication` or `BasePersistenceService`.
- Do not treat a shared helper as an excuse to mix responsibilities.
- Do not write custom or hacky replacements for `Orient`, `SpatialQuery`, `PlacementPlus`, or `ModelPlus` when their owned use cases fit.

---

## Failure Signals

- A utility starts containing feature logic instead of reusable technical helpers.
- A utility owns the lifecycle of ECS entities, live instances, or persisted data.
- A utility becomes context-specific but remains in `ReplicatedStorage/Utilities/`.
- A caller uses a utility as a substitute for a proper ECS or persistence owner.
- `BaseApplication` contains domain-rule branching or command/query orchestration beyond shared helper behavior.
- `BasePersistenceService` subscribes to lifecycle events or bypasses explicit context-owned load/save boundaries.

---

## Checklist

- [ ] The helper is reusable and technically focused.
- [ ] The helper does not own ECS, instance, or persistence lifecycle.
- [ ] The helper fits in `ReplicatedStorage/Utilities/` without becoming a feature service.
- [ ] ECS helpers like `ModelPlus` and `SpatialQuery` support ownership layers instead of replacing them.
