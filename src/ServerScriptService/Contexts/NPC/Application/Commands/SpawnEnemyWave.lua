--!strict

--[=[
	@class SpawnEnemyWave
	Application service orchestrating enemy wave spawn (validation, entity creation, model spawn).
	@server
]=]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyConfig = require(ReplicatedStorage.Contexts.Quest.Config.EnemyConfig)
local WaveConfig = require(ReplicatedStorage.Contexts.NPC.Config.WaveConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Err = Result.Err
local Try = Result.Try
local fromPcall = Result.fromPcall
local MentionSuccess = Result.MentionSuccess

--[[
    SpawnEnemyWave - Application Service

    Orchestrates: validate -> read wave config -> create JECS entities -> create R6 models
    Returns an array of enemy JECS entity IDs for Combat context to use.
]]

local SpawnEnemyWave = {}
SpawnEnemyWave.__index = SpawnEnemyWave

export type TSpawnEnemyWave = typeof(setmetatable({}, SpawnEnemyWave))

function SpawnEnemyWave.new(): TSpawnEnemyWave
	local self = setmetatable({}, SpawnEnemyWave)
	return self
end

--[=[
	Initialize service with policies and factories.
	@within SpawnEnemyWave
	@param registry any -- Registry with `:Get()` for policies and factories
]=]
function SpawnEnemyWave:Init(registry: any)
	self.EnemyWaveSpawnPolicy = registry:Get("EnemyWaveSpawnPolicy")
	self.NPCEntityFactory = registry:Get("NPCEntityFactory")
	self.NPCModelFactory = registry:Get("NPCModelFactory")
end

--[=[
	Spawn a complete wave of enemies for a dungeon zone.
	@within SpawnEnemyWave
	@param userId number -- Player ID who owns this dungeon
	@param waveNumber number -- Wave index to spawn
	@param zoneId string -- Zone ID for wave config lookup
	@param spawnPoints { any } -- Array of spawn locations
	@return Result.Result<{ any }> -- Array of enemy entity IDs, or error
	@error string -- Validation failure or entity/model creation failure
]=]
function SpawnEnemyWave:Execute(
	userId: number,
	waveNumber: number,
	zoneId: string,
	spawnPoints: { any }
): Result.Result<{ any }>
	-- Validate wave spawn parameters against domain policy
	Try(self.EnemyWaveSpawnPolicy:Check(userId, waveNumber, zoneId, spawnPoints))

	-- Look up wave config and spawn all enemy groups
	local waveData = WaveConfig[zoneId][waveNumber]
	local enemyEntities = self:_SpawnWaveGroups(userId, waveData, spawnPoints)
	if #enemyEntities == 0 then
		return Err("EntityCreationFailed", Errors.ENTITY_CREATION_FAILED, { userId = userId })
	end

	-- Log success with enemy count
	MentionSuccess("NPC:SpawnEnemyWave:Execute", "Spawned enemy wave entities for dungeon wave", {
		userId = userId,
		waveNumber = waveNumber,
		enemyCount = #enemyEntities,
	})
	return Ok(enemyEntities)
end

-- Spawn all enemy groups in a wave, round-robin across spawn points.
function SpawnEnemyWave:_SpawnWaveGroups(userId: number, waveData: { any }, spawnPoints: { any }): { any }
	local enemyEntities: { any } = {}
	local spawnIndex = 1

	-- Iterate each enemy group in the wave config
	for _, group in ipairs(waveData) do
		local config = EnemyConfig[group.EnemyType]
		if not config then continue end

		-- Spawn all enemies in this group (each group has a Count)
		for _ = 1, group.Count do
			local entity = self:_SpawnSingleEnemy(userId, group.EnemyType, config, spawnPoints, spawnIndex)
			if entity then
				table.insert(enemyEntities, entity)
			end
			spawnIndex += 1
		end
	end
	return enemyEntities
end

-- Spawn a single enemy: generate ID, create entity, create model, link refs.
function SpawnEnemyWave:_SpawnSingleEnemy(
	userId: number,
	enemyType: string,
	config: any,
	spawnPoints: { any },
	spawnIndex: number
): any?
	-- Generate unique enemy instance ID (UUID to avoid collisions across spawns)
	local enemyId = enemyType .. "_" .. HttpService:GenerateGUID(false)
	local spawnPosition = self:_PickSpawnPosition(spawnPoints, spawnIndex)
	local displayName = config.DisplayName or enemyType

	-- Create JECS entity with base stats from EnemyConfig
	local entity = self.NPCEntityFactory:CreateEnemy(
		userId, enemyId, enemyType, displayName,
		config.BaseHP, config.BaseATK, config.BaseDEF,
		spawnPosition
	)
	if not entity then return nil end

	-- Create R6 model and link to entity
	fromPcall("ModelCreationFailed", function()
		return self.NPCModelFactory:CreateEnemyModel(enemyType, enemyId, userId, displayName, config.BaseHP)
	end):andThen(function(model)
		self.NPCModelFactory:UpdatePosition(model, CFrame.new(spawnPosition))
		self.NPCEntityFactory:SetModelRef(entity, model)
	end)

	return entity
end

-- Pick a spawn point using round-robin; wrap around if spawnIndex > #spawnPoints.
function SpawnEnemyWave:_PickSpawnPosition(spawnPoints: { any }, spawnIndex: number): Vector3
	-- Round-robin formula: ((index - 1) % count) + 1 gives 1-based index within bounds
	local spawnPoint = spawnPoints[((spawnIndex - 1) % #spawnPoints) + 1]
	return spawnPoint.Position or Vector3.new(0, 5, 0)
end

return SpawnEnemyWave
