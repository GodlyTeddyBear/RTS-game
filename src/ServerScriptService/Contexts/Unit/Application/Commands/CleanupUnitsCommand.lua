--!strict

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

function CleanupUnitsCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityFactory = "UnitEntityFactory",
		_instanceFactory = "UnitInstanceFactory",
		_combatAdapterService = "UnitCombatAdapterService",
		_replicationService = "UnitECSReplicationService",
	})
end

function CleanupUnitsCommand:Start(registry: any, _name: string)
	self._teamContext = registry:Get("TeamContext")
end

function CleanupUnitsCommand:Execute(ownerKind: string?, ownerId: string?): Result.Result<boolean>
	return Result.Catch(function()
		local entities
		if ownerKind ~= nil or ownerId ~= nil then
			Ensure(type(ownerKind) == "string" and ownerKind ~= "", "InvalidOwnerKind", Errors.INVALID_OWNER_KIND)
			Ensure(type(ownerId) == "string" and ownerId ~= "", "InvalidOwnerId", Errors.INVALID_OWNER_ID)
			entities = self._entityFactory:QueryOwnerEntities(ownerKind, ownerId)
		else
			entities = self._entityFactory:QueryActiveEntities()
		end

		for _, entity in ipairs(entities) do
			local identity = self._entityFactory:GetIdentity(entity)
			if identity ~= nil and type(identity.UnitGuid) == "string" and identity.UnitGuid ~= "" then
				Try(self._teamContext:UnassignMember(TeamTypes.BuildMemberHandle("Unit", identity.UnitGuid)))
			end
			self._combatAdapterService:UnregisterActor(entity)
			self._replicationService:UnregisterUnitEntity(entity)
			self._instanceFactory:DestroyInstance(entity)
			self._entityFactory:DeleteEntity(entity)
		end

		self._entityFactory:FlushPendingDeletes()
		return Ok(true)
	end, self:_Label())
end

return CleanupUnitsCommand
