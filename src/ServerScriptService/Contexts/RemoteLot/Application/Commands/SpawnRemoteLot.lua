--!strict

--[=[
	@class SpawnRemoteLot
	Application command that spawns a remote lot for a player.
	@server
]=]

--[[
	Spawns a remote lot for a player:
	  1. Allocate a grid slot for the player
	  2. Compute the CFrame from config origin + slot offset
	  3. Clone the remote lot template and position it
	  4. Register zone folders into the Lot ECS world so
	     LotContext's getters (GetFarmFolderForUser, etc.) resolve correctly
	  5. Track the model so it can be cleaned up on disconnect
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Err = Result.Ok, Result.Err
local MentionSuccess = Result.MentionSuccess

local RemoteLotConfig = require(ReplicatedStorage.Contexts.RemoteLot.Config.RemoteLotConfig)

local SpawnRemoteLot = {}
SpawnRemoteLot.__index = SpawnRemoteLot

export type TSpawnRemoteLot = typeof(setmetatable(
	{} :: {
		_tracker: any,
		_modelFactory: any,
		_entityFactory: any,
		_terrainTemplate: any,
		_revealService: any,
	},
	SpawnRemoteLot
))

function SpawnRemoteLot.new(): TSpawnRemoteLot
	local self = setmetatable({}, SpawnRemoteLot)
	self._tracker = nil :: any
	self._modelFactory = nil :: any
	self._entityFactory = nil :: any
	self._terrainTemplate = nil :: any
	self._revealService = nil :: any
	return self
end

function SpawnRemoteLot:Init(registry: any, _name: string)
	self._tracker = registry:Get("RemoteLotTracker")
	self._modelFactory = registry:Get("RemoteLotModelFactory")
	self._entityFactory = registry:Get("RemoteLotEntityFactory")
	self._terrainTemplate = registry:Get("RemoteLotTerrainTemplate")
	self._revealService = registry:Get("RemoteLotRevealService")
end

--[=[
	Spawns the remote lot for a player.
	Returns Err if the player already has one.
	@within SpawnRemoteLot
	@param player Player
	@return Result.Result<CFrame> -- the CFrame the remote lot was placed at
]=]
function SpawnRemoteLot:Execute(player: Player): Result.Result<CFrame>
	-- Guard: ensure player doesn't already have a remote lot
	if self._tracker:Has(player) then
		return Err("DUPLICATE_REMOTE_LOT", "Player already has a remote lot")
	end

	-- Step 1: Allocate a grid slot and compute placement CFrame
	local slot = self._tracker:AllocateSlot(player)
	local slotOffset = RemoteLotConfig.SlotStride * slot
	local cframe = RemoteLotConfig.RemoteLotOrigin * CFrame.new(slotOffset)
	local snappedPosition = self._terrainTemplate:GetSnappedPosition(cframe.Position)
	local snappedCFrame = CFrame.new(snappedPosition) * (cframe - cframe.Position)

	-- Step 2: Stamp terrain at the snapped position
	self._terrainTemplate:StampTerrain(snappedPosition)

	-- Step 3: Clone the remote lot model and position it
	local model = self._modelFactory:CreateRemoteLotModel(player.UserId, snappedCFrame)
	self._revealService:HideLockedAreas(model)
	self._tracker:SetModel(player, model)

	-- Step 4: Resolve spawn point (use explicit SpawnPoint if exists, otherwise offset from lot center)
	local spawnPoint = model:FindFirstChild("SpawnPoint", true) :: BasePart?
	local spawnCFrame = spawnPoint and spawnPoint.CFrame or snappedCFrame + Vector3.new(0, 5, 0)
	self._tracker:SetSpawnCFrame(player, spawnCFrame)

	-- Step 5: Create ECS entities and register zone folders into Lot world
	local entity = self._entityFactory:CreateRemoteLot(player.UserId, snappedCFrame)
	self._entityFactory:CreateZoneEntities(entity, model)
	MentionSuccess("RemoteLot:SpawnRemoteLot:Execute", "Spawned remote lot model and registered zone entities", {
		userId = player.UserId,
		slot = slot,
		modelName = model.Name,
	})

	return Ok(snappedCFrame)
end

return SpawnRemoteLot
