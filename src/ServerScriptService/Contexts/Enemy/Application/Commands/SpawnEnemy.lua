--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
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

function SpawnEnemy.new()
	return setmetatable({}, SpawnEnemy)
end

function SpawnEnemy:Init(registry: any, _name: string)
	self._spawnPolicy = registry:Get("EnemySpawnPolicy")
	self._entityFactory = registry:Get("EnemyEntityFactory")
	self._modelFactory = registry:Get("EnemyModelFactory")
	self._syncService = registry:Get("EnemyGameObjectSyncService")
end

function SpawnEnemy:Execute(role: string, spawnCFrame: CFrame, waveNumber: number): Result.Result<number>
	local model: Model? = nil
	local entity: number? = nil

	return Result.Catch(function()
		Try(self._spawnPolicy:Check(role, spawnCFrame))
		Ensure(waveNumber > 0, "InvalidWaveNumber", Errors.INVALID_WAVE_NUMBER)

		local enemyId = HttpService:GenerateGUID(false)
		model = self._modelFactory:CreateEnemyModel(role, enemyId, waveNumber)
		entity = self._entityFactory:CreateEnemy(enemyId, role, spawnCFrame, waveNumber)

		model:PivotTo(spawnCFrame)
		self._entityFactory:SetModelRef(entity, model)
		self._syncService:RegisterEntity(entity)
		GameEvents.Bus:Emit(GameEvents.Events.Wave.EnemySpawned, entity, role, waveNumber)

		return Ok(entity)
	end, "Enemy:SpawnEnemy", function()
		if model then
			self._modelFactory:DestroyModel(model)
		end
		if entity then
			self._entityFactory:DeleteEntity(entity)
		end
	end)
end

return SpawnEnemy
