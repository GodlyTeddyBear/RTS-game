--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

local CleanupAllExtractorsCommand = {}
CleanupAllExtractorsCommand.__index = CleanupAllExtractorsCommand

function CleanupAllExtractorsCommand.new()
	return setmetatable({}, CleanupAllExtractorsCommand)
end

function CleanupAllExtractorsCommand:Init(registry: any, _name: string)
	self._factory = registry:Get("MiningEntityFactory")
end

function CleanupAllExtractorsCommand:Execute(): Result.Result<boolean>
	self._factory:DeleteAll()
	self._factory:FlushPendingDeletes()
	return Ok(true)
end

return CleanupAllExtractorsCommand
