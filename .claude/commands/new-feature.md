Create a new frontend feature slice named $ARGUMENTS.

## What to do

1. Read `src/StarterPlayerScripts/Contexts/` to understand the existing feature structure before creating anything.
2. Read the Counter feature at `src/StarterPlayerScripts/Contexts/Counter/` as the reference implementation — mirror its structure exactly.
3. Scaffold the full folder structure and all boilerplate files listed below.
4. After creating all files, report what was created.

## Folder structure to create

```
src/StarterPlayerScripts/Contexts/$ARGUMENTS/
├── Infrastructure/
│   └── $ARGUMENTS Atom.lua
├── Application/
│   ├── Hooks/
│   │   ├── use$ARGUMENTS.lua
│   │   └── use$ARGUMENTS Actions.lua
│   └── ViewModels/
│       └── $ARGUMENTS ViewModel.lua
├── Presentation/
│   ├── Organisms/
│   ├── Templates/
│   │   └── $ARGUMENTS Screen.lua
│   └── index.lua
└── Types/
```

## File contents

### `Infrastructure/$ARGUMENTS Atom.lua`
```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

export type T$ARGUMENTS State = {
    -- Define state shape here
}

local function create$ARGUMENTS Atom()
    return Charm.atom({
        -- Initialize state here
    } :: T$ARGUMENTS State)
end

return create$ARGUMENTS Atom
```

### `Application/Hooks/use$ARGUMENTS.lua`
```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local create$ARGUMENTS Atom = require(script.Parent.Parent.Parent.Infrastructure["$ARGUMENTS Atom"])

local atom = nil

local function use$ARGUMENTS()
    if atom == nil then
        atom = create$ARGUMENTS Atom()
    end
    return ReactCharm.useAtom(atom)
end

return use$ARGUMENTS
```

### `Application/Hooks/use$ARGUMENTS Actions.lua`
```lua
--!strict

-- Write hook — does NOT subscribe to atom, no re-renders triggered
local function use$ARGUMENTS Actions()
    return {
        -- Add mutation functions here
        -- Example:
        -- doSomething = function()
        --     atom({ ... })
        -- end,
    }
end

return use$ARGUMENTS Actions
```

### `Application/ViewModels/$ARGUMENTS ViewModel.lua`
```lua
--!strict

local $ARGUMENTS ViewModel = {}
$ARGUMENTS ViewModel.__index = $ARGUMENTS ViewModel

export type T$ARGUMENTS ViewData = {
    -- Define formatted/derived fields here
}

function $ARGUMENTS ViewModel.fromAtomData(atomData)
    return table.freeze({
        -- Transform atomData into display-ready values
    } :: T$ARGUMENTS ViewData)
end

return $ARGUMENTS ViewModel
```

### `Presentation/Templates/$ARGUMENTS Screen.lua`
```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local use$ARGUMENTS = require(script.Parent.Parent.Parent.Application.Hooks["use$ARGUMENTS"])
local use$ARGUMENTS Actions = require(script.Parent.Parent.Parent.Application.Hooks["use$ARGUMENTS Actions"])
local $ARGUMENTS ViewModel = require(script.Parent.Parent.Parent.Application.ViewModels["$ARGUMENTS ViewModel"])

local function $ARGUMENTS Screen()
    local state = use$ARGUMENTS()
    local actions = use$ARGUMENTS Actions()

    local viewModel = React.useMemo(function()
        return $ARGUMENTS ViewModel.fromAtomData(state)
    end, { state })

    return React.createElement("Frame", {
        Size = UDim2.fromScale(1, 1),
    }, {
        -- Add organisms here
    })
end

return $ARGUMENTS Screen
```

### `Presentation/index.lua`
```lua
--!strict

local $ARGUMENTS Screen = require(script.Templates["$ARGUMENTS Screen"])

return {
    Screen = $ARGUMENTS Screen,
}
```

## Rules to follow

- Read hook (`use$ARGUMENTS.lua`) uses `ReactCharm.useAtom()` — subscribes to state
- Write hook (`use$ARGUMENTS Actions.lua`) does NOT call `ReactCharm.useAtom()` — no subscription
- ViewModel returns a `table.freeze()`d table
- Template is the only place hooks are called and ViewModels constructed
- No business logic in Presentation components
- No cross-feature imports
