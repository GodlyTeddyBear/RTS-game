--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local StartCombatRuntimeCommand = {}
StartCombatRuntimeCommand.__index = StartCombatRuntimeCommand
setmetatable(StartCombatRuntimeCommand, BaseCommand)

function StartCombatRuntimeCommand.new()
	local self = BaseCommand.new("Combat", "StartCombatRuntime")
	return setmetatable(self, StartCombatRuntimeCommand)
end

function StartCombatRuntimeCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_behaviorRuntimeService = "CombatBehaviorRuntimeService",
	})
end

function StartCombatRuntimeCommand:Execute(_sessionPayload: any?): Result.Result<boolean>
	return Result.Catch(function()
		return self._behaviorRuntimeService:StartRuntime()
	end, self:_Label())
end

return StartCombatRuntimeCommand
