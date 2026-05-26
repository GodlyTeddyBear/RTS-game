--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local AddCommand = {}
AddCommand.__index = AddCommand
setmetatable(AddCommand, BaseCommand)

function AddCommand.new()
	local self = BaseCommand.new("Entity", "Add")
	return setmetatable(self, AddCommand)
end
function AddCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_entityFactory = "EntityEntityFactory",
	})
end

function AddCommand:Execute(entity: number, key: string, featureName: string?): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "Add", self._lifecycle:GetState(), {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:Add(entity, key, featureName)
	end, self:_Label())
end

return AddCommand