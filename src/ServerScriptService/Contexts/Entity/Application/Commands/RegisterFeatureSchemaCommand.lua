--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local RegisterFeatureSchemaCommand = {}
RegisterFeatureSchemaCommand.__index = RegisterFeatureSchemaCommand
setmetatable(RegisterFeatureSchemaCommand, BaseCommand)

function RegisterFeatureSchemaCommand.new()
	local self = BaseCommand.new("Entity", "RegisterFeatureSchema")
	return setmetatable(self, RegisterFeatureSchemaCommand)
end
function RegisterFeatureSchemaCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_schemaRegistry = "EntitySchemaRegistry",
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
	})
end

function RegisterFeatureSchemaCommand:Execute(featureName: string, schema: any): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "RegisterFeatureSchema", self._lifecycle:GetState(), {
			"RegisteringECS",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._schemaRegistry:RegisterFeatureSchema(featureName, schema)
	end, self:_Label())
end

return RegisterFeatureSchemaCommand