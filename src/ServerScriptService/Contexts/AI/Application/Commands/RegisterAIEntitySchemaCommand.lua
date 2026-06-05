--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)

local AIEntitySchema = require(script.Parent.Parent.Parent.Infrastructure.ECS.AIEntitySchema)
local Errors = require(script.Parent.Parent.Parent.Errors)

local RegisterAIEntitySchemaCommand = {}
RegisterAIEntitySchemaCommand.__index = RegisterAIEntitySchemaCommand
setmetatable(RegisterAIEntitySchemaCommand, BaseCommand)

function RegisterAIEntitySchemaCommand.new()
	local self = BaseCommand.new("AI", "RegisterAIEntitySchema")
	return setmetatable(self, RegisterAIEntitySchemaCommand)
end

function RegisterAIEntitySchemaCommand:Init(registry: any, _name: string)
end

function RegisterAIEntitySchemaCommand:Start(registry: any, _name: string)
	self._entityContext = registry:Get("EntityContext")
	assert(self._entityContext ~= nil, "RegisterAIEntitySchemaCommand missing EntityContext in Start")
end

function RegisterAIEntitySchemaCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		local schemaRegistry = self._entityContext._schemaRegistry
		if schemaRegistry ~= nil and schemaRegistry:HasFeature(AISharedContract.FeatureName) then
			return Result.Ok(true)
		end

		local registerResult = self._entityContext:RegisterFeatureSchema(AISharedContract.FeatureName, AIEntitySchema)
		if not registerResult.success then
			return Result.Err("AIEntitySchemaRegistrationFailed", Errors.AI_ENTITY_SCHEMA_REGISTRATION_FAILED, {
				CauseType = registerResult.type,
				CauseMessage = registerResult.message,
				Details = registerResult.data,
			})
		end

		return Result.Ok(true)
	end, self:_Label())
end
return RegisterAIEntitySchemaCommand
