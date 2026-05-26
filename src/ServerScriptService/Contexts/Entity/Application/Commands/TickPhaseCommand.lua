--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local TickPhaseCommand = {}
TickPhaseCommand.__index = TickPhaseCommand
setmetatable(TickPhaseCommand, BaseCommand)

function TickPhaseCommand.new()
	local self = BaseCommand.new("Entity", "TickPhase")
	return setmetatable(self, TickPhaseCommand)
end
function TickPhaseCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_systemRegistry = "EntitySystemRegistry",
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
	})
end

function TickPhaseCommand:Execute(phaseName: string): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "TickPhase", self._lifecycle:GetState(), {
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._systemRegistry:RunPhase(phaseName)
	end, self:_Label())
end

return TickPhaseCommand