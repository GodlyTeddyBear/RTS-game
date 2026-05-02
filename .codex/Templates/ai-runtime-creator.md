# AI Runtime Creator Template

Use this as the scaffold reference for runtime-owner contexts like `CombatContext` and `MiningContext` and their `*BehaviorRuntimeService` modules built on `BaseAIRuntimeService`.

---

## Target Shape

```text
src/ServerScriptService/Contexts/<RuntimeContextName>/
|-- <RuntimeContextName>Context.lua
`-- Infrastructure/
    `-- Services/
        |-- <RuntimeContextName>ActorRegistryService.lua
        `-- <RuntimeContextName>BehaviorRuntimeService.lua
```

---

## Runtime Owner Context Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)

local <RuntimeContextName>ActorRegistryService = require(script.Parent.Infrastructure.Services["<RuntimeContextName>ActorRegistryService"])
local <RuntimeContextName>BehaviorRuntimeService = require(script.Parent.Infrastructure.Services["<RuntimeContextName>BehaviorRuntimeService"])

local <RuntimeContextName>Context = Knit.CreateService({
	Name = "<RuntimeContextName>Context",
	Client = {},
	Modules = {
		Infrastructure = {
			{
				Name = "<RuntimeContextName>ActorRegistryService",
				Module = <RuntimeContextName>ActorRegistryService,
				CacheAs = "_actorRegistryService",
			},
			{
				Name = "<RuntimeContextName>BehaviorRuntimeService",
				Module = <RuntimeContextName>BehaviorRuntimeService,
				CacheAs = "_behaviorRuntimeService",
			},
		},
	},
	AIRuntimeContext = {
		RuntimeServiceField = "_behaviorRuntimeService",
		ActorRegistryServiceField = "_actorRegistryService",
	},
	StartOrder = { "Infrastructure" },
})

local <RuntimeContextName>BaseContext = BaseContext.new(<RuntimeContextName>Context)

function <RuntimeContextName>Context:KnitInit()
	<RuntimeContextName>BaseContext:KnitInit()
end

function <RuntimeContextName>Context:KnitStart()
	<RuntimeContextName>BaseContext:KnitStart()
	<RuntimeContextName>BaseContext:RegisterSchedulerSystem("CombatTick", function()
		self._behaviorRuntimeService:RunFrame({
			CurrentTime = os.clock(),
			DeltaTime = <RuntimeContextName>BaseContext:GetSchedulerDeltaTime(),
			Services = {
				<RuntimeContextName>ActorRegistryService = self._actorRegistryService,
			},
		})
	end)
end

return <RuntimeContextName>Context
```

---

## Behavior Runtime Service Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseAIRuntimeService = require(ReplicatedStorage.Utilities.BaseAIRuntimeService)
local Errors = require(script.Parent.Parent.Parent.Errors)
local RuntimeAdapterHook = require(script.Parent.Parent.BehaviorSystem.Hooks.<RuntimeAdapterHookModule>)

local <RuntimeContextName>BehaviorRuntimeService = {}
<RuntimeContextName>BehaviorRuntimeService.__index = <RuntimeContextName>BehaviorRuntimeService
setmetatable(<RuntimeContextName>BehaviorRuntimeService, BaseAIRuntimeService)

function <RuntimeContextName>BehaviorRuntimeService.new()
	local self = BaseAIRuntimeService.new({
		RuntimeLabel = "<RuntimeContextName>:BehaviorRuntime",
		ActorRegistryServiceName = "<RuntimeContextName>ActorRegistryService",
		BaseHooks = {
			RuntimeAdapterHook,
		},
		Errors = Errors,
	})
	return setmetatable(self, <RuntimeContextName>BehaviorRuntimeService)
end

return <RuntimeContextName>BehaviorRuntimeService
```

---

## Behavior Runtime Method Surface Example

```lua
function <RuntimeContextName>BehaviorRuntimeService:StartRuntimeIfNeeded(): Result.Result<boolean>
	if self._actorRegistryService:IsRuntimeStarted() then
		return Result.Ok(false)
	end

	return self:StartRuntime()
end

function <RuntimeContextName>BehaviorRuntimeService:BuildBehaviorTree(definition: any): Result.Result<any>
	return self:BuildTree(definition)
end

function <RuntimeContextName>BehaviorRuntimeService:StopRuntimeSafe(): Result.Result<boolean>
	return self:StopRuntime()
end
```

---

## Runtime Owner API Example (Combat-Style)

```lua
function <RuntimeContextName>Context:RegisterActorType(payload: <RuntimeActorTypePayload>): Result.Result<boolean>
	return Result.Catch(function()
		return self._registerActorTypeCommand:Execute(payload)
	end, "<RuntimeContextName>:RegisterActorType")
