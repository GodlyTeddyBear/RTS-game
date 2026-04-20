Create a new backend bounded context named `$ARGUMENTS`.

`$ARGUMENTS` format: `<ContextName>` in PascalCase with no spaces (for example: `Fishing`, `PetTraining`).

## What to do

1. Read `src/ServerScriptService/Contexts/` to verify naming and existing context patterns before creating files.
2. Read `.claude/documents/architecture/backend/ERROR_HANDLING.md` to align with Result + WrapContext context-boundary rules.
3. Read persistence event contracts:
   - `src/ReplicatedStorage/Events/GameEvents/Misc/Persistence.lua`
   - `src/ServerScriptService/Persistence/PlayerLifecycleManager.lua`
4. Scaffold the folder structure below using the exact naming shown.
5. Create only the boilerplate files listed below; do not create command/query/domain/infrastructure implementation files yet.
6. After creation, report every file and folder created.

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

## File contents

### `<ContextName>Context.lua`

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local <ContextName>Context = Knit.CreateService({
    Name = "<ContextName>Context",
    Client = {},
})

function <ContextName>Context:KnitInit()
end

function <ContextName>Context:KnitStart()
end

return <ContextName>Context
```

### `Errors.lua`

```lua
--!strict

return table.freeze({
    -- Add SCREAMING_SNAKE_CASE error constants as features are added
    -- Example: INVALID_REQUEST = "Request is invalid",
})
```

### `src/ReplicatedStorage/Contexts/<ContextName>/Types/<ContextName>Types.lua`

```lua
--!strict

--[=[
	@class <ContextName>Types
	Defines shared types for the <ContextName> context.
]=]
local <ContextName>Types = {}

-- Add `export type ...` declarations here as the context grows.
-- Keep context-shared DTO/shape types centralized in this file.

return table.freeze(<ContextName>Types)
```

## Rules to follow

- Use exact naming: `<ContextName>Context.lua` and service name `"<ContextName>Context"` (no spaces).
- Do not create `Application/Services/` (deprecated). Use `Application/Commands/` and `Application/Queries/`.
- Do not create `Config/DebugLogger.lua`.
- Context file is a pass-through bridge only; no business logic.
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
  - Require `ReplicatedStorage.Utilities.WrapContext` and call `WrapContext(<ContextName>Context, "<ContextName>")` at the end of the file before returning.
  - Public server-to-server context methods should return `Result.Result<T>` and preserve propagation by return value.
  - Use `result:unwrapOr(default)` only in terminal/private boundaries where default fallback is intentional.
  - `.Client` methods that call `Execute` directly should own a `Catch`; `.Client` methods that delegate to `self.Server:Method()` should not add another `Catch`.
- `Errors.lua` uses `table.freeze()` and SCREAMING_SNAKE_CASE keys.
- All created Luau files start with `--!strict`.
