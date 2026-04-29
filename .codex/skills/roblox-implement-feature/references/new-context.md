---
name: new-context
description: Read when you need this skill reference template and workflow rules.
---

# New Context

<!-- This is a repo-local prompt template. Codex does not automatically expose this as a slash command. Prefer the matching skill when available. -->

Create a new backend bounded context named `$ARGUMENTS`.

`$ARGUMENTS` format: `<ContextName>` in PascalCase with no spaces (for example: `Fishing`, `PetTraining`).

---

## What to do

1. Read `.codex/Templates/README.md` and `.codex/Templates/backend-context.md` before creating anything.
2. Read `src/ServerScriptService/Contexts/` to verify naming and existing context patterns before creating files.
3. Read `.codex/documents/methods/backend/BASE_CONTEXT_CONTRACTS.md` and `.codex/documents/architecture/backend/ERROR_HANDLING.md` to align with BaseContext and Result boundary rules.
4. Read persistence event contracts:
   - `src/ReplicatedStorage/Events/GameEvents/Misc/Persistence.lua`
   - `src/ServerScriptService/Persistence/PlayerLifecycleManager.lua`
5. If the new context will own ECS infrastructure, also read:
   - `.codex/documents/methods/ECS/COMPONENT_RULES.md`
   - `.codex/documents/methods/ECS/ENTITY_FACTORY_RULES.md`
   - `.codex/documents/methods/ECS/WORLD_ISOLATION_RULES.md`
   - `.codex/documents/methods/ECS/SYSTEM_RULES.md`
   - `.codex/documents/methods/ECS/PHASE_AND_EXECUTION_RULES.md`
   - `.codex/documents/methods/ECS/TAG_RULES.md`
   - `.codex/documents/methods/ECS/INSTANCE_REVEAL_RULES.md`
   - `.codex/documents/methods/ECS/ECS_PERSISTENCE_RULES.md`
6. Scaffold the folder structure below using the exact naming shown.
7. Create only the boilerplate files listed below; do not create command/query/domain/infrastructure implementation files yet.
8. After creation, report every file and folder created.

---

## Folder structure to create

```text
src/ServerScriptService/Contexts/<ContextName>/
|- <ContextName>Context.lua
|- Errors.lua
|- Application/
|  |- Commands/
|  `- Queries/
|- <ContextName>Domain/
|  |- Policies/
|  |- Services/
|  |- Specs/
|  `- ValueObjects/
|- Infrastructure/
|  |- ECS/
|  |- Persistence/
|  `- Services/
`- Config/
```

Also create the shared context folders:

```text
src/ReplicatedStorage/Contexts/<ContextName>/
|- Config/
|- Types/
`- Sync/
```

---

## Rules to follow

- Use exact naming: `<ContextName>Context.lua` and service name `"<ContextName>Context"` (no spaces).
- Do not create `Application/Services/` (deprecated). Use `Application/Commands/` and `Application/Queries/`.
- Do not create `Config/DebugLogger.lua`.
- Context file is a pass-through bridge only; no business logic.
- Context files use `BaseContext.new(<ContextName>Context)` and delegate `KnitInit`/`KnitStart` to the wrapper.
- Do not call `Registry.new(...)` or `WrapContext(...)` directly in a BaseContext-backed context file.
- If the context owns ECS, also create the ECS folder and base-class modules under `Infrastructure/ECS/` and `Infrastructure/Persistence/` as needed.
- Persistence lifecycle integration rule for future context behavior:
  - On context startup, register as a loader via `PlayerLifecycleManager:RegisterLoader("<ContextName>")`.
  - Hydrate context state on `GameEvents.Events.Persistence.ProfileLoaded`.
  - Flush context state on `GameEvents.Events.Persistence.ProfileSaving`.
  - After hydration, call `PlayerLifecycleManager:NotifyLoaded(player, "<ContextName>")`.
  - Do not use `Players.PlayerAdded/PlayerRemoving` directly for profile hydration/flush responsibilities.
  - Place context sync services (atom read/write orchestration) under `Infrastructure/Persistence`, not `Infrastructure/Services`.
- Centralized types rule:
  - Create and keep shared types in `src/ReplicatedStorage/Contexts/<ContextName>/Types/<ContextName>Types.lua`.
  - Service/query/policy modules should import from that single file for context-wide data shapes.
  - Do not duplicate context-shared `export type` shapes across multiple modules.
- Result boundary rule for future methods in `<ContextName>Context.lua`:
  - Require `ReplicatedStorage.Utilities.Result` and use `Catch` for context method boundaries (or `Ok(value)` for simple getters).
  - Require `ReplicatedStorage.Utilities.BaseContext` and use `BaseContext.new(<ContextName>Context)` to wrap the service table before lifecycle methods.
  - Public server-to-server context methods should return `Result.Result<T>` and preserve propagation by return value.
  - Use `result:unwrapOr(default)` only in terminal/private boundaries where default fallback is intentional.
  - `.Client` methods that call `Execute` directly should own a `Catch`; `.Client` methods that delegate to `self.Server:Method()` should not add another `Catch`.
- ECS infrastructure should use the ECS base classes, not ad hoc world or registry setup:
  - `BaseECSWorldService` for the world owner
  - `BaseECSComponentRegistry` for component/tag registration
  - `BaseECSEntityFactory` for entity creation and queries
  - `BaseSyncService` for sync services that bridge atom state
- `Errors.lua` uses `table.freeze()` and SCREAMING_SNAKE_CASE keys.
- All created Luau files start with `--!strict`.
