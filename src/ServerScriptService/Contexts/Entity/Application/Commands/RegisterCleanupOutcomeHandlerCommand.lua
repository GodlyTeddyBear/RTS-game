--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local RegisterCleanupOutcomeHandlerCommand = {}
RegisterCleanupOutcomeHandlerCommand.__index = RegisterCleanupOutcomeHandlerCommand
setmetatable(RegisterCleanupOutcomeHandlerCommand, BaseCommand)

function RegisterCleanupOutcomeHandlerCommand.new()
	local self = BaseCommand.new("Entity", "RegisterCleanupOutcomeHandler")
	return setmetatable(self, RegisterCleanupOutcomeHandlerCommand)
end

function RegisterCleanupOutcomeHandlerCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_cleanupOutcomeService = "EntityCleanupOutcomeService",
	})
end

function RegisterCleanupOutcomeHandlerCommand:Execute(payload: any): Result.Result<boolean>
	return Result.Catch(function()
		return self._cleanupOutcomeService:RegisterHandler(payload)
	end, self:_Label())
end

return RegisterCleanupOutcomeHandlerCommand
