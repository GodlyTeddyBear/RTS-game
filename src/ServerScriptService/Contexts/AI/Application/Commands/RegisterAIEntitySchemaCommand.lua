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
	self._registry = registry
	if registry ~= nil and type(registry) == "table" and type(registry.Modules) == "table" then
		self._entityContext = registry.Modules.EntityContext
	end
end

function RegisterAIEntitySchemaCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		self:_EnsureEntityContext()

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

function RegisterAIEntitySchemaCommand:_EnsureEntityContext()
	if self._entityContext ~= nil then
		return
	end
	assert(self._registry ~= nil, "RegisterAIEntitySchemaCommand missing registry for EntityContext resolution")
	self._entityContext = self._registry:Get("EntityContext")
end

return RegisterAIEntitySchemaCommand
