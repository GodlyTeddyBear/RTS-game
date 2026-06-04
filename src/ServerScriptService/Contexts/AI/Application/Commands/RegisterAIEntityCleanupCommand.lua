--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)
local AICleanupOutcomeSystem = require(script.Parent.Parent.Parent.Infrastructure.Systems.AICleanupOutcomeSystem)

local RegisterAIEntityCleanupCommand = {}
RegisterAIEntityCleanupCommand.__index = RegisterAIEntityCleanupCommand
setmetatable(RegisterAIEntityCleanupCommand, BaseCommand)

function RegisterAIEntityCleanupCommand.new()
	local self = BaseCommand.new("AI", "RegisterAIEntityCleanup")
	return setmetatable(self, RegisterAIEntityCleanupCommand)
end

function RegisterAIEntityCleanupCommand:Init(registry: any, _name: string)
	self._registry = registry
	if registry ~= nil and type(registry) == "table" and type(registry.Modules) == "table" then
		self._entityContext = registry.Modules.EntityContext
	end
	self:_RequireDependency(registry, "_cleanupEntityAICommand", "CleanupEntityAICommand")
end

function RegisterAIEntityCleanupCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		self:_EnsureEntityContext()

		local registerResult = self._entityContext:RegisterSystem("CleanupResolve", {
			Name = "AICleanupOutcomeSystem",
			Phase = "CleanupResolve",
			Reads = {
				"Entity.CleanupOutcomeRequest",
				"Entity.CleanupRequestTag",
			},
			Writes = {
				"Entity.CleanupOutcomeRequest",
				"Entity.CleanupProcessedTag",
				"Entity.CleanupFailedTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return AICleanupOutcomeSystem.new(entityFactory, self._cleanupEntityAICommand)
			end,
		})
		if registerResult.success then
			return Result.Ok(true)
		end

		return Result.Err("AIEntityCleanupRegistrationFailed", Errors.AI_ENTITY_CLEANUP_REGISTRATION_FAILED, {
			CauseType = registerResult.type,
			CauseMessage = registerResult.message,
			Details = registerResult.data,
		})
	end, self:_Label())
end

function RegisterAIEntityCleanupCommand:_EnsureEntityContext()
	if self._entityContext ~= nil then
		return
	end
	assert(self._registry ~= nil, "RegisterAIEntityCleanupCommand missing registry for EntityContext resolution")
	self._entityContext = self._registry:Get("EntityContext")
end

return RegisterAIEntityCleanupCommand
