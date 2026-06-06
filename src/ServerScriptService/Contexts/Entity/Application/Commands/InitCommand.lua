--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityCoreSchema = require(script.Parent.Parent.Parent.Infrastructure.ECS.Schemas.EntityCoreSchema)
local EntityProofSchema = require(script.Parent.Parent.Parent.Infrastructure.ECS.Schemas.EntityProofSchema)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local InitCommand = {}
InitCommand.__index = InitCommand
setmetatable(InitCommand, BaseCommand)

function InitCommand.new()
	local self = BaseCommand.new("Entity", "Init")
	return setmetatable(self, InitCommand)
end

function InitCommand:Init(registry: any, _name: string)
	self._registry = registry
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_schemaRegistry = "EntitySchemaRegistry",
		_validationService = "EntityValidationService",
	})
	assert(self._lifecycle ~= nil, "Entity.InitCommand missing EntityLifecycleStateMachine")
	assert(self._schemaRegistry ~= nil, "Entity.InitCommand missing EntitySchemaRegistry")
	assert(self._validationService ~= nil, "Entity.InitCommand missing EntityValidationService")
end

function InitCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		self:_EnsureDependencies()

		assert(self._lifecycle ~= nil, "Entity.InitCommand executed without EntityLifecycleStateMachine")
		assert(self._schemaRegistry ~= nil, "Entity.InitCommand executed without EntitySchemaRegistry")
		assert(self._validationService ~= nil, "Entity.InitCommand executed without EntityValidationService")

		local currentState = self._lifecycle:GetState()
		if currentState == "Uninitialized" then
			local transitionResult = self._lifecycle:BeginECSRegistration()
			if not transitionResult.success then
				return transitionResult
			end

			local schemaResult = self:_RegisterBuiltInSchemas()
			if not schemaResult.success then
				return schemaResult
			end

			return Result.Ok(true)
		end

		return EntityOperationSupport.RequireLifecycleStates(self._validationService, "Init", currentState, {
			"RegisteringECS",
			"FinalizingECSRegistration",
			"CompilingECS",
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"Running",
		})
	end, self:_Label())
end

function InitCommand:_EnsureDependencies()
	if self._lifecycle ~= nil and self._schemaRegistry ~= nil and self._validationService ~= nil then
		return
	end

	assert(self._registry ~= nil, "Entity.InitCommand missing registry for dependency recovery")
	self:Init(self._registry, "InitCommand")
end

function InitCommand:_RegisterBuiltInSchemas(): Result.Result<boolean>
	if not self._schemaRegistry:HasFeature(EntityCoreSchema.FeatureName) then
		local coreResult = self._schemaRegistry:RegisterCoreSchema(EntityCoreSchema)
		if not coreResult.success then
			return coreResult
		end
	end

	if not self._schemaRegistry:HasFeature(EntityProofSchema.FeatureName) then
		local proofResult = self._schemaRegistry:RegisterFeatureSchema(EntityProofSchema.FeatureName, EntityProofSchema)
		if not proofResult.success then
			return proofResult
		end
	end

	return Result.Ok(true)
end

return InitCommand
