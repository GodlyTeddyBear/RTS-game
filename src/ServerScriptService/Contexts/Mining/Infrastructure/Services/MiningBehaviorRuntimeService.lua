--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseAIRuntimeService = require(ServerStorage.Utilities.ContextUtilities.BaseAIRuntimeService)
local Errors = require(script.Parent.Parent.Parent.Errors)
local MiningActorAdapterHook = require(script.Parent.Parent.BehaviorSystem.Hooks.MiningActorAdapterHook)

local MiningBehaviorRuntimeService = {}
MiningBehaviorRuntimeService.__index = MiningBehaviorRuntimeService
setmetatable(MiningBehaviorRuntimeService, BaseAIRuntimeService)

function MiningBehaviorRuntimeService.new()
	local self = BaseAIRuntimeService.new({
		RuntimeLabel = "Mining:BehaviorRuntime",
		ActorRegistryServiceName = "MiningActorRegistryService",
		BaseHooks = {
			MiningActorAdapterHook,
		},
		Errors = Errors,
	})
	return setmetatable(self, MiningBehaviorRuntimeService)
end

return MiningBehaviorRuntimeService
