# AI System ECS Overhaul

This is a design note for replacing the current executor-centered AI runtime with a more ECS-like model.

## Goal

Move AI from:

```text
behavior tree -> executor object -> runtime lifecycle
```

to:

```text
behavior selection -> behavior/action components -> ECS systems execute
```

The intent is to make AI easier to reason about in the repo's DDD + ECS style and reduce the number of translation layers between behavior choice and gameplay effect.

## Current Shape

- The behavior system decides what action should happen.
- The runtime owns actor iteration, hook merging, action dispatch, and cleanup.
- Executors own the action lifecycle and carry most of the execution behavior.
- Contexts and adapters bridge facts, services, action state, and cleanup into the runtime.

## Target Shape

### Behavior layer

- A dedicated behavior system selects the active behavior for an entity.
- The behavior system writes components such as:
  - `CurrentBehavior`
  - `DesiredBehavior`
  - `ActionIntent`
  - `BehaviorState`

### ECS layer

- ECS systems read behavior/action components and perform the actual work.
- Systems own recurring execution by phase.
- Systems write authoritative state components and clear or advance them when needed.

### Action layer

- Action handling is no longer centered on executor objects.
- Actions become:
  - plain data tables, or
  - system-owned logic attached to a specific phase and component contract

## Proposed System Split

| System | Responsibility |
|---|---|
| `BehaviorSelectionSystem` | Reads facts and current state, then writes the next behavior or action intent. |
| `BehaviorCommitSystem` | Promotes desired behavior into current behavior and initializes behavior state. |
| `BehaviorExecutionSystem` | Reads the current behavior and emits behavior-specific intents or action components. |
| `ActionStartSystem` | Consumes action intent data and initializes active action state. |
| `ActionTickSystem` | Advances active actions over time. |
| `ActionResolveSystem` | Finalizes success, failure, cancel, or death outcomes. |
| `CleanupSystem` | Clears stale behavior/action state on removal or teardown. |

## Component Contract

Likely ECS state candidates:

- `CurrentBehaviorComponent`
- `DesiredBehaviorComponent`
- `BehaviorStateComponent`
- `ActionIntentComponent`
- `ActionStateComponent`
- `ActionIntentTag`
- `BehaviorDirtyTag`
- `ActionDirtyTag`
- `FactSnapshotComponent` or domain-specific fact components

Recommended split:

- `ActionIntent` is the next thing AI wants to happen.
- `ActionState` is the thing currently executing.
- `PendingAction` is not needed if intent and state stay separate.

Core rule:

- components carry the state
- systems carry the logic
- behavior selection does not perform the action directly

## Profiles, Evaluation, and Actions

Profiles are configuration only.

- They are used at initialization time.
- `AIContext` converts profile data into components.
- After conversion, systems should read components, not profiles.
- This makes entity creation simpler and keeps runtime state in ECS.

The execution pipeline is:

```text
behavior -> evaluation registry -> action registry -> systems
```

### Evaluation registry

The evaluation registry replaces resolvers.

- It contains global, shared, pure checks and selectors.
- Behavior trees and behavior selection logic call it to build condition logic.
- It should not mutate components.
- It should not own execution.

Example evaluation entries:

- `IsTargetInRange`
- `HasValidTarget`
- `CanAttack`
- `ShouldRetreat`
- `CanTransitionToBehavior`

### Action registry

The action registry replaces executor-style action ownership.

- It contains action producers.
- It mutates components to known values.
- It attaches the specific components or tags that systems use to identify work.
- It does not perform the action itself.

Example action entries:

- `Attack`
- `Harvest`
- `Move`
- `Guard`

Action registry output should be limited to component writes such as:

- `ActionIntent`
- `ActionIntentTag`
- `DesiredBehavior`
- action-specific trigger components

That means:

- actions are producers
- systems are consumers
- components are the handshake

### Practical split

