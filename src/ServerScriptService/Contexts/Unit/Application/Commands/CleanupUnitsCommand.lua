--!strict

--[=[
    @class CleanupUnitsCommand
    Removes all units, or all units owned by a specific owner bucket, by delegating to the despawn command.

    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
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

-- Resolves the entity factory and despawn command used to identify and remove target units.
function CleanupUnitsCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityFactory = "UnitEntityFactory",
		_despawnUnitCommand = "DespawnUnitCommand",
	})
end

-- Selects either a specific owner's units or every active unit and despawns them one by one.
function CleanupUnitsCommand:Execute(ownerKind: string?, ownerId: string?): Result.Result<boolean>
	return Result.Catch(function()
		-- Switch between owner-scoped cleanup and full cleanup based on whether an owner was supplied.
		local entities
		if ownerKind ~= nil or ownerId ~= nil then
			Ensure(type(ownerKind) == "string" and ownerKind ~= "", "InvalidOwnerKind", Errors.INVALID_OWNER_KIND)
			Ensure(type(ownerId) == "string" and ownerId ~= "", "InvalidOwnerId", Errors.INVALID_OWNER_ID)
			entities = self._entityFactory:QueryOwnerEntities(ownerKind, ownerId)
		else
			entities = self._entityFactory:QueryActiveEntities()
		end

		-- Despawn each matching entity through the normal teardown path so every dependency is cleaned up consistently.
		for _, entity in ipairs(entities) do
			Try(self._despawnUnitCommand:Execute(entity))
		end

		return Ok(true)
	end, self:_Label())
end

return CleanupUnitsCommand
