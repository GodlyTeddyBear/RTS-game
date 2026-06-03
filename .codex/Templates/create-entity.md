# Create Entity Variant Template

Use this checklist when adding a new `Enemy` or `Structure` entity variant inside existing contexts.

Scope constraints:
- This template is for extending `EnemyContext` and `StructureContext`.
- This template is not for creating a new bounded context.
- Keep shared runtime layers generic; keep variant policy in the owning context.

Canonical references:
- [Entity Implementation Pipeline](../documents/architecture/backend/ENTITY_IMPLEMENTATION_PIPELINE.md)
- [AI Runtime Overview](../../src/ServerScriptService/Readmes/ai.md)
- [Combat Overview](../../src/ServerScriptService/Readmes/combat.md)

---

## Ordered Checklist

### 1. Update canonical data first

- [ ] Add or extend the variant record in `ReplicatedStorage/Contexts/<Context>/Config/<Context>Config.lua`.
- [ ] Ensure the variant has a canonical runtime selector field (for example `RuntimeProfileId`).
- [ ] Add or extend shared type definitions in `ReplicatedStorage/Contexts/<Context>/Types/<Context>Types.lua`.
- [ ] Keep identity and runtime selector fields data-owned; do not derive them ad hoc in adapters.

### 2. Register runtime profile policy

- [ ] Add or extend `Infrastructure/Runtime/Profiles/<Context>RuntimeProfiles.lua`.
- [ ] Define the variant profile with `BehaviorDefinition`, `TickInterval`, and animation mapping.
- [ ] Keep fallback and animation-resolution policy in profile tables.
- [ ] Freeze profile registries and nested tables where existing context style already does so.

### 3. Add or extend resolver factories

- [ ] Add or extend `Infrastructure/Runtime/Resolvers/*Factory.lua` modules for callback/proxy construction.
- [ ] Keep target resolution, hit resolution helpers, and proxy wiring in resolvers, not inline in adapters.
- [ ] Keep resolver modules technical and context-owned; do not move them to shared runtime contexts.

### 4. Wire adapter registration paths

- [ ] Extend `Infrastructure/Services/*CombatAdapterService.lua` and, for structure extractors, `*MiningAdapterService.lua`.
- [ ] Resolve runtime profile by canonical variant selector.
- [ ] Register actor type once; register and unregister actor instances via handle-based APIs.
- [ ] Keep adapters thin: profile selection + bridge wiring + registration lifecycle.

### 5. Apply ECS changes only when needed

- [ ] Extend component registry only for new authoritative state required by the variant.
- [ ] Extend entity factory read/write methods as the only ECS mutation surface.
- [ ] Avoid direct JECS mutation outside `*EntityFactory`.
- [ ] Avoid adding duplicate state that already exists in config/profile tables.

### 6. Update sync and persistence bridges

- [ ] Extend `Infrastructure/Persistence/*GameObjectSyncService.lua` only for projection concerns.
- [ ] Resolve projected animation state through `Runtime/Profiles`, not inline `if Variant == ...` chains.
- [ ] Extend persistence bridge code only where serialized data shape truly changes.
- [ ] Keep sync and persistence layers bridge-only (no entity creation or behavior selection ownership).

### 7. Connect application lifecycle touchpoints

- [ ] Update application command/query flows that create, mutate, and remove the entity.
- [ ] Ensure create flow order is consistent: entity create -> instance bind -> sync registration -> runtime actor registration.
- [ ] Ensure remove flow unregisters runtime actors before entity deletion.
- [ ] Ensure cleanup flows remove both runtime records and live instance ownership.

### 8. Validate end-to-end behavior

- [ ] Verify variant can spawn/register without runtime-owner changes.
- [ ] Verify runtime profile drives behavior selection and animation projection.
- [ ] Verify unregister and cleanup paths execute without leaving stale actor handles.
- [ ] Verify no step implies creating a new bounded context.

---

## Do / Don't Rules

Do:
- Keep variant behavior policy in `Runtime/Profiles`.
- Keep adapters thin and resolver-driven.
- Keep shared runtime contexts generic and context-agnostic.

Don't:
- Spread `if Variant == ...` logic across adapters, sync services, and systems.
- Move context-specific profile/resolver rules into shared runtime contexts.
- Let sync or persistence services become owners of ECS lifecycle or behavior selection.

---

## Required File Touch Map

Enemy variant extension:
- Config + types: `ReplicatedStorage/Contexts/Enemy/Config`, `ReplicatedStorage/Contexts/Enemy/Types`
- Runtime policy: `ServerScriptService/Contexts/Enemy/Infrastructure/Runtime/Profiles`, `.../Resolvers`
- Runtime bridge + projection: `.../Services/EnemyCombatAdapterService.lua`, `.../Persistence/EnemyGameObjectSyncService.lua`
- ECS/application updates when needed: `.../Infrastructure/ECS`, `.../Application`

Structure variant extension:
- Config + types: `ReplicatedStorage/Contexts/Structure/Config`, `ReplicatedStorage/Contexts/Structure/Types`
- Runtime policy: `ServerScriptService/Contexts/Structure/Infrastructure/Runtime/Profiles`, `.../Resolvers`
- Runtime bridges + projection: `.../Services/StructureCombatAdapterService.lua`, `.../Services/StructureMiningAdapterService.lua`, `.../Persistence/StructureGameObjectSyncService.lua`
- ECS/application updates when needed: `.../Infrastructure/ECS`, `.../Application`
