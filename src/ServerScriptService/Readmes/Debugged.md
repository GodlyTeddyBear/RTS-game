# Enemy Base Attack Debugged

## Symptom

Enemies would walk to the base but never transition into `AttackBase`.

The combat logs showed only:

- `Enemy base attack facts updated`
- `HasBaseTargetInRange = false`

There were no logs for:

- pending `AttackBase` selection
- `AttackBaseExecutor`

That meant the behavior tree was never reaching the base-attack branch.

## Actual Cause

The main issue was not the behavior tree definition or the executor.

`EnemyCombatAdapterService:_BuildFacts()` depends on `EnemyEntityFactory:GetPosition(entity)` to determine whether the base is in range. That ECS position is refreshed by `EnemyGameObjectSyncService:_PollEntity()`, which samples the live model transform and writes it back into the enemy ECS transform component.

The problem was that `EnemyContext` only registered `_syncService` through `RegisterSyncSystem(...)`. That schedules `SyncDirtyEntities()`, which pushes ECS state out to the model, but it does not call `Poll()`.

So the enemy ECS transform stayed stale while the live model moved. Combat kept evaluating base range from old position data, which left `HasBaseTargetInRange` false and prevented `AttackBase` from ever being queued.

## Fix

`EnemyContext:KnitStart()` now registers the same service as both:

- a poll system
- a sync system

Specifically:

```lua
EnemyBaseContext:RegisterPollSystem("_syncService", nil, "EnemySync")
EnemyBaseContext:RegisterSyncSystem("_syncService", nil, "EnemySync")
```

This makes the loop do both sides of the state flow:

- `Poll()` updates ECS position from the live enemy model
- `SyncDirtyEntities()` updates model attributes from ECS state

Once ECS position started updating continuously, facts rebuilt with current position data, `HasBaseTargetInRange` flipped to `true`, and the behavior tree could select `AttackBase`.

## Secondary Debug Notes

While tracing the issue, we also removed an outdated enemy goal shortcut and tightened the base range check:

- removed the old `Advance -> damage base -> destroy enemy` shortcut
- changed base targeting to validate against the actual base instance instead of relying on an arbitrary anchor point
- added temporary combat debug logs for facts, pending base attack selection, and base attack executor milestones

Those changes helped narrow the failure, but the root cause was stale ECS position caused by missing poll scheduling.
