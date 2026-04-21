# Context-owned unlock registry

Unlock runtime (`UnlockContext`, persistence, `IsUnlocked`) stays in the Unlock bounded context. **Static unlock definitions** are owned by the context that owns the gameplay entity, then merged into `ReplicatedStorage.Contexts.Unlock.Config.UnlockConfig`.

## Contract

Types: `ReplicatedStorage.Contexts.Unlock.Types.UnlockEntryTypes` (`TUnlockEntry`, `TUnlockConditions`).

Each owning context exposes a module returning `{ [string]: TUnlockEntry }` keyed by the same string used as `targetId` in unlock state and UI.

## Ownership map

| Category         | Owning context | Export module |
|------------------|----------------|---------------|
| `ShopItem`       | Inventory      | `Inventory.Config.ItemUnlockConfig` (derived from `ItemConfig`) |
| `Building`       | Building       | `Building.Config.BuildingUnlockConfig` |
| `Role`           | Worker         | `Worker.Config.RoleUnlockConfig` |
| `Ore`            | Worker         | `Worker.Config.OreUnlockConfig` |
| `Tree`           | Worker         | `Worker.Config.TreeUnlockConfig` |
| `Zone`           | Quest          | `Quest.Config.ZoneUnlockConfig` |
| `CommissionTier` | Commission     | `Commission.Config.CommissionTierUnlockConfig` |

## Aggregator

`UnlockConfig/init.lua` merges all exports into one frozen table. Add a new unlockable kind by defining it in the owning context and adding one `require` to the aggregator.

## Guardrails

- Keep existing `TargetId` strings when moving rows to avoid invalidating saved unlock state.
- Avoid defining the same `TargetId` in two export modules.
