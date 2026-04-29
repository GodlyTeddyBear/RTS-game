---
name: new-service
description: Read when you need this skill reference template and workflow rules.
---

# New Service

<!-- This is a repo-local prompt template. Codex does not automatically expose this as a slash command. Prefer the matching skill when available. -->

Add a new backend module to an existing bounded context.

`$ARGUMENTS` format: `<ContextName> <Kind> <Name>`

- `<ContextName>`: existing context name in PascalCase (for example: `Worker`, `World`)
- `<Kind>`: one of `ApplicationCommand`, `ApplicationQuery`, `DomainPolicy`, `DomainService`, `DomainSpecs`, `DomainValueObject`, `InfrastructureService`, `InfrastructurePersistence`, `InfrastructureECS`
- `<Name>`: module name in PascalCase (for example: `HireWorker`, `FindAvailableLots`, `AssignRolePolicy`)

---

## What to do

1. Read `.codex/Templates/README.md` and the matching template before creating anything.
2. Read `src/ServerScriptService/Contexts/<ContextName>/` and `<ContextName>Context.lua` before creating anything.
3. Read `src/ServerScriptService/Contexts/<ContextName>/Errors.lua` and reuse existing error constants.
4. Read `src/ReplicatedStorage/Contexts/<ContextName>/Types/<ContextName>Types.lua` and reuse existing context-shared types.
5. Read persistence lifecycle contracts:
   - `src/ReplicatedStorage/Events/GameEvents/Misc/Persistence.lua`
   - `src/ServerScriptService/Persistence/PlayerLifecycleManager.lua`
6. Read `.codex/documents/methods/backend/BASE_APPLICATION_CONTRACTS.md` and `.codex/documents/architecture/backend/ERROR_HANDLING.md` and follow their BaseApplication/Result contracts for the selected layer.
7. Create exactly one module at the target path for the selected `<Kind>`.
8. If a new context-shared shape is needed, add it to `src/ReplicatedStorage/Contexts/<ContextName>/Types/<ContextName>Types.lua` instead of defining it locally across multiple files.
9. Wire it in `'<ContextName>Context.lua'` when required (require + registry register + cached reference if used).
10. Report what was created and what wiring was added.

---

## Paths by kind

- `ApplicationCommand` -> `src/ServerScriptService/Contexts/<ContextName>/Application/Commands/<Name>.lua`
- `ApplicationQuery` -> `src/ServerScriptService/Contexts/<ContextName>/Application/Queries/<Name>.lua`
- `DomainPolicy` -> `src/ServerScriptService/Contexts/<ContextName>/<ContextName>Domain/Policies/<Name>.lua`
- `DomainService` -> `src/ServerScriptService/Contexts/<ContextName>/<ContextName>Domain/Services/<Name>.lua`
- `DomainSpecs` -> `src/ServerScriptService/Contexts/<ContextName>/<ContextName>Domain/Specs/<Name>.lua`
- `DomainValueObject` -> `src/ServerScriptService/Contexts/<ContextName>/<ContextName>Domain/ValueObjects/<Name>.lua`
- `InfrastructureService` -> `src/ServerScriptService/Contexts/<ContextName>/Infrastructure/Services/<Name>.lua`
- `InfrastructurePersistence` -> `src/ServerScriptService/Contexts/<ContextName>/Infrastructure/Persistence/<Name>.lua`
- `InfrastructureECS` -> `src/ServerScriptService/Contexts/<ContextName>/Infrastructure/ECS/<Name>.lua`
- **Any `*SyncService` must use `InfrastructurePersistence` and live under `Infrastructure/Persistence/` (never `Infrastructure/Services/`).**
- ECS infrastructure modules should prefer the ECS base classes:
  - `BaseECSWorldService` for world ownership
  - `BaseECSComponentRegistry` for component/tag registration
  - `BaseECSEntityFactory` for entity mutation and queries
  - `BaseSyncService` for atom-backed sync services that bridge ECS state
- Shared utilities should still be preferred for reusable technical work inside ECS and non-ECS modules:
  - `SpatialQuery` for raycasts, overlap checks, range checks, visibility, and target picking
  - `PlacementPlus` for placement previews, snapping, footprints, ground alignment, and placement validation
  - `ModelPlus` for model pivots, bounds, movement, alignment, and model traversal

---

## Boilerplate by kind

### Result Contract By Kind

- `ApplicationCommand`: must require `Result`, return `Result.Result<T>` from `Execute`, and use `Ensure` + `Try` for guard/propagation.
- `ApplicationQuery`: must require `Result`, return `Result.Result<T>` from `Execute`, and use inline `Ensure` guards. Queries never require Domain.
- `DomainPolicy`: must require `Result`, return `Result.Result<T>` from `Check`, and use `Try(spec:IsSatisfiedBy(candidate))` for command-invoked policy checks.
- `DomainService`: default to Result-returning shape (`Result.Result<T>`) so validators can use `TryAll` and callers can use `Try`.
- `InfrastructureService` / `InfrastructurePersistence` / `InfrastructureECS`: use `Result` for genuinely fallible runtime boundaries (`fromPcall`, `fromNilable`); use plain Lua returns for safe in-memory reads where `nil` is valid.

### Type Contract

- Context-shared data shapes must live in `src/ReplicatedStorage/Contexts/<ContextName>/Types/<ContextName>Types.lua`.
- New modules should import that file, then alias needed types locally.
- Keep module-private helper types local only when they are truly internal implementation details.

### Persistence Event Contract

- Context persistence behavior is driven by `GameEvents.Events.Persistence` (`ProfileLoaded`, `ProfileSaving`, `PlayerReady`).
- `InfrastructurePersistence` modules should expose explicit load/save methods that context handlers call from those event hooks.
- Do not implement profile hydration/save flows by directly binding persistence logic to `Players.PlayerAdded/PlayerRemoving` inside feature modules.
- Sync services that own atom mutation/read APIs are persistence infrastructure and must be placed in `Infrastructure/Persistence`.

### Rules

- Commands and queries must respect `Result` contracts and layer boundaries.
- Queries must not depend on Domain modules.
- Commands may depend on Domain and Infrastructure.
- Domain services are pure and must not require Knit, JECS, ProfileStore, Charm, or Roblox instance APIs for side effects.
- Infrastructure is the only layer that mutates sync state.
- Keep context methods as pass-through bridges; no business logic in `<ContextName>Context.lua`.
- Reuse `Errors.lua` constants; do not add inline error strings.
- Do not create `Application/Services/`.
- Keep context-shared type definitions centralized in `<ContextName>Types.lua`.

---

## Output

- Report the file created.
- Report any context wiring added.
- Report any shared type additions.
