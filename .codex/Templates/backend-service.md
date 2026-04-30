# Backend Service Template

Use this as the scaffold reference for a new backend module inside an existing bounded context.

`$ARGUMENTS` format: `<ContextName> <Kind> <Name>`

If `$ARGUMENTS` is empty, stop and ask for the context name, kind, and module name.

---

## Target Shape

```text
src/ServerScriptService/Contexts/<ContextName>/
|-- Application/
|   |-- Commands/<Name>.lua
|   `-- Queries/<Name>.lua
|-- <ContextName>Domain/
|   |-- Policies/<Name>.lua
|   `-- Specs/<Name>.lua
`-- Infrastructure/
    |-- ECS/<Name>.lua
    |-- Persistence/<Name>.lua
    `-- Services/<Name>.lua
```

---

## Application Command Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok
local Try = Result.Try

local <Name> = {}
<Name>.__index = <Name>
setmetatable(<Name>, BaseCommand)

function <Name>.new()
	local self = BaseCommand.new("<ContextName>", "<Name>")
	return setmetatable(self, <Name>)
end

function <Name>:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_policy = "<ContextName>Policy",
		_entityFactory = "<ContextName>EntityFactory",
	})
end

function <Name>:Execute(input: string): Result.Result<boolean>
	return Result.Catch(function()
		Try(self._policy:Check(input))
		self._entityFactory:DoSomething(input)
		return Ok(true)
	end, self:_Label())
end

return <Name>
```

---

## Application Query Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)

local Ok = Result.Ok

local <Name> = {}
<Name>.__index = <Name>
setmetatable(<Name>, BaseQuery)

function <Name>.new()
	local self = BaseQuery.new("<ContextName>", "<Name>")
	return setmetatable(self, <Name>)
end

function <Name>:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_entityFactory", "<ContextName>EntityFactory")
end

function <Name>:Execute(): Result.Result<number>
	return Ok(self._entityFactory:GetCount())
end

return <Name>
```

---

## Domain Policy Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local <ContextName>Specs = require(script.Parent.Parent.Specs["<ContextName>Specs"])
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err

local <Name> = {}
<Name>.__index = <Name>

function <Name>.new()
	return setmetatable({}, <Name>)
end

function <Name>:Check(input: string): Result.Result<boolean>
	if not <ContextName>Specs.IsValidInput(input) then
		return Err("InvalidInput", Errors.INVALID_INPUT, { Input = input })
	end

	return Ok(true)
end

return <Name>
```

---

## Domain Spec Example

```lua
--!strict

local <Name> = {}

function <Name>.IsValidInput(input: string): boolean
	return type(input) == "string" and input ~= ""
end

return table.freeze(<Name>)
```

---

## Infrastructure ECS World Service Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseECSWorldService = require(ReplicatedStorage.Utilities.BaseECSWorldService)

local <Name> = {}
<Name>.__index = <Name>
setmetatable(<Name>, BaseECSWorldService)

function <Name>.new()
	return setmetatable(BaseECSWorldService.new("<ContextName>"), <Name>)
end

function <Name>:ResetWorld()
	self:Reset()
end

function <Name>:GetWorld()
	return BaseECSWorldService.GetWorld(self)
end

return <Name>
```

---

## Infrastructure ECS Component Registry Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseECSComponentRegistry = require(ReplicatedStorage.Utilities.BaseECSComponentRegistry)

local <Name> = {}
<Name>.__index = <Name>
setmetatable(<Name>, BaseECSComponentRegistry)

function <Name>.new()
	return setmetatable(BaseECSComponentRegistry.new("<ContextName>"), <Name>)
end

function <Name>:_RegisterComponents(_registry: any, _name: string)
	self:RegisterComponent("<ContextName>StateComponent", "<ContextName>.State", "AUTHORITATIVE")
	self:RegisterComponent("<ContextName>ValueComponent", "<ContextName>.Value", "DERIVED")
	self:RegisterTag("<ContextName>ReadyTag", "<ContextName>.ReadyTag")
end

function <Name>:_ValidateRegistry()
	self:ValidateKeyAndNameConventions()
end

function <Name>:GetComponents()
	return BaseECSComponentRegistry.GetComponents(self)
end

function <Name>:GetRegistryMetadata()
	return BaseECSComponentRegistry.GetRegistryMetadata(self)
end

return <Name>
```

---

## Infrastructure ECS Entity Factory Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseECSEntityFactory = require(ReplicatedStorage.Utilities.BaseECSEntityFactory)

local <Name> = {}
<Name>.__index = <Name>
setmetatable(<Name>, BaseECSEntityFactory)

function <Name>.new()
	return setmetatable(BaseECSEntityFactory.new("<ContextName>"), <Name>)
end

function <Name>:_GetComponentRegistryName(): string
	return "<ContextName>ComponentRegistry"
end

function <Name>:CreateThing(): number
	self:RequireReady()
	local entity = self:_CreateEntity()
	self:_Set(entity, self._components["<ContextName>StateComponent"], {
		Value = true,
	})
	self:_Set(entity, self._components["<ContextName>ValueComponent"], {
		Value = 1,
	})
	self:_Add(entity, self._components["<ContextName>ReadyTag"])
	return entity
end

function <Name>:SetThingValue(entity: number, value: number)
	self:RequireReady()
	self:_Set(entity, self._components["<ContextName>ValueComponent"], {
		Value = value,
	})
end

function <Name>:GetThingValue(entity: number)
	self:RequireReady()
	return self:_Get(entity, self._components["<ContextName>ValueComponent"])
end

function <Name>:QueryThings(): { number }
	self:RequireReady()
	return self:CollectQuery(self._components["<ContextName>ReadyTag"])
end

function <Name>:DeleteThing(entity: number)
	self:MarkForDestruction(entity)
	self:FlushDestructionQueue()
end

return <Name>
```

---

## Infrastructure Service Example

```lua
--!strict

local <Name> = {}
<Name>.__index = <Name>

function <Name>.new()
	return setmetatable({}, <Name>)
end

function <Name>:Start()
	-- wire up reusable technical behavior here
end

return <Name>
```

---

## Infrastructure Instance Factory Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseInstanceFactory = require(ReplicatedStorage.Utilities.BaseInstanceFactory)

local <Name> = {}
<Name>.__index = <Name>
setmetatable(<Name>, BaseInstanceFactory)

function <Name>.new()
	return setmetatable(BaseInstanceFactory.new("<ContextName>"), <Name>)
end

function <Name>:_GetWorkspaceFolderName(): string
	return "<ContextName>"
end

function <Name>:_CreateInstanceForEntity(_entityId: number, _options: any): Instance
	local model = Instance.new("Model")
	model.Name = "<ContextName>Object"
	return model
end

function <Name>:_BuildRevealIdentityOptions(entityId: number, _instance: Instance, _options: any)
	return {
		EntityType = "<ContextName>",
		SourceId = tostring(entityId),
		ScopeId = "<ContextName>",
	}
end

function <Name>:_BuildRevealAttributes(_entityId: number, _instance: Instance, _options: any)
	return {
		Example = true,
	}
end

function <Name>:_BuildRevealTags(_entityId: number, _instance: Instance, _options: any)
	return {
		["<ContextName>ReadyTag"] = true,
	}
end

function <Name>:CreateThingInstance(entityId: number, options: any): Model
	return self:_CreateBoundInstance(entityId, options)
end

function <Name>:RefreshThingInstance(entityId: number)
	return self:RefreshReveal(entityId)
end

function <Name>:DestroyThingInstance(entityId: number)
	self:DestroyInstance(entityId)
end

return <Name>
```
