--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

local CleanupBaseCommand = {}
CleanupBaseCommand.__index = CleanupBaseCommand

function CleanupBaseCommand.new()
	return setmetatable({}, CleanupBaseCommand)
end

function CleanupBaseCommand:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("BaseEntityFactory")
	self._syncService = registry:Get("BaseSyncService")
	self._applyDamageCommand = registry:Get("ApplyDamageBaseCommand")
end

function CleanupBaseCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		self._entityFactory:ClearBase()
		self._syncService:ClearState()
		self._applyDamageCommand:ResetDeathEmission()
		return Ok(true)
	end, "Base:CleanupBaseCommand")
end

return CleanupBaseCommand