- `AIContext`
  - reads `EntityContext`
  - reads profiles and converts them into components at spawn or setup time
  - runs behavior logic
  - calls the evaluation registry
  - calls the action registry
  - writes shared contract components

- `EntityContext`
  - owns the shared entity gateway
  - owns cleanup, death, and removal
  - exposes typed queries and state access

- Feature contexts
  - query entities through `EntityContext`
  - react to trigger components and tags
  - run their own systems on their own schedule

## Behavior State Shape

Keep `BehaviorState` small and generic. It should describe the current behavior without encoding feature-specific logic.

Suggested fields:

- `Mode`
  - the active behavior mode name, such as `Attack`, `Idle`, or `Chase`
- `EnteredAt`
  - the time the behavior became active
- `LastEvaluatedAt`
  - the last time the behavior was rechecked
- `TransitionCount`
  - how many times the entity has switched behaviors since entering the current mode
- `Flags`
  - small generic markers for transient behavior conditions

Example:

```lua
BehaviorState = {
    Mode = "Attack",
    EnteredAt = 123.45,
    LastEvaluatedAt = 123.67,
    TransitionCount = 2,
    Flags = {
        NeedsTarget = false,
        CanRetarget = true,
    },
}
```

## First Attack Flow

Use `Attack` as the first proof of concept because it exercises the full contract:

- behavior selection
- intent emission
- feature-context execution
- authoritative state resolution
- cleanup on death or removal

### Attack pipeline

1. `AIContext` reads entity state through `EntityContext`.
2. `AIContext` determines the entity should attack.
3. `AIContext` writes:
   - `DesiredBehavior = "Attack"`
   - `BehaviorState.Mode = "Attack"`
   - `ActionIntent = { ActionId = "Attack", SourceEntity = ..., TargetEntity = ..., Data = ... }`
   - `ActionIntentTag`
4. `CombatContext` queries `EntityContext` for entities with attack intent.
5. `CombatContext` systems consume the intent and create or update `ActionState`.
6. `ActionStartSystem` initializes the active attack.
7. `ActionTickSystem` advances the attack windup or active phase.
8. `ActionResolveSystem` applies damage, cooldown changes, and outcome state.
9. `EntityContext` handles death or removal when combat marks the entity for cleanup.
10. `AIContext` sees the updated state next tick and selects the next behavior.

### Attack state ownership

- `AIContext`
  - selects the behavior
  - writes the intent
  - does not apply combat results directly

- `CombatContext`
  - consumes attack intent
  - runs the attack systems
  - writes combat-specific execution state

- `EntityContext`
  - exposes the query surface
  - owns death/removal handling
  - clears or removes the entity once cleanup is required

## DDD Boundary

### Domain

Keep pure rules here:

- valid behavior transitions
- behavior selection predicates
- action eligibility checks
- cooldown and target validation rules

### Application

Keep orchestration here:

- spawn or despawn flow
- forced behavior reset
- runtime boot and shutdown sequencing
- cross-context coordination

### Infrastructure/ECS

Keep implementation here:

- component registry
- entity factory
- ECS systems
- world service
- phase order

### Infrastructure/Services

Keep integration here:

- hooks
- adapters
- runtime bridges
- non-ECS technical helpers

## Design Constraints

- One system owns writes to one authoritative component.
- Systems stay stateless.
- Systems never query the world directly when the factory exposes the query.
- Phase order is explicit and owned by the context.
- Removal and teardown use deferred cleanup.

## Why This Is Better

- Fewer runtime layers.
- More direct mapping from entity state to behavior.
- Easier to debug because the source of truth is visible in components.
- More consistent with the repo's ECS rules.
- Less executor inheritance and less lifecycle indirection.

## Tradeoffs

- More ECS components.
- More systems.
- Less convenience from one central runtime object.
- Behavior trees may need to be simplified to high-level modes instead of full per-entity tree execution.

## Open Questions