end

function <RuntimeContextName>Context:RegisterRuntimeActor(payload: <RuntimeActorPayload>): Result.Result<string>
	return Result.Catch(function()
		return self._registerRuntimeActorCommand:Execute(payload)
	end, "<RuntimeContextName>:RegisterRuntimeActor")
end

function <RuntimeContextName>Context:UnregisterRuntimeActor(actorHandle: string): Result.Result<boolean>
	return Result.Catch(function()
		return self._unregisterRuntimeActorCommand:Execute(actorHandle)
	end, "<RuntimeContextName>:UnregisterRuntimeActor")
end
```

---

## Runtime Owner API Example (Mining-Style)

```lua
function <RuntimeContextName>Context:RegisterActorType(payload: <RuntimeActorTypePayload>): Result.Result<boolean>
	return Result.Catch(function()
		return self._actorRegistryService:RegisterActorType(payload)
	end, "<RuntimeContextName>:RegisterActorType")
end

function <RuntimeContextName>Context:RegisterRuntimeActor(payload: <RuntimeActorPayload>): Result.Result<string>
	return Result.Catch(function()
		if not self._actorRegistryService:IsRuntimeStarted() then
			local queueResult = self._actorRegistryService:QueueActor(payload)
			if not queueResult.success then
				return queueResult
			end

			local startRuntimeResult = self._behaviorRuntimeService:StartRuntime()
			if not startRuntimeResult.success then
				return startRuntimeResult
			end

			return queueResult
		end

		local treeResult = self._behaviorRuntimeService:BuildTree(payload.BehaviorDefinition)
		if not treeResult.success then
			return treeResult
		end

		return self._actorRegistryService:RegisterActor(payload, treeResult.value)
	end, "<RuntimeContextName>:RegisterRuntimeActor")
end
```

---

## Actor Registry Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActorRegistryBase = require(ReplicatedStorage.Utilities.ActorRegistryBase)

local <RuntimeContextName>ActorRegistryService = {}
<RuntimeContextName>ActorRegistryService.__index = <RuntimeContextName>ActorRegistryService
setmetatable(<RuntimeContextName>ActorRegistryService, ActorRegistryBase)

function <RuntimeContextName>ActorRegistryService.new()
	local self = ActorRegistryBase.new()
	return setmetatable(self, <RuntimeContextName>ActorRegistryService)
end

function <RuntimeContextName>ActorRegistryService:_ValidateActorTypePayload(payload: any)
	assert(type(payload.ActorType) == "string", "ActorType required")
	assert(type(payload.Conditions) == "table", "Conditions required")
	assert(type(payload.Commands) == "table", "Commands required")
	assert(type(payload.Executors) == "table", "Executors required")
end

function <RuntimeContextName>ActorRegistryService:_ValidateActorPayload(payload: any)
	assert(type(payload.ActorType) == "string", "ActorType required")
	assert(type(payload.ActorHandle) == "string", "ActorHandle required")
	assert(type(payload.Adapter) == "table", "Adapter required")
end

function <RuntimeContextName>ActorRegistryService:_BuildStoredActorTypePayload(payload: any)
	return payload
end

function <RuntimeContextName>ActorRegistryService:_BuildRecordFromPayload(payload: any, runtimeId: number, _buildContext: any?)
	return {
		RuntimeId = runtimeId,
		ActorType = payload.ActorType,
		ActorHandle = payload.ActorHandle,
		Adapter = payload.Adapter,
		CompiledBehaviorTree = _buildContext.CompiledBehaviorTree,
		ActionState = nil,
		LastTickTime = 0,
		TickInterval = payload.TickInterval or 0.25,
	}
end

function <RuntimeContextName>ActorRegistryService:_IsRecordActive(record: any): boolean
	return record.Adapter.IsActive()
end
```

---

## Usage Notes

- Runtime-owner contexts register `AIRuntimeContext` with runtime and actor-registry fields.
- `*BehaviorRuntimeService` should subclass `BaseAIRuntimeService` instead of manually recreating runtime lifecycle logic.
- Hook names are context-specific. For example, Combat uses `ActorAdapterHook` and Mining uses `MiningActorAdapterHook`.
- Runtime-owner context APIs usually follow either command-wrapper registration (Combat-style) or direct registry/runtime orchestration (Mining-style).
- Runtime consumers (for example enemy or structure adapters) own actor-type payloads, resolvers, and profiles, then call creator-context registration APIs.
