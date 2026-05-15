--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseAIRuntimeService = require(ReplicatedStorage.Utilities.BaseAIRuntimeService)
local Errors = require(script.Parent.Parent.Parent.Errors)
local ActorAdapterHook = require(script.Parent.Parent.BehaviorSystem.Hooks.ActorAdapterHook)

--[=[
	@class CombatBehaviorRuntimeService
	Builds and runs the shared AI runtime used by combat actors.
	@server
]=]
local CombatBehaviorRuntimeService = {}
CombatBehaviorRuntimeService.__index = CombatBehaviorRuntimeService
setmetatable(CombatBehaviorRuntimeService, BaseAIRuntimeService)

--[=[
	@within CombatBehaviorRuntimeService
	Creates a new runtime service with no active AI runtime.
	@return CombatBehaviorRuntimeService -- Service instance used to manage combat AI runtime state.
]=]
function CombatBehaviorRuntimeService.new()
	local self = BaseAIRuntimeService.new({
		RuntimeLabel = "Combat:BehaviorRuntime",
		ActorRegistryServiceName = "CombatActorRegistryService",
		BaseHooks = {
			ActorAdapterHook,
		},
		Errors = Errors,
		UseDirectCombatHookPath = true,
		UseCachedActiveEntityProvider = true,
	})
	return setmetatable(self, CombatBehaviorRuntimeService)
end

return CombatBehaviorRuntimeService
