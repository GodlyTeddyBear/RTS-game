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
		_worldRegistry = "EntityWorldRegistryService",
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_replicationService = "EntityReplicationService",
	})
end

function RegisterFeatureSchemaCommand:Execute(featureNameOrWorldName: string, schemaOrFeatureName: any, maybeSchema: any?): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "RegisterFeatureSchema", self._lifecycle:GetState(), {
			"RegisteringECS",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local worldName = self._worldRegistry:GetDefaultWorldName()
		local featureName = featureNameOrWorldName
		local schema = schemaOrFeatureName
		if maybeSchema ~= nil then
			worldName = featureNameOrWorldName
			featureName = schemaOrFeatureName
			schema = maybeSchema
		end

		if self._worldRegistry:IsDefaultWorld(worldName) then
			local registrationResult = self._schemaRegistry:RegisterFeatureSchema(featureName, schema)
			if not registrationResult.success then
				return registrationResult
			end
			local compiledSchema = registrationResult.value
			local sharedComponents = {}
			local sharedTags = {}
			for _, componentId in pairs(compiledSchema.Components or {}) do
				local metadata = self._schemaRegistry:GetComponentMetadataById(componentId)
				if metadata ~= nil and metadata.Replication ~= "ServerOnly" then
					table.insert(sharedComponents, componentId)
				end
			end
			for _, tagId in pairs(compiledSchema.Tags or {}) do
				local metadata = self._schemaRegistry:GetComponentMetadataById(tagId)
				if metadata ~= nil and metadata.Replication ~= "ServerOnly" then
					table.insert(sharedTags, tagId)
				end
			end
			self._replicationService:ApplySharedSchema({
				sharedComponents = sharedComponents,
				sharedTags = sharedTags,
			})
			return registrationResult
		end

		return self._worldRegistry:RegisterFeatureSchema(worldName, featureName, schema)
	end, self:_Label())
end

return RegisterFeatureSchemaCommand
