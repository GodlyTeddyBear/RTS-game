# AI Runtime Consumer Context Template

Use this as the scaffold reference for consumer contexts like `EnemyContext` and `StructureContext` that do not create the runtime directly and instead register actor types and actors through adapter services.

---

## Target Shape

```text
src/ServerScriptService/Contexts/<ConsumerContextName>/
|-- <ConsumerContextName>Context.lua
`-- Infrastructure/
    |-- Services/
    |   `-- <ConsumerContextName><RuntimeOwnerName>AdapterService.lua
    `-- Runtime/
        |-- Profiles/
        |   `-- <ConsumerContextName>RuntimeProfiles.lua
        `-- Resolvers/
            |-- <ConsumerContextName>FactsResolverFactory.lua
            |-- <ConsumerContextName>TargetingResolverFactory.lua
            `-- <ConsumerContextName>...ResolverFactory.lua
```

---

## Consumer Context Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local <ConsumerContextName><RuntimeOwnerName>AdapterService = require(script.Parent.Infrastructure.Services["<ConsumerContextName><RuntimeOwnerName>AdapterService"])

local <ConsumerContextName>Context = Knit.CreateService({
	Name = "<ConsumerContextName>Context",
	Client = {},
	Modules = {
		Infrastructure = {
			{
				Name = "<ConsumerContextName><RuntimeOwnerName>AdapterService",
				Module = <ConsumerContextName><RuntimeOwnerName>AdapterService,
				CacheAs = "_runtimeAdapterService",
			},
		},
	},
	ExternalServices = {
		{ Name = "<RuntimeOwnerName>Context" },
	},
})

local <ConsumerContextName>BaseContext = BaseContext.new(<ConsumerContextName>Context)

function <ConsumerContextName>Context:KnitInit()
	<ConsumerContextName>BaseContext:KnitInit()
end

function <ConsumerContextName>Context:KnitStart()
	<ConsumerContextName>BaseContext:KnitStart()
	self._runtimeAdapterService:ConfigureRuntimeOwner(self)

	local registerActorTypeResult = self._runtimeAdapterService:RegisterActorType()
	if not registerActorTypeResult.success then
		Result.MentionError("<ConsumerContextName>:KnitStart", "Failed to register runtime actor type", {
			CauseType = registerActorTypeResult.type,
			CauseMessage = registerActorTypeResult.message,
			Details = registerActorTypeResult.data,
		}, registerActorTypeResult.type)
		error("<ConsumerContextName>Context failed to register runtime actor type")
	end
end

return <ConsumerContextName>Context
```

---

## Adapter Service Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local Result = require(ReplicatedStorage.Utilities.Result)
local Nodes = require(script.Parent.Parent.BehaviorSystem.Nodes)
local Executors = require(script.Parent.Parent.BehaviorSystem.Executors)
local RuntimeProfiles = require(script.Parent.Parent.Runtime.Profiles["<ConsumerContextName>RuntimeProfiles"])
local FactsResolverFactory = require(script.Parent.Parent.Runtime.Resolvers["<ConsumerContextName>FactsResolverFactory"])

local <ConsumerContextName><RuntimeOwnerName>AdapterService = {}
<ConsumerContextName><RuntimeOwnerName>AdapterService.__index = <ConsumerContextName><RuntimeOwnerName>AdapterService

local SemanticRequirements = table.freeze({
	FactsDependOnPolling = true,
	AttributesDependOnProjection = true,
})

local RuntimeBinding = table.freeze({
	ServiceField = "_syncService",
	PollPhase = "<ConsumerSyncPhase>",
	SyncPhase = "<ConsumerSyncPhase>",
})

function <ConsumerContextName><RuntimeOwnerName>AdapterService.new()
	local self = setmetatable({}, <ConsumerContextName><RuntimeOwnerName>AdapterService)
	self._runtimeOwner = nil
	return self
end

function <ConsumerContextName><RuntimeOwnerName>AdapterService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("<ConsumerContextName>EntityFactory")
end

function <ConsumerContextName><RuntimeOwnerName>AdapterService:Start(registry: any, _name: string)
	self._runtimeOwnerContext = registry:Get("<RuntimeOwnerName>Context")
	self._factsResolver = FactsResolverFactory.Create({
		<ConsumerContextName>EntityFactory = self._entityFactory,
	})
end

function <ConsumerContextName><RuntimeOwnerName>AdapterService:ConfigureRuntimeOwner(runtimeOwner: any)
	self._runtimeOwner = runtimeOwner
end

function <ConsumerContextName><RuntimeOwnerName>AdapterService:RegisterActorType(): Result.Result<boolean>
	return Result.Catch(function()
		AI.ValidateSemanticContract("<ActorType>", SemanticRequirements, RuntimeBinding, {
			RuntimeOwner = self._runtimeOwner,
		})

		return self._runtimeOwnerContext:RegisterActorType({
			ActorType = "<ActorType>",
			Conditions = Nodes.Conditions,
			Commands = Nodes.Commands,
			Executors = Executors,
			SemanticRequirements = SemanticRequirements,
			RuntimeBinding = RuntimeBinding,
			RuntimeOwner = self._runtimeOwner,
		})
	end, "<ConsumerContextName>:RegisterActorType")
end

function <ConsumerContextName><RuntimeOwnerName>AdapterService:RegisterActor(entity: number): Result.Result<string>
	return Result.Catch(function()
		local runtimeProfile = RuntimeProfiles.GetByVariant("<VariantId>")

		return self._runtimeOwnerContext:Register<RuntimeOwnerName>Actor({
			ActorType = "<ActorType>",
			ActorHandle = "<ActorType>:" .. tostring(entity),
			BehaviorDefinition = runtimeProfile.BehaviorDefinition,
			TickInterval = runtimeProfile.TickInterval,
			Adapter = {
				IsActive = function(): boolean
					return self._entityFactory:IsActive(entity)
				end,
				BuildFacts = function(currentTime: number): { [string]: any }
					return self._factsResolver.BuildFacts(entity, currentTime)
				end,
				BuildServices = function(currentTime: number): { [string]: any }
					return {
						CurrentTime = currentTime,
					}
				end,
			},
		})
	end, "<ConsumerContextName>:RegisterActor")
end

return <ConsumerContextName><RuntimeOwnerName>AdapterService
```

