--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local AIActionDefinitionRegistry = require(script.Parent.Infrastructure.Services.AIActionDefinitionRegistry)
local AIBehaviorDefinitionCompiler = require(script.Parent.Infrastructure.Services.AIBehaviorDefinitionCompiler)
local AIBehaviorDefinitionRegistry = require(script.Parent.Infrastructure.Services.AIBehaviorDefinitionRegistry)
local AIEntityDecisionEvaluator = require(script.Parent.Infrastructure.Services.AIEntityDecisionEvaluator)
local AIEntityProfileRegistry = require(script.Parent.Infrastructure.Services.AIEntityProfileRegistry)
local AIFactProviderRegistry = require(script.Parent.Infrastructure.Services.AIFactProviderRegistry)
local AIEvaluationRegistry = require(script.Parent.Infrastructure.Services.AIEvaluationRegistry)
local AIBehaviorDefinitionPolicy = require(script.Parent.AIDomain.Policies.AIBehaviorDefinitionPolicy)
local AIEntitySetupPolicy = require(script.Parent.AIDomain.Policies.AIEntitySetupPolicy)

local EvaluateEntityAICommand = require(script.Parent.Application.Commands.EvaluateEntityAICommand)
local CleanupEntityAICommand = require(script.Parent.Application.Commands.CleanupEntityAICommand)
local RegisterAIEntityCleanupCommand = require(script.Parent.Application.Commands.RegisterAIEntityCleanupCommand)
local RegisterFactProviderCommand = require(script.Parent.Application.Commands.RegisterFactProviderCommand)
local RegisterAIEntitySchemaCommand = require(script.Parent.Application.Commands.RegisterAIEntitySchemaCommand)
local RegisterAIEntitySystemsCommand = require(script.Parent.Application.Commands.RegisterAIEntitySystemsCommand)
local RegisterActionDefinitionCommand = require(script.Parent.Application.Commands.RegisterActionDefinitionCommand)
local RegisterBehaviorDefinitionCommand = require(script.Parent.Application.Commands.RegisterBehaviorDefinitionCommand)
local RegisterEvaluationCommand = require(script.Parent.Application.Commands.RegisterEvaluationCommand)
local SeedBuiltInAIDefinitionsCommand = require(script.Parent.Application.Commands.SeedBuiltInAIDefinitionsCommand)
local SetupEntityAICommand = require(script.Parent.Application.Commands.SetupEntityAICommand)
local SetupEntityAIFromProfileCommand = require(script.Parent.Application.Commands.SetupEntityAIFromProfileCommand)
local GetStatusQuery = require(script.Parent.Application.Queries.GetStatusQuery)

local Catch = Result.Catch

local function moduleSpec(name: string, module: any, cacheAs: string?): BaseContext.TModuleSpec
	return {
		Name = name,
		Module = module,
		CacheAs = cacheAs,
	}
end

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	moduleSpec("AIBehaviorDefinitionRegistry", AIBehaviorDefinitionRegistry, "_behaviorRegistry"),
	moduleSpec("AIEvaluationRegistry", AIEvaluationRegistry, "_evaluationRegistry"),
	moduleSpec("AIActionDefinitionRegistry", AIActionDefinitionRegistry, "_actionRegistry"),
	moduleSpec("AIBehaviorDefinitionCompiler", AIBehaviorDefinitionCompiler),
	moduleSpec("AIEntityDecisionEvaluator", AIEntityDecisionEvaluator),
	moduleSpec("AIFactProviderRegistry", AIFactProviderRegistry),
	moduleSpec("AIEntityProfileRegistry", AIEntityProfileRegistry),
}

local DomainModules: { BaseContext.TModuleSpec } = {
	moduleSpec("AIBehaviorDefinitionPolicy", AIBehaviorDefinitionPolicy),
	moduleSpec("AIEntitySetupPolicy", AIEntitySetupPolicy),
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	moduleSpec("RegisterAIEntitySchemaCommand", RegisterAIEntitySchemaCommand, "_registerAIEntitySchemaCommand"),
	moduleSpec("RegisterAIEntitySystemsCommand", RegisterAIEntitySystemsCommand, "_registerAIEntitySystemsCommand"),
	moduleSpec("RegisterBehaviorDefinitionCommand", RegisterBehaviorDefinitionCommand, "_registerBehaviorDefinitionCommand"),
	moduleSpec("RegisterEvaluationCommand", RegisterEvaluationCommand, "_registerEvaluationCommand"),
	moduleSpec("RegisterActionDefinitionCommand", RegisterActionDefinitionCommand, "_registerActionDefinitionCommand"),
	moduleSpec("SetupEntityAICommand", SetupEntityAICommand, "_setupEntityAICommand"),
	moduleSpec("SetupEntityAIFromProfileCommand", SetupEntityAIFromProfileCommand, "_setupEntityAIFromProfileCommand"),
	moduleSpec("CleanupEntityAICommand", CleanupEntityAICommand, "_cleanupEntityAICommand"),
	moduleSpec("RegisterAIEntityCleanupCommand", RegisterAIEntityCleanupCommand, "_registerAIEntityCleanupCommand"),
	moduleSpec("EvaluateEntityAICommand", EvaluateEntityAICommand, "_evaluateEntityAICommand"),
	moduleSpec("RegisterFactProviderCommand", RegisterFactProviderCommand, "_registerFactProviderCommand"),
	moduleSpec("SeedBuiltInAIDefinitionsCommand", SeedBuiltInAIDefinitionsCommand, "_seedBuiltInAIDefinitionsCommand"),
	moduleSpec("GetStatusQuery", GetStatusQuery, "_getStatusQuery"),
}

local AIModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Domain = DomainModules,
	Application = ApplicationModules,
}

local AIContext = Knit.CreateService({
	Name = "AIContext",
	Client = {},
	Modules = AIModules,
	StartOrder = { "Infrastructure", "Domain", "Application" },
	ExternalServices = {
		{ Name = "EntityContext" },
	},
})

local AIBaseContext = BaseContext.new(AIContext)

function AIContext:KnitInit()
	AIBaseContext:KnitInit()
	self._schemaRegistered = false
	self._systemsRegistered = false
	self._cleanupRegistered = false
	self._builtInsSeeded = false
end

function AIContext:KnitStart()
	AIBaseContext:KnitStart()

	local schemaResult = self:_RegisterEntitySchema()
	if not schemaResult.success then
		error(("AIContext failed to register Entity schema: [%s] %s"):format(
			tostring(schemaResult.type),
			tostring(schemaResult.message)
		))
	end

	local systemsResult = self:_RegisterEntitySystems()
	if not systemsResult.success then
		error(("AIContext failed to register Entity systems: [%s] %s"):format(
			tostring(systemsResult.type),
			tostring(systemsResult.message)
		))
	end

	local cleanupResult = self:_RegisterEntityCleanup()
	if not cleanupResult.success then
		error(("AIContext failed to register Entity cleanup: [%s] %s"):format(
			tostring(cleanupResult.type),
			tostring(cleanupResult.message)
		))
	end

	local seedResult = self:_SeedBuiltInDefinitions()
	if not seedResult.success then
		error(
			("AIContext failed to seed built-in definitions: [%s] %s"):format(
				tostring(seedResult.type),
				tostring(seedResult.message)
			)
		)
	end
end

function AIContext:_RegisterEntitySchema(): Result.Result<boolean>
	return Catch(function()
		local result = self._registerAIEntitySchemaCommand:Execute()
		if result.success then
			self._schemaRegistered = true
		end
		return result
	end, "AIContext:RegisterEntitySchema")
end

function AIContext:_RegisterEntitySystems(): Result.Result<boolean>
	return Catch(function()
		local result = self._registerAIEntitySystemsCommand:Execute()
		if result.success then
			self._systemsRegistered = true
		end
		return result
	end, "AIContext:RegisterEntitySystems")
end

function AIContext:_RegisterEntityCleanup(): Result.Result<boolean>
	return Catch(function()
		local result = self._registerAIEntityCleanupCommand:Execute()
		if result.success then
			self._cleanupRegistered = true
		end
		return result
	end, "AIContext:RegisterEntityCleanup")
end

function AIContext:_SeedBuiltInDefinitions(): Result.Result<boolean>
	return Catch(function()
		local result = self._seedBuiltInAIDefinitionsCommand:Execute()
		if result.success then
			self._builtInsSeeded = true
		end
		return result
	end, "AIContext:SeedBuiltInDefinitions")
end

function AIContext:RegisterBehaviorDefinition(payload: any): Result.Result<boolean>
	return Catch(function()
		return self._registerBehaviorDefinitionCommand:Execute(payload)
	end, "AIContext:RegisterBehaviorDefinition")
end

function AIContext:RegisterEvaluation(payload: any): Result.Result<boolean>
	return Catch(function()
		return self._registerEvaluationCommand:Execute(payload)
	end, "AIContext:RegisterEvaluation")
end

function AIContext:RegisterActionDefinition(payload: any): Result.Result<boolean>
	return Catch(function()
		return self._registerActionDefinitionCommand:Execute(payload)
	end, "AIContext:RegisterActionDefinition")
end

function AIContext:RegisterFactProvider(payload: any): Result.Result<boolean>
	return Catch(function()
		return self._registerFactProviderCommand:Execute(payload)
	end, "AIContext:RegisterFactProvider")
end

function AIContext:SetupEntityAI(entity: number, profile: any): Result.Result<boolean>
	return Catch(function()
		return self._setupEntityAICommand:Execute(entity, profile)
	end, "AIContext:SetupEntityAI")
end

function AIContext:SetupEntityAIFromProfile(entity: number, profileId: string, overrides: any?): Result.Result<boolean>
	return Catch(function()
		return self._setupEntityAIFromProfileCommand:Execute(entity, profileId, overrides)
	end, "AIContext:SetupEntityAIFromProfile")
end

function AIContext:CleanupEntityAI(entity: number): Result.Result<boolean>
	return Catch(function()
		return self._cleanupEntityAICommand:Execute(entity)
	end, "AIContext:CleanupEntityAI")
end

function AIContext:EvaluateEntityAI(entity: number, options: any?): Result.Result<any>
	return Catch(function()
		return self._evaluateEntityAICommand:Execute(entity, options)
	end, "AIContext:EvaluateEntityAI")
end

function AIContext:GetStatus(): Result.Result<any>
	return Catch(function()
		return self._getStatusQuery:Execute(
			self._schemaRegistered == true,
			self._systemsRegistered == true,
			self._cleanupRegistered == true,
			self._builtInsSeeded == true
		)
	end, "AIContext:GetStatus")
end

return AIContext
