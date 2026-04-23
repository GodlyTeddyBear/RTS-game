---
name: migrate-context-ecs
description: Read when migrating a Roblox backend context, ECS layer, and runtime instance layer to BaseContext, BaseECS, and BaseInstanceFactory base classes.
---

<!-- This is a repo-local prompt template for the roblox-migrate-context-ecs skill. -->

# Migrate Context ECS

Use this workflow to migrate one existing bounded context and its ECS layer to the shared BaseContext, BaseECS, and BaseInstanceFactory classes.

---

## Migration Workflow

1. Read the required architecture and contract docs:
- `.codex/documents/methods/backend/BASE_CONTEXT_CONTRACTS.md`
- `.codex/documents/methods/backend/CONTEXT_BOUNDARIES.md`
- `.codex/documents/methods/backend/DEPENDENCY_REGISTRATION_CONTRACTS.md`
- `.codex/documents/methods/backend/ASSET_ACCESS_CONTRACTS.md`
- `.codex/documents/methods/backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md`
- `.codex/documents/methods/ECS/COMPONENT_RULES.md`
- `.codex/documents/methods/ECS/ENTITY_FACTORY_RULES.md`
- `.codex/documents/methods/ECS/WORLD_ISOLATION_RULES.md`
- `.codex/documents/methods/ECS/PHASE_AND_EXECUTION_RULES.md`
- `.codex/documents/methods/ECS/TAG_RULES.md`
- `.codex/documents/methods/ECS/INSTANCE_REVEAL_RULES.md`
2. Read the target context entry module and every target ECS world service, component registry, entity factory, system, and persistence bridge that the migration touches.
3. If the context creates Roblox runtime objects for ECS-backed entities, also read every model factory, object factory, or other runtime instance service that owns Workspace instances, attributes, or CollectionService tags.
4. Read the migrated examples before editing:
- `src/ServerScriptService/Contexts/World/WorldContext.lua`
- `src/ServerScriptService/Contexts/Commander/Infrastructure/ECS/CommanderECSWorldService.lua`
- `src/ServerScriptService/Contexts/Commander/Infrastructure/ECS/CommanderComponentRegistry.lua`
- `src/ServerScriptService/Contexts/Commander/Infrastructure/ECS/CommanderEntityFactory.lua`
- `src/ReplicatedStorage/Utilities/BaseInstanceFactory.lua`
- `src/ServerScriptService/Contexts/Enemy/Infrastructure/Services/EnemyInstanceFactory.lua`
5. Audit the target context for manual `Registry.new(...)`, `WrapContext(...)`, `_InitModule(...)`, lifecycle ordering, cross-context `Knit.GetService(...)`, signals, persistence loader hooks, scheduler registrations, runtime instance binding tables, direct reveal/tag stamping, and `Destroy()` cleanup.
6. Convert context-owned modules to BaseContext service-table config.
7. Convert ECS infrastructure to the appropriate BaseECS inheritance pattern.
8. Convert runtime Workspace instance services to `BaseInstanceFactory` only when they own ECS-backed runtime object lifecycle, reveal, or binding concerns.
9. Preserve public APIs and behavior; do not rename public context methods, result shapes, client methods, bindable signal names, event payloads, or persistence data shapes unless the user explicitly requests it.
10. Run targeted validation and report any validation that could not be run.

---

## BaseContext Rules

- Require `ReplicatedStorage.Utilities.BaseContext` from the context entry module.
- Replace manual `Registry.new(...)`, direct `WrapContext(...)`, custom `_InitModule(...)`, and manual registry init/start loops when BaseContext can own them.
- Declare context-owned modules in typed layer arrays: `{ BaseContext.TModuleSpec }`.
- Compose layer arrays into one `BaseContext.TModuleLayers` value.
- Pass the module config through the Knit service table as `Modules = <ContextModules>`.
- Use `WorldService` only for the context-owned ECS world service that also registers the raw `World` handle.
- Use `CacheAs` or `Cache` only for dependencies required by public methods, lifecycle handlers, event handlers, scheduler callbacks, or teardown.
- Use `ExternalServices` for sibling Knit services resolved during `KnitStart`.
- Use `ExternalDependencies` only for values returned by another service method that already returns a `Result`.
- Use `StartOrder` only when the default layer startup order would change behavior.
- Use `ProfileLifecycle` for persistence loader, load, save, remove, and backfill wiring when the existing context owns player profile lifecycle behavior.
- Use `Teardown` for connections, bindable events, cleanup methods, and service fields that `baseContext:Destroy()` should clean up.
- Create exactly one BaseContext wrapper with `BaseContext.new(<ContextService>)`.
- Delegate `KnitInit` and `KnitStart` to the wrapper before context-specific logging or post-start work.
- Keep public context methods bridge-only and Result-preserving.

---

## BaseECS Rules

