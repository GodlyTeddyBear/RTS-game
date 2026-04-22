# Asset Access Contracts

Method contracts for loading runtime assets through `AssetFetcher` registries instead of direct asset tree traversal.

---

## Core Rules

- Follow the required contracts in the sections below.
- Treat Prohibitions, Failure Signals, and Checklist as pass/fail requirements.

---

## Intent

Prevent inconsistent asset loading behavior by enforcing a single access pattern:

1. Create an asset registry through `AssetFetcher`.
2. Cache the registry on the owning module.
3. Resolve assets through registry methods, not direct `FindFirstChild` chains.

This contract applies to backend modules that load models, effects, animations, sounds, or other runtime assets from `ReplicatedStorage.Assets`.


---
## Required Pattern

### Registry creation before asset usage

- Require `ReplicatedStorage.Utilities.Assets.AssetFetcher`.
- In `Init` (or equivalent setup lifecycle), create the appropriate registry for the owned asset folder.
- Cache the registry as module state (example: `self._entityRegistry`, `self._buildingRegistry`).

### Asset resolution through registry APIs

- Read assets through registry methods only (for example, `GetEnemyModel`, `GetBuildingModel`, `GetSkillEffect`).
- Keep direct tree lookup limited to locating the root folder needed to construct the registry.
- Clone or prepare instances after registry retrieval, not before.


---
## Prohibitions

- Do not resolve runtime assets via direct deep traversal such as:
  - `ReplicatedStorage.Assets.<...>:FindFirstChild(...)` chains for each fetch.
  - `WaitForChild` chains used as the primary runtime fetch path.
- Do not bypass an existing registry by loading equivalent assets directly from `ReplicatedStorage.Assets`.
- Do not spread asset path knowledge across multiple methods when a single registry can encapsulate lookup and fallback behavior.


---
## Failure Signals

- Duplicate or divergent fallback behavior across modules loading the same asset family.
- Repeated direct `Assets` traversal in runtime methods (`Spawn`, `Create`, `Play`, etc.).
- Asset lookup regressions caused by path/name changes that a registry should have absorbed.


---
## Checklist

- [ ] Module creates the correct registry through `AssetFetcher.Create*Registry(...)`.
- [ ] Registry creation happens during setup lifecycle before runtime fetches.
- [ ] Runtime asset reads use registry methods, not direct `Assets` traversal.
- [ ] Registry reference is cached and reused instead of rebuilt per fetch.
- [ ] Any temporary legacy direct lookup path is explicitly isolated and marked for removal.

---

## Examples

<!-- Add context-specific correct usage examples here when updating this contract. -->

