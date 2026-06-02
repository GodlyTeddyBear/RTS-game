--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
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
		_entityContext = "EntityContext",
		_enemyEntityReadService = "EnemyEntityReadService",
	})
end

function DespawnEnemy:Execute(entity: any): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(entity ~= nil, "InvalidEntity", Errors.INVALID_ENTITY)

		local identity = self._enemyEntityReadService:GetIdentity(entity)
		if identity == nil then
			return Ok(false)
		end

		Try(self._entityContext:DestroyEntity(entity))
		return Ok(true)
	end, "Enemy:DespawnEnemy")
end

return DespawnEnemy
