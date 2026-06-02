# AI Runtime Overview

`AIContext` is the only AI decision runtime. It owns reusable evaluations, actions, fact providers, behavior compilation, scheduled selection, action-intent validation, and generic action start orchestration.

Feature contexts own the behavior trees and profiles for their entities. They register those contracts with `AIContext` during startup and initialize actors through `SetupEntityAIFromProfile`.

## Decision Flow

```text
Feature fact state
  -> AI fact providers
  -> feature-owned behavior tree
  -> AI.ActionIntent
  -> AIActionIntentValidationSystem
  -> AIActionExecutionSystem
  -> domain actor state
```

`AIContext` stops at actor-state creation. Combat, movement, construction, status, mining, and future domains advance their own state or emit transient request entities.

## Ownership Rules

- Evaluations and actions are reusable AI-owned catalogs.
- Behavior trees and profiles belong to the feature context that owns the actor.
- `AI.ActionIntent` is actor-owned input state.
- Persistent action state lives on the actor.
- Temporary work such as damage, hitbox, and projectile operations uses request entities.
- No feature system consumes raw `AI.ActionIntent` to execute gameplay.

## Key Files

- [AIContext.lua](../Contexts/AI/AIContext.lua)
- [BasicEvaluations.lua](../Contexts/AI/Config/Evaluations/BasicEvaluations.lua)
- [BasicActions.lua](../Contexts/AI/Config/Actions/BasicActions.lua)
- [BasicFactProviders.lua](../Contexts/AI/Config/Facts/BasicFactProviders.lua)
- [AI systems](../Contexts/AI/Infrastructure/Systems)
