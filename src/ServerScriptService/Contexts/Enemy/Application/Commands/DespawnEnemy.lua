--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

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
	})
end

function DespawnEnemy:Execute(entity: any): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(entity ~= nil, "InvalidEntity", Errors.INVALID_ENTITY)

		local identity = self._entityFactory:GetIdentity(entity)
		local modelRef = self._entityFactory:GetModelRef(entity)
		if not identity and not modelRef then
			return Ok(false)
		end

		self._instanceFactory:DestroyInstance(entity)
		self._entityFactory:DeleteEntity(entity)
		return Ok(true)
	end, "Enemy:DespawnEnemy")
end

return DespawnEnemy
