--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local StopCombatRuntimeCommand = {}
StopCombatRuntimeCommand.__index = StopCombatRuntimeCommand
setmetatable(StopCombatRuntimeCommand, BaseCommand)

function StopCombatRuntimeCommand.new()
	local self = BaseCommand.new("Combat", "StopCombatRuntime")
	return setmetatable(self, StopCombatRuntimeCommand)
end

function StopCombatRuntimeCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_behaviorRuntimeService = "CombatBehaviorRuntimeService",
	})
end

function StopCombatRuntimeCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		return self._behaviorRuntimeService:StopRuntime()
	end, self:_Label())
end

return StopCombatRuntimeCommand
