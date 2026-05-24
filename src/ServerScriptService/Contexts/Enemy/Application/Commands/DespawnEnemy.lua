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

--[=[
	@class DespawnEnemy
	Stops enemy movement, destroys the model, and removes the entity from the world.
	@server
]=]
local DespawnEnemy = {}
DespawnEnemy.__index = DespawnEnemy
setmetatable(DespawnEnemy, BaseCommand)

function DespawnEnemy.new()
	local self = BaseCommand.new("Enemy", "DespawnEnemy")
	return setmetatable(self, DespawnEnemy)
end

function DespawnEnemy:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityFactory = "EnemyEntityFactory",
		_instanceFactory = "EnemyInstanceFactory",
		_combatAdapterService = "EnemyCombatAdapterService",
		_replicationService = "EnemyECSReplicationService",
	})
end

function DespawnEnemy:Start(registry: any, _name: string)
	self._teamContext = registry:Get("TeamContext")
end

function DespawnEnemy:Execute(entity: any): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(entity ~= nil, "InvalidEntity", Errors.INVALID_ENTITY)

		local identity = self._entityFactory:GetIdentity(entity)
		local modelRef = self._entityFactory:GetModelRef(entity)
		if not identity and not modelRef then
			return Ok(false)
		end

		if identity ~= nil and type(identity.EnemyId) == "string" and identity.EnemyId ~= "" then
			Try(self._teamContext:UnassignMember(TeamTypes.BuildMemberHandle("Enemy", identity.EnemyId)))
		end

		self._combatAdapterService:UnregisterActor(entity)
		self._replicationService:UnregisterEnemyEntity(entity)
		self._instanceFactory:DestroyInstance(entity)
		self._entityFactory:DeleteEntity(entity)
		return Ok(true)
	end, "Enemy:DespawnEnemy")
end

return DespawnEnemy
