--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local SetCommand = {}
SetCommand.__index = SetCommand
setmetatable(SetCommand, BaseCommand)

function SetCommand.new()
	local self = BaseCommand.new("Entity", "Set")
	return setmetatable(self, SetCommand)
end
function SetCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_entityFactory = "EntityEntityFactory",
	})
end

function SetCommand:Execute(entity: number, key: string, value: any, featureName: string?): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "Set", self._lifecycle:GetState(), {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:Set(entity, key, value, featureName)
	end, self:_Label())
end

return SetCommand
