--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

--[=[
	@class SpawnEnemy
	Creates an enemy entity, model, and movement state for the active lane.
	@server
]=]
local SpawnEnemy = {}
SpawnEnemy.__index = SpawnEnemy
setmetatable(SpawnEnemy, BaseCommand)

function SpawnEnemy.new()
	local self = BaseCommand.new("Enemy", "SpawnEnemy")
	return setmetatable(self, SpawnEnemy)
end

function SpawnEnemy:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_spawnPolicy = "EnemySpawnPolicy",
		_entityFactory = "EnemyEntityFactory",
		_instanceFactory = "EnemyInstanceFactory",
		_syncService = "EnemyGameObjectSyncService",
	})
end

function SpawnEnemy:Execute(role: string, spawnCFrame: CFrame, waveNumber: number): Result.Result<number>
	local model: Model? = nil
	local entity: number? = nil

	return Result.Catch(function()
		Try(self._spawnPolicy:Check(role, spawnCFrame))
		Ensure(waveNumber > 0, "InvalidWaveNumber", Errors.INVALID_WAVE_NUMBER)

		local enemyId = HttpService:GenerateGUID(false)
		entity = self._entityFactory:CreateEnemy(enemyId, role, spawnCFrame, waveNumber)
		model = self._instanceFactory:CreateEnemyInstance(entity, role, enemyId, waveNumber)

		model:PivotTo(spawnCFrame)
		self._entityFactory:SetModelRef(entity, model)
		self._syncService:RegisterEntity(entity, model)
		self:_EmitGameEvent("Wave", "EnemySpawned", entity, role, waveNumber)

		return Ok(entity)
	end, self:_Label(), function()
		if entity then
			self._instanceFactory:DestroyInstance(entity)
		end
		if entity then
			self._entityFactory:DeleteEntity(entity)
		end
	end)
end

return SpawnEnemy