---

## Runtime Profiles Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseRuntimeProfileModule = require(ReplicatedStorage.Utilities.BaseRuntimeProfileModule)
local <ConsumerContextName>Config = require(ReplicatedStorage.Contexts.<ConsumerContextName>.Config.<ConsumerContextName>Config)
local <ConsumerContextName>Types = require(ReplicatedStorage.Contexts.<ConsumerContextName>.Types.<ConsumerContextName>Types)
local <ConsumerContextName>RuntimeProfiles = {}

type TIdentityType = <ConsumerContextName>Types.<IdentityType>
type TConfigRecord = <ConsumerContextName>Types.<ConfigRecordType>

local PrimaryAnimationMap = {
	["<Action.Id>"] = {
		Running = "<ActionAnimation>",
		Committed = "<ActionAnimation>",
	},
}

local PrimaryLoopingMap = {
	Idle = true,
	<ActionAnimation> = false,
}

local function _ResolveVariantIdFromIdentity(identityType: TIdentityType?): string?
	if type(identityType) ~= "string" then
		return nil
	end

	local configRecord = <ConsumerContextName>Config.<CONFIG_TABLE>[identityType] :: TConfigRecord?
	assert(
		configRecord ~= nil,
		("<ConsumerContextName>RuntimeProfiles: missing config for identity type '%s'"):format(tostring(identityType))
	)
	return configRecord.RuntimeProfileId
end

local BaseProfiles = BaseRuntimeProfileModule.new({
	Label = "<ConsumerContextName>RuntimeProfiles",
	ProfilesByVariant = {
		Default = BaseRuntimeProfileModule.CreateProfile({
			VariantId = "Default",
			BehaviorDefinition = require(script.Parent.Parent.Parent.BehaviorSystem.Behaviors.DefaultBehavior),
			DefaultAnimationState = "Idle",
			AnimationByActionIdAndState = PrimaryAnimationMap,
			LoopingByAnimationState = PrimaryLoopingMap,
			TickInterval = 0.25,
		}),
		Secondary = BaseRuntimeProfileModule.CreateProfile({
			VariantId = "Secondary",
			BehaviorDefinition = require(script.Parent.Parent.Parent.BehaviorSystem.Behaviors.SecondaryBehavior),
			DefaultAnimationState = "Idle",
			AnimationByActionIdAndState = PrimaryAnimationMap,
			LoopingByAnimationState = PrimaryLoopingMap,
			TickInterval = 0.25,
		}),
	},
	ResolveVariantId = function(input: {
		VariantId: string?,
		IdentityType: TIdentityType?,
		CombatAction: any,
	}): string?
		if type(input.VariantId) == "string" and input.VariantId ~= "" then
			return input.VariantId
		end
		return _ResolveVariantIdFromIdentity(input.IdentityType)
	end,
})

function <ConsumerContextName>RuntimeProfiles.GetByVariant(variantId: string)
	return BaseProfiles:GetByVariant(variantId)
end

function <ConsumerContextName>RuntimeProfiles.ResolveAnimationState(input: {
	VariantId: string?,
	IdentityType: TIdentityType?,
	CombatAction: any,
}): (string, boolean)
	return BaseProfiles:ResolveAnimationState(input)
end

return table.freeze(<ConsumerContextName>RuntimeProfiles)
```

---

## Resolver Factory Example

```lua
--!strict

local <ConsumerContextName>FactsResolverFactory = {}

function <ConsumerContextName>FactsResolverFactory.Create(deps: any)
	local entityFactory = deps.<ConsumerContextName>EntityFactory

	return table.freeze({
		BuildFacts = function(entity: number, currentTime: number): { [string]: any }
			return {
				Entity = entity,
				CurrentTime = currentTime,
				Identity = entityFactory:GetIdentity(entity),
				Position = entityFactory:GetPosition(entity),
			}
		end,
	})
end

return table.freeze(<ConsumerContextName>FactsResolverFactory)
```

---

## Adapter Service Function Coverage

```lua
function <ConsumerContextName><RuntimeOwnerName>AdapterService:ShouldRegisterActor(entity: number): boolean
	return self._entityFactory:IsActive(entity)
end

function <ConsumerContextName><RuntimeOwnerName>AdapterService:GetActorHandle(entity: number): string
	return "<ActorType>:" .. tostring(entity)
end

function <ConsumerContextName><RuntimeOwnerName>AdapterService:UnregisterActor(entity: number): Result.Result<boolean>
	return self._runtimeOwnerContext:Unregister<RuntimeOwnerName>Actor(self:GetActorHandle(entity))
end
```

---

## Consumer Ownership Notes

- Consumer contexts own adapter services, resolver factories, runtime profiles, and actor registration timing.
- Runtime-owner contexts (`Combat`, `Mining`) own runtime start and frame execution.
- For mixed contexts like `Structure`, keep one adapter service per runtime owner (`StructureCombatAdapterService`, `StructureMiningAdapterService`).
