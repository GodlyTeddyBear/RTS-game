--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

local CleanupUnitsCommand = {}
CleanupUnitsCommand.__index = CleanupUnitsCommand
setmetatable(CleanupUnitsCommand, BaseCommand)

function CleanupUnitsCommand.new()
	local self = BaseCommand.new("Unit", "CleanupUnits")
	return setmetatable(self, CleanupUnitsCommand)
end

function CleanupUnitsCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_unitReadService = "UnitEntityReadService",
		_despawnUnitCommand = "DespawnUnitCommand",
	})
end

function CleanupUnitsCommand:Execute(ownerKind: string?, ownerId: string?): Result.Result<boolean>
	return Result.Catch(function()
		local entities
		if ownerKind ~= nil or ownerId ~= nil then
			Ensure(type(ownerKind) == "string" and ownerKind ~= "", "InvalidOwnerKind", Errors.INVALID_OWNER_KIND)
			Ensure(type(ownerId) == "string" and ownerId ~= "", "InvalidOwnerId", Errors.INVALID_OWNER_ID)
			entities = self._unitReadService:QueryOwnerEntities(ownerKind, ownerId)
		else
			entities = self._unitReadService:QueryActiveEntities()
		end

		for _, entity in ipairs(entities) do
			Try(self._despawnUnitCommand:Execute(entity))
		end

		return Ok(true)
	end, self:_Label())
end

return CleanupUnitsCommand
