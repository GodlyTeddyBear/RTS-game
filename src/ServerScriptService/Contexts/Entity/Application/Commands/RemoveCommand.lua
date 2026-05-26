--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local RemoveCommand = {}
RemoveCommand.__index = RemoveCommand
setmetatable(RemoveCommand, BaseCommand)

function RemoveCommand.new()
	local self = BaseCommand.new("Entity", "Remove")
	return setmetatable(self, RemoveCommand)
end
function RemoveCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_entityFactory = "EntityEntityFactory",
	})
end

function RemoveCommand:Execute(entity: number, key: string, featureName: string?): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "Remove", self._lifecycle:GetState(), {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:Remove(entity, key, featureName)
	end, self:_Label())
end

return RemoveCommand