- Should behavior be a high-level mode system or a full tree-state system?
- Should action handling stay as plain tables or become separate system modules per action family?
- Should current AI state move fully into ECS, or should a small registry remain as an index layer only?
- Which contexts own the new systems:
  - `Combat`
  - `Mining`
  - `Structure`
  - `Entity`

## Suggested First Cut

1. Keep the behavior definitions.
2. Make behavior selection write `DesiredBehavior` and `PendingAction` components.
3. Move action start/tick/resolve into ECS systems.
4. Shrink the runtime until it only coordinates data flow, or remove it where it becomes redundant.
5. Rebuild one action family, such as `Attack`, as the proof of concept.

## Recommended Boundary

This gives a clean split:

- `AIContext` is the decision maker.
- `EntityContext` is the shared entity data gateway.
- `CombatContext`, `MiningContext`, and other feature contexts are the executors of domain-specific systems.

### Why this works

- `EntityContext` stays the authoritative gateway to entity state.
- Feature contexts do not need to know how entities are stored.
- AI only writes intent, so coupling stays low.
- Systems remain independent because they all read from the same entity-facing API.

### The contract

- `AIContext`
  - writes `DesiredBehavior`
  - writes `PendingAction`
  - writes `BehaviorState`
  - does not execute combat or mining directly

- `EntityContext`
  - exposes typed queries and state access
  - reads current behavior, pending action, and entity state
  - remains the shared entity gateway

- `CombatContext` and other feature contexts
  - query entities through `EntityContext`
  - run their own systems on their own schedule
  - react to intent components such as `PendingAction.ActionId == "Attack"`

### Example flow

```text
AIContext
  -> writes PendingAction = Attack

CombatContext
  -> queries EntityContext for entities with PendingAction = Attack
  -> runs combat systems
  -> writes combat results back through EntityContext
```

## Design Decisions

- `AIContext` reads from `EntityContext`.
- Shared components are the contract between contexts.
- Systems should stay as generic as possible.
- `EntityContext` owns death and removal handling.
- `AIContext` only sets the tag or intent needed for `EntityContext` to run its systems.

## Startup / Initialization

`AIContext` should not need a special runtime registration flow with `EntityContext`.

Recommended startup shape:

1. `AIContext` starts after `EntityContext` is available.
2. `AIContext` resolves `EntityContext` as a dependency.
3. `AIContext` validates that the shared AI contract components and tags exist.
4. `AIContext` performs any one-time seeding for already-loaded entities, if needed.
5. `AIContext` begins reading entity state and writing behavior intent.

### What startup should not do

- It should not register per-entity callbacks.
- It should not own the tick schedule for feature contexts.
- It should not create a second source of truth for entity state.
- It should not require a live runtime registration API unless a future plugin-style system genuinely needs it.

### Good initiation boundary

- `EntityContext` remains the entity gateway.
- `AIContext` depends on `EntityContext`.
- The feature contexts depend on `EntityContext` for queries and on the shared AI contract for intent markers.
- The only "initiation" is resolving dependencies and validating the shared contract once at startup.

### Feature context startup

`CombatContext`, `MiningContext`, and other feature contexts should also avoid a special initiation ceremony.

Recommended startup shape:

1. Resolve `EntityContext` and any local dependencies during `KnitInit` or the context's own bootstrap boundary.
2. Construct the systems that belong to the context.
3. Validate that the systems can read the shared AI contract components.
4. Register or schedule the systems inside the context's own tick pipeline.
5. Begin normal execution.

### What feature startup should not do

- It should not register per-entity callbacks with `AIContext`.
- It should not require AI to tell it when to start each system every frame.
- It should not create a second orchestration layer just for startup.
- It should not depend on hidden cross-context lifecycle hooks unless a real dependency demands it.

## Module Layout

This is the concrete structure for the ECS-style AI split:

