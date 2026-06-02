# Combat Overview

Combat is a shared Entity-backed domain pipeline. It does not run behavior trees and it does not own feature entities. `AIContext` selects semantic actions, `EntityContext` schedules ECS phases, and Combat advances shared movement, attacks, transient requests, damage, and status effects.

## Ownership

| Layer | Responsibility |
|------|----------------|
| `AIContext` | Selects `AI.ActionIntent` and starts actor-state components through the shared action execution system. |
| `EntityContext` | Owns ECS lifecycle, phase execution, instance binding, cleanup contributors, and deferred request destruction. |
| `CombatContext` | Registers `Movement.*` and `Combat.*` schemas, services, and domain systems. |
| Feature contexts | Own actor setup, profiles, behavior trees, presentation projection, and feature cleanup. |

## Movement Flow

```text
AI.ActionIntent(Advance | ManualMove | EngageEnemy)
  -> Movement.MoveIntent
  -> MovementGridSystem
  -> MovementFlowCalculationSystem
  -> Movement.ApplyState
  -> MovementApplySystem
  -> Entity.Transform / Humanoid integration
```

Focused movement services provide grid construction, path handles, shared flowfields, snapshots, dispatch infrastructure, actor reads, and Roblox integration. Systems retain ECS decisions and component writes.

## Attack Flow

```text
AI.ActionIntent(Attack)
  -> Combat.AttackState
  -> AttackAdvanceSystem
  -> HitboxSpawnRequest | ProjectileSpawnRequest | DamageRequest
  -> impact systems
  -> Combat.DamageRequest
  -> DamageResolveSystem
  -> Entity.Health
  -> Combat.HealthDepletedRequest
  -> feature lifecycle systems
```

Attack variants are data in `Config/CombatAbilities.lua`. Mechanic categories branch into request resolvers; feature contexts do not execute raw AI action intents.

## Key Files

- [CombatContext.lua](../Contexts/Combat/CombatContext.lua)
- [CombatAbilities.lua](../Contexts/Combat/Config/CombatAbilities.lua)
- [Movement systems](../Contexts/Combat/Infrastructure/Systems/Movement)
- [Attack systems](../Contexts/Combat/Infrastructure/Systems/Attack)
- [Movement services](../Contexts/Combat/Infrastructure/Services/Movement)
