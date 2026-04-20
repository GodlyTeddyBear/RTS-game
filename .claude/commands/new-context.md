Create a new backend bounded context named `$ARGUMENTS`.

`$ARGUMENTS` format: `<ContextName>` in PascalCase with no spaces (for example: `Fishing`, `PetTraining`).

## What to do

1. Read `src/ServerScriptService/Contexts/` to verify naming and existing context patterns before creating files.
2. Scaffold the folder structure below using the exact naming shown.
3. Create only the boilerplate files listed below; do not create command/query/domain/infrastructure implementation files yet.
4. After creation, report every file and folder created.

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

## Rules to follow

- Use exact naming: `<ContextName>Context.lua` and service name `"<ContextName>Context"` (no spaces).
- Do not create `Application/Services/` (deprecated). Use `Application/Commands/` and `Application/Queries/`.
- Do not create `Config/DebugLogger.lua`.
- Context file is a pass-through bridge only; no business logic.
- `Errors.lua` uses `table.freeze()` and SCREAMING_SNAKE_CASE keys.
- All created Luau files start with `--!strict`.