```text
src/ServerScriptService/Contexts/
|-- AI/
|   |-- AIContext.lua
|   |-- Application/
|   |-- AIDomain/
|   `-- Infrastructure/
|       |-- Runtime/
|       |   |-- AIBehaviorSystem.lua
|       |   |-- AIDecisionSystem.lua
|       |   |-- AIIntentSystem.lua
|       |   `-- AISharedContract.lua
|       `-- Services/
|
|-- Entity/
|   |-- EntityContext.lua
|   |-- Application/
|   |-- EntityDomain/
|   `-- Infrastructure/
|       |-- ECS/
|       |   |-- EntityComponentRegistry.lua
|       |   |-- EntityEntityFactory.lua
|       |   `-- Systems/
|       |       |-- EntityDeathSystem.lua
|       |       |-- EntityRemovalSystem.lua
|       |       `-- EntityQuerySystem.lua
|       `-- Services/
|
|-- Combat/
|   |-- CombatContext.lua
|   |-- Application/
|   |-- CombatDomain/
|   `-- Infrastructure/
|       |-- ECS/
|       |   |-- CombatComponentRegistry.lua
|       |   |-- CombatEntityFactory.lua
|       |   `-- Systems/
|       |       |-- CombatActionStartSystem.lua
|       |       |-- CombatActionTickSystem.lua
|       |       |-- CombatActionResolveSystem.lua
|       |       `-- CombatCleanupSystem.lua
|       `-- Services/
|
`-- Mining/
    |-- MiningContext.lua
    |-- Application/
    |-- MiningDomain/
    `-- Infrastructure/
        |-- ECS/
        |   |-- MiningComponentRegistry.lua
        |   |-- MiningEntityFactory.lua
        |   `-- Systems/
        `-- Services/
```

## Layout Notes

- `AIContext` owns decision making and writes shared intent components.
- `EntityContext` owns the shared query gateway, cleanup, and death/removal handling.
- `CombatContext` and `MiningContext` own their own execution systems and schedule their own ticks.
- `AISharedContract.lua` is the shared type and tag vocabulary for the AI boundary.
- Feature contexts should not depend on AI internals beyond the shared contract.

### Practical rule

- `AIContext` owns the decision contract.
- Feature contexts own their own system startup and tick scheduling.
- `EntityContext` remains the shared read/write gateway for entity state.

## Implications

- `AIContext` should not directly execute combat or mining logic.
- Behavior selection should stop at writing contract components or tags.
- Feature contexts should query `EntityContext` through typed APIs and react to the contract state.
- Cleanup should happen where the authoritative entity lifecycle already lives.

## Shared Contract Example

### Minimum shared components

| Component | Purpose |
|---|---|
| `CurrentBehavior` | The active behavior the entity is currently in. |
| `DesiredBehavior` | The next behavior AI wants to switch to. |
| `BehaviorState` | Generic state for the current behavior, such as timer, phase, retry count, or transition metadata. |
| `PendingAction` | The next action the entity should execute. |
| `ActionState` | The active action lifecycle state, such as running, completed, canceled, or failed. |
| `ActionIntentTag` | Cheap query marker that tells feature contexts the entity has actionable AI intent. |
| `BehaviorDirtyTag` | Marker that tells behavior systems something changed and needs reevaluation. |
| `ActionDirtyTag` | Marker that tells action systems the pending action or action state changed. |

### Optional shared components

Add these only if multiple contexts genuinely need them:

- `TargetEntity`
- `TargetPosition`
- `ThreatLevel`
- `FactSnapshot`
- `LastBehaviorChangeAt`
- `LastActionChangeAt`

### Context-specific components

Do not make these shared unless they become universal:

- `AttackStats`
- `HarvestStats`
- `MovementStats`
- `CombatCooldown`
- `MiningCooldown`
- `Health`
- `Damage`
- `ResourceYield`

### Contract rule

- AI writes the contract.
- `EntityContext` validates or exposes the contract state.
- Feature contexts consume the contract through systems.
