--!strict

--[=[
	@class DungeonContext
	Server-side Knit service that orchestrates dungeon generation, wave clearing, and cleanup.
	@server
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local BlinkServer = require(ReplicatedStorage.Network.Generated.DungeonSyncServer)
local Result = require(ReplicatedStorage.Utilities.Result)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)

local Catch = Result.Catch
local Ok = Result.Ok
local Try = Result.Try

-- Domain Services
local PieceAlignmentCalculator = require(script.Parent.DungeonDomain.Services.PieceAlignmentCalculator)

-- Domain Policies
local GeneratePolicy = require(script.Parent.DungeonDomain.Policies.GeneratePolicy)
local ClearWavePolicy = require(script.Parent.DungeonDomain.Policies.ClearWavePolicy)

-- Persistence Infrastructure
local DungeonSyncService = require(script.Parent.Infrastructure.Persistence.DungeonSyncService)

-- Infrastructure Services
local DungeonInstanceService = require(script.Parent.Infrastructure.Services.DungeonInstanceService)
local SpawnPointService = require(script.Parent.Infrastructure.Services.SpawnPointService)

-- Application Services
local GenerateDungeon = require(script.Parent.Application.Commands.GenerateDungeon)
local ClearWave = require(script.Parent.Application.Commands.ClearWave)
local DestroyDungeon = require(script.Parent.Application.Commands.DestroyDungeon)

local DungeonTypes = require(ReplicatedStorage.Contexts.Dungeon.Types.DungeonTypes)
type TSpawnPoint = DungeonTypes.TSpawnPoint
type TGenerateDungeonResult = GenerateDungeon.TGenerateDungeonResult
type TClearWaveResult = ClearWave.TClearWaveResult

local DungeonContext = Knit.CreateService({
	Name = "DungeonContext",
	Client = {},
})

---
-- Knit Lifecycle
---

function DungeonContext:KnitInit()
	local registry = Registry.new("Server")
	self.Registry = registry

	-- Register raw values
	registry:Register("BlinkServer", BlinkServer)

	-- Register services (zero-arg .new(); Init pulls deps from registry)
	registry:Register("GeneratePolicy", GeneratePolicy.new(), "Domain")
	registry:Register("ClearWavePolicy", ClearWavePolicy.new(), "Domain")
	registry:Register("PieceAlignmentCalculator", PieceAlignmentCalculator.new(), "Domain")
	registry:Register("DungeonSyncService", DungeonSyncService.new(), "Infrastructure")
	registry:Register("SpawnPointService", SpawnPointService.new(), "Infrastructure")
	registry:Register("DungeonInstanceService", DungeonInstanceService.new(), "Infrastructure")
	registry:Register("GenerateDungeon", GenerateDungeon.new(), "Application")
	registry:Register("ClearWave", ClearWave.new(), "Application")
	registry:Register("DestroyDungeon", DestroyDungeon.new(), "Application")

	registry:InitAll()

	-- Cache refs
	self.PieceAlignmentCalculator = registry:Get("PieceAlignmentCalculator")
	self.DungeonSyncService = registry:Get("DungeonSyncService")
	self.SpawnPointService = registry:Get("SpawnPointService")
	self.DungeonInstanceService = registry:Get("DungeonInstanceService")
	self.GenerateDungeonService = registry:Get("GenerateDungeon")
	self.ClearWaveService = registry:Get("ClearWave")
	self.DestroyDungeonService = registry:Get("DestroyDungeon")

	-- Tracking
	self.PlayerIndexCounter = 0
	self.SpawnPointCache = {} :: { [number]: { [number]: { any } } }
	self.StartModelCache = {} :: { [number]: Model }
end

function DungeonContext:KnitStart()
	-- Cross-context dependency: LotContext for return teleportation
	local LotContext = Knit.GetService("LotContext")
	self.LotContext = LotContext
	self.Registry:Register("LotContext", LotContext)
	self.Registry:StartAll()

	-- Cleanup on player leave
	Players.PlayerRemoving:Connect(function(player)
		self:DestroyDungeon(player, player.UserId)
	end)

	print("DungeonContext started")
end

--[=[
	Generate a dungeon for a player starting an expedition.
	@within DungeonContext
	@param player Player -- The player entering the dungeon
	@param userId number -- The player's user ID
	@param zoneId string -- The zone to generate
	@return Result<TGenerateDungeonResult> -- Dungeon data including spawn points and models
]=]
function DungeonContext:GenerateDungeon(player: Player, userId: number, zoneId: string): Result.Result<TGenerateDungeonResult>
	return Catch(function()
		local playerIndex = self:_GetNextPlayerIndex()
		local result = Try(self.GenerateDungeonService:Execute(player, userId, zoneId, playerIndex))

		-- Cache spawn points and start model if successful
		if result.SpawnPoints then
			if not self.SpawnPointCache[userId] then
				self.SpawnPointCache[userId] = {}
			end
			self.SpawnPointCache[userId][0] = result.StartSpawnPoints or {}
			self.SpawnPointCache[userId][1] = result.SpawnPoints
		end
		if result.StartModel then
			self.StartModelCache[userId] = result.StartModel
		end

		return result
	end, "Dungeon:GenerateDungeon")
end

--[=[
	Clear the current wave: destroy barrier, generate next area or end piece.
	@within DungeonContext
	@param userId number -- The player's user ID
	@return Result<TClearWaveResult> -- Wave data including next wave number or completion status
]=]
function DungeonContext:ClearWave(userId: number): Result.Result<TClearWaveResult>
	return Catch(function()
		local result = Try(self.ClearWaveService:Execute(userId))

		-- Cache spawn points for the new wave if successful
		if result.SpawnPoints and result.NextWave then
			if not self.SpawnPointCache[userId] then
				self.SpawnPointCache[userId] = {}
			end
			self.SpawnPointCache[userId][result.NextWave] = result.SpawnPoints
		end

		return result
	end, "Dungeon:ClearWave")
end

--[=[
	Destroy a player's dungeon: cleanup instances, remove state, teleport back.
	@within DungeonContext
	@param player Player? -- The player to teleport (may be nil on disconnect)
	@param userId number -- The player's user ID
	@return Result<nil> -- Success indicator
]=]
function DungeonContext:DestroyDungeon(player: Player?, userId: number): Result.Result<any>
	return Catch(function()
		-- Clear caches
		self.SpawnPointCache[userId] = nil
		self.StartModelCache[userId] = nil

		return self.DestroyDungeonService:Execute(player, userId)
	end, "Dungeon:DestroyDungeon")
end

--[=[
	Get the cached Start piece model for a player's dungeon.
	@within DungeonContext
	@param userId number -- The player's user ID
	@return Result<Model> -- The cached Start model
]=]
function DungeonContext:GetStartModel(userId: number): Result.Result<Model>
	return Ok(self.StartModelCache[userId])
end

--[=[
	Destroy the barrier on a specific piece model (e.g. the Start piece).
	@within DungeonContext
	@param pieceModel Model -- The piece model containing the barrier
	@return Result<boolean> -- Whether the barrier was found and destroyed
]=]
function DungeonContext:DestroyBarrierOnPiece(pieceModel: Model): Result.Result<boolean>
	return Catch(function()
		return self.DungeonInstanceService:DestroyBarrierOnPiece(pieceModel)
	end, "Dungeon:DestroyBarrierOnPiece")
end

--[=[
	Get cached spawn points for a specific wave, used to determine enemy placement.
	@within DungeonContext
	@param userId number -- The player's user ID
	@param waveNumber number -- The wave number (0 for Start, 1+ for areas)
	@return Result<{ TSpawnPoint }> -- Spawn points for the wave
]=]
function DungeonContext:GetSpawnPoints(userId: number, waveNumber: number): Result.Result<{ TSpawnPoint }>
	return Catch(function()
		return Result.RequirePath(self.SpawnPointCache, userId, waveNumber)
	end, "Dungeon:GetSpawnPoints")
end

--[=[
	Get the current area model for a player's dungeon.
	@within DungeonContext
	@param userId number -- The player's user ID
	@return Result<Model> -- The current area model, or nil
]=]
function DungeonContext:GetCurrentAreaModel(userId: number): Result.Result<Model>
	return Catch(function()
		return self.DungeonInstanceService:GetCurrentAreaModel(userId)
	end, "Dungeon:GetCurrentAreaModel")
end

-- Generate the next unique player index for dungeon isolation (increments with each new dungeon)
function DungeonContext:_GetNextPlayerIndex(): number
	self.PlayerIndexCounter += 1
	return self.PlayerIndexCounter
end

WrapContext(DungeonContext, "DungeonContext")

return DungeonContext
