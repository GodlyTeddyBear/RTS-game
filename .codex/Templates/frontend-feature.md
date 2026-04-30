# Frontend Feature Template

Use this as the scaffold reference for a new frontend feature slice named `$ARGUMENTS`.

If `$ARGUMENTS` is empty, stop and ask for the feature name.

---

## Target Shape

```text
src/StarterPlayerScripts/Contexts/<FeatureName>/
|-- <FeatureName>Controller.lua
|-- Application/
|   |-- Hooks/
|   `-- ViewModels/
|-- Config/
|-- Infrastructure/
|   |-- Persistence/
|   `-- Services/
`-- Presentation/
    |-- Atoms/
    |-- Layouts/
    |-- Molecules/
    |-- Organisms/
    |-- Screens/
    `-- Templates/

src/ReplicatedStorage/Contexts/<FeatureName>/
|-- Config/
|-- Sync/
`-- Types/
    `-- <FeatureName>Types.lua
```

---

## Controller Example

```lua
--!strict

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

local <FeatureName>Controller = Knit.CreateController({
	Name = "<FeatureName>Controller",
})

function <FeatureName>Controller:KnitInit()
	self._syncClient = require(script.Parent.Infrastructure.Persistence["<FeatureName>SyncClient"]).new()
end

function <FeatureName>Controller:KnitStart()
	self._syncClient:Start()
end

function <FeatureName>Controller:GetAtom()
	return self._syncClient:GetAtom()
end

return <FeatureName>Controller
```

---

## Sync Client Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts["<FeatureName>"].Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated["<FeatureName>SyncClient"])

local <FeatureName>SyncClient = {}
<FeatureName>SyncClient.__index = <FeatureName>SyncClient
setmetatable(<FeatureName>SyncClient, BaseSyncClient)

function <FeatureName>SyncClient.new()
	local self = BaseSyncClient.new(BlinkClient, "Sync<FeatureName>", "<featureName>", SharedAtoms.CreateClientAtom)
	return setmetatable(self, <FeatureName>SyncClient)
end

function <FeatureName>SyncClient:Start()
	BaseSyncClient.Start(self)
end

function <FeatureName>SyncClient:GetAtom()
	return BaseSyncClient.GetAtom(self)
end

return <FeatureName>SyncClient
```

---

## Hook Example

```lua
--!strict

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

local function use<FeatureName>()
	local controller = Knit.GetController("<FeatureName>Controller")
	return controller:GetAtom()
end

return use<FeatureName>
```

---

## ViewModel Example

```lua
--!strict

local function create<FeatureName>ViewModel(atomState: any)
	return {
		title = "<FeatureName>",
		value = atomState,
	}
end

return create<FeatureName>ViewModel
```

---

## Presentation Template Example

```lua
--!strict

local React = require(game:GetService("ReplicatedStorage").Packages.React)

local use<FeatureName> = require(script.Parent.Parent.Application.Hooks["use<FeatureName>"])
local create<FeatureName>ViewModel = require(script.Parent.Parent.Application.ViewModels["create<FeatureName>ViewModel"])

local function <FeatureName>Template()
	local atomState = use<FeatureName>()
	local viewModel = create<FeatureName>ViewModel(atomState)

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Title = React.createElement("TextLabel", {
			Size = UDim2.fromOffset(200, 40),
			Text = viewModel.title,
		}),
	})
end

return <FeatureName>Template
```

---

## Presentation Screen Example

```lua
--!strict

local React = require(game:GetService("ReplicatedStorage").Packages.React)

local function <FeatureName>Screen()
	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})
end

return <FeatureName>Screen
```

---

## Shared Types Example

```lua
--!strict

local <FeatureName>Types = {}

export type ExampleState = {
	Enabled: boolean,
	Label: string,
}

return table.freeze(<FeatureName>Types)
```