- Convert `*ECSWorldService` to inherit from `BaseECSWorldService`.
- Convert `*ComponentRegistry` to inherit from `BaseECSComponentRegistry`.
- Convert `*EntityFactory` to inherit from `BaseECSEntityFactory`.
- Call `BaseECSWorldService.new("<ContextName>")`, `BaseECSComponentRegistry.new("<ContextName>")`, or `BaseECSEntityFactory.new("<ContextName>")` inside derived `.new()` methods.
- Call `BaseECSWorldService.Init(self, registry, name)` from the derived world service `Init`.
- Call `BaseECSComponentRegistry.InitBase(self, registry)` before registering components or tags.
- Register data components with `RegisterComponent(key, ecsName, "AUTHORITATIVE" | "DERIVED")`.
- Register binary markers with `RegisterTag(key, ecsName)`.
- Call `Finalize()` exactly once after component, tag, and external id registration.
- Call `BaseECSEntityFactory.InitBase(self, registry, "<ContextComponentRegistry>")` before factory methods use the world or components.
- Replace duplicated factory readiness assertions with `RequireReady()`.
- Replace duplicated query collection loops with `CollectQuery(...)` where the behavior matches.
- Replace duplicated deferred delete queues with `MarkForDestruction(...)`, `IsMarkedForDestruction(...)`, `GetDestructionQueueSize()`, and `FlushDestructionQueue()` where the behavior matches.
- Replace duplicated reveal helpers with `RegisterReveal(...)`, `RefreshReveal(...)`, `UnregisterReveal(...)`, and `HasReveal(...)` where the behavior matches.

---

## BaseInstanceFactory Rules

- Convert runtime services such as `*ModelFactory`, `*ObjectFactory`, or similar Workspace-instance owners to inherit from `BaseInstanceFactory` only when they own ECS-backed runtime object lifecycle.
- Use `BaseInstanceFactory` for asset-backed instance creation, Workspace folder ownership, entity-instance binding, and reveal lifecycle.
- Do not move JECS world reads/writes into `BaseInstanceFactory`; `*EntityFactory` remains the only JECS mutation surface.
- Keep runtime mutable projection in a sync service when the values come from ECS state and change over time.
- Implement `_GetWorkspaceFolderName()` in the derived instance factory.
- Implement `_CreateAssetRegistry(assetsRoot)` in the derived instance factory when the runtime object family is asset-backed.
- Implement `_CreateInstanceForEntity(entityId, options)` in the derived instance factory.
- Implement `_PrepareInstance(instance, entityId, options)` in the derived instance factory for family-specific model/object setup.
- Prefer `_BuildRevealIdentityOptions(...)`, `_BuildRevealAttributes(...)`, and `_BuildRevealTags(...)` over assembling raw reveal-apply logic inline.
- Let `BaseInstanceFactory` own `BuildIdentityRevealState(...)`, `MergeRevealStates(...)`, `BuildRevealState(...)`, `RegisterReveal(...)`, `RefreshReveal(...)`, `DestroyInstance(...)`, and `DestroyAll()`.
- Keep ownership explicit:
  - `*EntityFactory`: JECS entities/components/tags
  - `*InstanceFactory`: Workspace instances, binding, reveal, cleanup
  - sync service: mutable ECS-to-instance projection
- Preserve existing public service methods when migrating. If a context exposes `GetModelFactory()`, keep a compatibility bridge unless the user explicitly requests a breaking rename.

---

## Prohibitions

- Do not register cross-context Knit services in `Modules`.
- Do not resolve cross-context services in `KnitInit`.
- Do not expose the registry through public context methods.
- Do not move business logic into `Factory` callbacks.
- Do not convert an ECS helper to a base-class helper when custom behavior is not equivalent.
- Do not convert a pure placement/runtime helper to `BaseInstanceFactory` unless it actually owns ECS-backed runtime instance lifecycle.
- Do not let systems call `world:set`, `world:add`, `world:remove`, `world:delete`, or `world:query` directly.
- Do not let `BaseInstanceFactory` or derived instance factories take JECS world ownership.
- Do not split identity/discovery reveal ownership across both the instance factory and a sync service.
- Do not remove cleanup, signal, scheduler, or persistence behavior while simplifying setup.
- Do not change saved data, sync payload, or public server API contracts as part of the migration.

---

## Validation

- Search the migrated context for remaining `Registry.new`, `WrapContext`, `_InitModule`, and direct JECS mutation outside factories.
- Confirm the context entry module imports `BaseContext` and no longer imports removed setup utilities.
- Confirm all module spec layer arrays are typed as `{ BaseContext.TModuleSpec }`.
- Confirm all component registries use authority labels and call `Finalize()`.
- Confirm all entity factories call `RequireReady()` before world/component access.
- Confirm runtime instance factories do not read or mutate JECS world state.
- Confirm runtime instance factories use `AssetFetcher` registries rather than direct asset traversal where the context is asset-backed.
- Confirm reveal/tag/attribute ownership is explicit: identity/discovery in the instance factory, mutable ECS projection in the sync service when applicable.
- Run available targeted checks such as `selene`, `luau-lsp`, `stylua --check`, or project tests when present.

---

## Output Format

```markdown
Implemented the context/ECS base-class migration.

Changed:
- `<path>`: <one-line summary>

Validation:
- `<command>`: <result>

Notes:
- <residual risk or follow-up, if any>
```
