--!strict

--[=[
	@class GenerateDungeon
	Application command: orchestrates dungeon generation from validation through player teleportation.
	@server
]=]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DungeonConfig = require(ReplicatedStorage.Contexts.Dungeon.Config.DungeonConfig)
local DungeonTypes = require(ReplicatedStorage.Contexts.Dungeon.Types.DungeonTypes)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok, Err, Try, Ensure = Result.Ok, Result.Err, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess

type TSpawnPoint = DungeonTypes.TSpawnPoint

--[=[
	@interface TGenerateDungeonResult
	@within GenerateDungeon
	.DungeonId string -- Unique ID for this dungeon instance
	.ZoneId string -- Zone where the dungeon was generated
	.TotalWaves number -- Total wave count for this dungeon
	.SpawnPoints { TSpawnPoint } -- Spawn points for the first area
	.StartSpawnPoints { TSpawnPoint } -- Spawn points for the start piece
	.StartModel Model -- The cloned Start piece model
]=]

export type TGenerateDungeonResult = {
	DungeonId: string,
	ZoneId: string,
	TotalWaves: number,
	SpawnPoints: { TSpawnPoint },
	StartSpawnPoints: { TSpawnPoint },
	StartModel: Model,
}

local GenerateDungeon = {}
GenerateDungeon.__index = GenerateDungeon

export type TGenerateDungeon = typeof(setmetatable({}, GenerateDungeon))

function GenerateDungeon.new(): TGenerateDungeon
	local self = setmetatable({}, GenerateDungeon)
	return self
end

function GenerateDungeon:Init(registry: any)
	self.GeneratePolicy = registry:Get("GeneratePolicy")
	self.DungeonSyncService = registry:Get("DungeonSyncService")
	self.DungeonInstanceService = registry:Get("DungeonInstanceService")
	self.SpawnPointService = registry:Get("SpawnPointService")
end

--[=[
	Execute dungeon generation: validate, create instances, extract spawn points, and teleport player.
	@within GenerateDungeon
	@param player Player -- The player entering the dungeon
	@param userId number -- The player's user ID
	@param zoneId string -- The zone to generate
	@param playerIndex number -- Unique index for this player's dungeon (for X-offset isolation)
	@return Result<TGenerateDungeonResult> -- Generation result with dungeon data, or error
]=]
function GenerateDungeon:Execute(
	player: Player,
	userId: number,
	zoneId: string,
	playerIndex: number
): Result.Result<TGenerateDungeonResult>
	Ensure(player ~= nil and userId > 0, "InvalidInput", Errors.PLAYER_NOT_FOUND)

	local ctx = Try(self.GeneratePolicy:Check(userId, zoneId))
	local totalWaves = ctx.TotalWaves

	-- Layer 2: Calculate base offset for player isolation
	local baseOffset = CFrame.new(playerIndex * DungeonConfig.PLAYER_X_OFFSET_SPACING, 0, 0)

	-- Layer 3: Create dungeon state (status = "Generating")
	local dungeonId = HttpService:GenerateGUID(false)
	self.DungeonSyncService:CreateDungeon(userId, {
		ZoneId = zoneId,
		CurrentWave = 0,
		TotalWaves = totalWaves,
		Status = "Generating",
	})

	-- Layer 4: Create Workspace folder and place Start piece
	self.DungeonInstanceService:CreateDungeon(userId, zoneId, baseOffset)

	local startModel = Try(Result.fromPcall("MissingStartPiece", function()
		return self.DungeonInstanceService:PlaceStartPiece(userId, zoneId)
	end):orElse(function(_err)
		self:_CleanupFailedDungeon(userId)
		return Err("MissingStartPiece", Errors.MISSING_START_PIECE, { userId = userId })
	end))

	-- Extract spawn points from Start piece for adventurer spawning
	local startSpawnPoints = self.SpawnPointService:ExtractSpawnPoints(startModel)

	-- Layer 5: Place first Area piece
	Try(Result.fromPcall("MissingAreaPieces", function()
		return self.DungeonInstanceService:PlaceAreaPiece(userId, zoneId)
	end):orElse(function(_err)
		self:_CleanupFailedDungeon(userId)
		return Err("MissingAreaPieces", Errors.MISSING_AREA_PIECES, { userId = userId })
	end))

	-- Layer 6: Extract spawn points for wave 1
	local currentArea = self.DungeonInstanceService:GetCurrentAreaModel(userId)
	local spawnPoints = {}
	if currentArea then
		spawnPoints = self.SpawnPointService:ExtractSpawnPoints(currentArea)
	end

	-- Layer 7: Update state to Active, wave 1
	self.DungeonSyncService:SetCurrentWave(userId, 1)
	self.DungeonSyncService:SetStatus(userId, "Active")

	-- Layer 8: Teleport player to Start piece's spawn location
	self:_TeleportPlayerToStart(player, startModel)

	-- Layer 9: Fire DungeonReady event
	GameEvents.Bus:Emit(Events.Dungeon.DungeonReady, userId, zoneId)
	MentionSuccess("Dungeon:GenerateDungeon:Execute", "Generated dungeon and activated first wave", {
		userId = userId,
		zoneId = zoneId,
		totalWaves = totalWaves,
	})

	return Ok({
		DungeonId = dungeonId,
		ZoneId = zoneId,
		TotalWaves = totalWaves,
		SpawnPoints = spawnPoints,
		StartSpawnPoints = startSpawnPoints,
		StartModel = startModel,
	})
end

-- Cleanup workspace instances and atom state when generation fails mid-process
function GenerateDungeon:_CleanupFailedDungeon(userId: number)
	self.DungeonInstanceService:DestroyDungeon(userId)
	self.DungeonSyncService:RemoveDungeonState(userId)
end

-- Teleport player to the Start piece's first spawn location, offset upward to prevent clipping
function GenerateDungeon:_TeleportPlayerToStart(player: Player, startModel: Model)
	local humanoidRootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then return end

	local spawnCFrame = self:_FindSpawnPoint(startModel)
	humanoidRootPart.CFrame = spawnCFrame + Vector3.new(0, 3, 0)
end

-- Find the first spawn location in the Start piece, or fall back to the model's center pivot
function GenerateDungeon:_FindSpawnPoint(startModel: Model): CFrame
	local spawnLocations = startModel:FindFirstChild("SpawnLocations")
	local firstSpawn = spawnLocations and spawnLocations:FindFirstChildOfClass("Part") :: BasePart?
	return if firstSpawn then firstSpawn.CFrame else startModel:GetPivot()
end

return GenerateDungeon
