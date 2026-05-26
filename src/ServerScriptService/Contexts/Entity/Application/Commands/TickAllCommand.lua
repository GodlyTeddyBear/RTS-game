--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local TickAllCommand = {}
TickAllCommand.__index = TickAllCommand
setmetatable(TickAllCommand, BaseCommand)

function TickAllCommand.new()
	local self = BaseCommand.new("Entity", "TickAll")
	return setmetatable(self, TickAllCommand)
end
function TickAllCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_systemRegistry = "EntitySystemRegistry",
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
	})
end

function TickAllCommand:Execute(): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "TickAll", self._lifecycle:GetState(), {
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._systemRegistry:RunAllPhases()
	end, self:_Label())
end

return TickAllCommand