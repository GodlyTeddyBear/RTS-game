--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

local CleanupSummonsCommand = {}
CleanupSummonsCommand.__index = CleanupSummonsCommand
setmetatable(CleanupSummonsCommand, BaseCommand)

function CleanupSummonsCommand.new()
	local self = BaseCommand.new("Summon", "CleanupSummons")
	return setmetatable(self, CleanupSummonsCommand)
end

function CleanupSummonsCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_summonReadService = "SummonEntityReadService",
	})
end

function CleanupSummonsCommand:Start(registry: any, _name: string)
	self:_RequireDependency(registry, "_entityContext", "EntityContext")
end

function CleanupSummonsCommand:Execute(ownerUserId: number?): Result.Result<boolean>
	return Result.Catch(function()
		local entities = if type(ownerUserId) == "number"
			then self._summonReadService:QueryOwnerDrones(ownerUserId)
			else self._summonReadService:QueryActiveDrones()

		for _, entity in ipairs(entities) do
			Try(self._entityContext:DestroyEntity(entity))
		end

		return Ok(true)
	end, self:_Label())
end

return CleanupSummonsCommand
