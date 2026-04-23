--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

function DespawnEnemy.new()
	return setmetatable({}, DespawnEnemy)
end

function DespawnEnemy:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("EnemyEntityFactory")
	self._instanceFactory = registry:Get("EnemyInstanceFactory")
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
