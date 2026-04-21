--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class CleanupAllEnemies
	Stops all enemy movement and removes every enemy entity and model.
	@server
]=]
local CleanupAllEnemies = {}
CleanupAllEnemies.__index = CleanupAllEnemies

function CleanupAllEnemies.new()
	return setmetatable({}, CleanupAllEnemies)
end

function CleanupAllEnemies:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("EnemyEntityFactory")
	self._despawnEnemyCommand = registry:Get("DespawnEnemyCommand")
end

function CleanupAllEnemies:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		local seen: { [any]: boolean } = {}
		for _, entity in ipairs(self._entityFactory:QueryAliveEntities()) do
			seen[entity] = true
			Try(self._despawnEnemyCommand:Execute(entity))
		end

		for _, entity in ipairs(self._entityFactory:QueryGoalReachedEntities()) do
			if not seen[entity] then
				Try(self._despawnEnemyCommand:Execute(entity))
			end
		end

		return Ok(true)
	end, "Enemy:CleanupAllEnemies")
end

return CleanupAllEnemies
