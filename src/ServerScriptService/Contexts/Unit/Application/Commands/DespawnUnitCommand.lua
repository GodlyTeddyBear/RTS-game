--!strict

--[=[
    @class DespawnUnitCommand
    Removes a unit entity from the world and unbinds its team, combat, replication, and instance state.

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

local DespawnUnitCommand = {}
DespawnUnitCommand.__index = DespawnUnitCommand
setmetatable(DespawnUnitCommand, BaseCommand)

function DespawnUnitCommand.new()
	local self = BaseCommand.new("Unit", "DespawnUnit")
	return setmetatable(self, DespawnUnitCommand)
end

-- Resolves the entity, instance, combat, and replication dependencies needed for unit teardown.
function DespawnUnitCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityFactory = "UnitEntityFactory",
		_instanceFactory = "UnitInstanceFactory",
		_combatAdapterService = "UnitCombatAdapterService",
		_replicationService = "UnitECSReplicationService",
	})
end

-- Caches the team context so teardown can unassign the unit from its team bucket.
function DespawnUnitCommand:Start(registry: any, _name: string)
	self._teamContext = registry:Get("TeamContext")
end

-- Unregisters the unit from every server-side system and deletes the entity after all dependencies are detached.
function DespawnUnitCommand:Execute(entity: number): Result.Result<boolean>
	return Result.Catch(function()
		-- Reject non-existent or inactive entities up front.
		Ensure(type(entity) == "number" and self._entityFactory:IsActive(entity), "InvalidEntity", Errors.INVALID_ENTITY)

		local identity = self._entityFactory:GetIdentity(entity)
		Ensure(identity ~= nil and type(identity.UnitGuid) == "string" and identity.UnitGuid ~= "", "InvalidEntity", Errors.INVALID_ENTITY)

		-- Unassign the unit from the team system before the entity disappears.
		local unitHandle = TeamTypes.BuildMemberHandle("Unit", identity.UnitGuid)
		Try(self._teamContext:UnassignMember(unitHandle))

		-- Tear down combat, replication, and instance state before removing the entity itself.
		self._combatAdapterService:UnregisterActor(entity)
		self._replicationService:UnregisterUnitEntity(entity)
		self._instanceFactory:DestroyInstance(entity)
		local deleted = self._entityFactory:DeleteEntity(entity)
		self._entityFactory:FlushPendingDeletes()

		return Ok(deleted)
	end, self:_Label())
end

return DespawnUnitCommand
