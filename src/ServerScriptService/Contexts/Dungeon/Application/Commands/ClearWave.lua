--!strict

--[=[
	@class ClearWave
	Application command: orchestrates wave clearing, barrier destruction, and area generation.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DungeonTypes = require(ReplicatedStorage.Contexts.Dungeon.Types.DungeonTypes)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok, Err, Try = Result.Ok, Result.Err, Result.Try
local MentionSuccess = Result.MentionSuccess

type TSpawnPoint = DungeonTypes.TSpawnPoint

--[=[
	@interface TClearWaveResult
	@within ClearWave
	.NextWave number? -- The next wave number, or nil if dungeon complete
	.IsComplete boolean -- Whether the dungeon is now complete
	.SpawnPoints { TSpawnPoint }? -- Spawn points for the next wave, or nil if complete
]=]

export type TClearWaveResult = {
	NextWave: number?,
	IsComplete: boolean,
	SpawnPoints: { TSpawnPoint }?,
}

local ClearWave = {}
ClearWave.__index = ClearWave

export type TClearWave = typeof(setmetatable({}, ClearWave))

function ClearWave.new(): TClearWave
	local self = setmetatable({}, ClearWave)
	return self
end

function ClearWave:Init(registry: any)
	self.ClearWavePolicy = registry:Get("ClearWavePolicy")
	self.DungeonSyncService = registry:Get("DungeonSyncService")
	self.DungeonInstanceService = registry:Get("DungeonInstanceService")
	self.SpawnPointService = registry:Get("SpawnPointService")
end

--[=[
	Execute wave clearing: destroy barrier, generate next area or end piece, and emit events.
	@within ClearWave
	@param userId number -- The player's user ID
	@return Result<TClearWaveResult> -- Clearing result with next wave data, or error
]=]
function ClearWave:Execute(userId: number): Result.Result<TClearWaveResult>
	local ctx = Try(self.ClearWavePolicy:Check(userId))
	local state = ctx.State

	-- Destroy barrier in current area
	self.DungeonInstanceService:DestroyBarrier(userId)

	local currentWave = state.CurrentWave
	local totalWaves = state.TotalWaves
	local zoneId = state.ZoneId

	-- Layer 4: Determine what comes next
	if currentWave < totalWaves then
		-- Generate next area piece
		self.DungeonSyncService:SetStatus(userId, "WaveClearing")

		Try(Result.fromPcall("MissingAreaPieces", function()
			return self.DungeonInstanceService:PlaceAreaPiece(userId, zoneId)
		end):orElse(function(_err)
			self.DungeonSyncService:SetStatus(userId, "Active")
			return Err("MissingAreaPieces", Errors.MISSING_AREA_PIECES, { userId = userId })
		end))

		-- Extract spawn points for next wave
		local currentArea = self.DungeonInstanceService:GetCurrentAreaModel(userId)
		local spawnPoints = {}
		if currentArea then
			spawnPoints = self.SpawnPointService:ExtractSpawnPoints(currentArea)
		end

		-- Update state
		local nextWave = currentWave + 1
		self.DungeonSyncService:SetCurrentWave(userId, nextWave)
		self.DungeonSyncService:SetStatus(userId, "Active")

		-- Fire event
		GameEvents.Bus:Emit(Events.Dungeon.WaveAreaGenerated, userId, nextWave, zoneId)
		MentionSuccess("Dungeon:ClearWave:Execute", "Cleared wave and generated next wave area", {
			userId = userId,
			nextWave = nextWave,
			zoneId = zoneId,
		})

		return Ok({
			NextWave = nextWave,
			IsComplete = false,
			SpawnPoints = spawnPoints,
		})
	else
		-- Final wave cleared — generate End piece
		Try(Result.fromPcall("MissingEndPiece", function()
			return self.DungeonInstanceService:PlaceEndPiece(userId, zoneId)
		end):orElse(function(_err)
			return Err("MissingEndPiece", Errors.MISSING_END_PIECE, { userId = userId })
		end))

		-- Update state
		self.DungeonSyncService:SetStatus(userId, "Complete")

		-- Fire event
		GameEvents.Bus:Emit(Events.Dungeon.DungeonComplete, userId, zoneId)
		MentionSuccess("Dungeon:ClearWave:Execute", "Cleared final wave and marked dungeon complete", {
			userId = userId,
			zoneId = zoneId,
		})

		return Ok({
			NextWave = nil,
			IsComplete = true,
		})
	end
end

return ClearWave
