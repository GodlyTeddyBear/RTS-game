--!strict

--[=[
	@class CleanupRemoteLot
	Application command that tears down a player's remote lot on disconnect.
	@server
]=]

--[[
	Tears down a player's remote lot on disconnect:
	  1. Destroy the Roblox model
	  2. Delete the ECS entity (cascades to zone children)
	  3. Free the grid slot
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Err = Result.Ok, Result.Err
local MentionSuccess = Result.MentionSuccess

local RemoteLotConfig = require(ReplicatedStorage.Contexts.RemoteLot.Config.RemoteLotConfig)

local CleanupRemoteLot = {}
CleanupRemoteLot.__index = CleanupRemoteLot

export type TCleanupRemoteLot = typeof(setmetatable(
	{} :: {
		_tracker: any,
		_modelFactory: any,
		_entityFactory: any,
		_terrainTemplate: any,
	},
	CleanupRemoteLot
))

function CleanupRemoteLot.new(): TCleanupRemoteLot
	local self = setmetatable({}, CleanupRemoteLot)
	self._tracker = nil :: any
	self._modelFactory = nil :: any
	self._entityFactory = nil :: any
	self._terrainTemplate = nil :: any
	return self
end

function CleanupRemoteLot:Init(registry: any, _name: string)
	self._tracker = registry:Get("RemoteLotTracker")
	self._modelFactory = registry:Get("RemoteLotModelFactory")
	self._entityFactory = registry:Get("RemoteLotEntityFactory")
	self._terrainTemplate = registry:Get("RemoteLotTerrainTemplate")
end

--[=[
	Cleans up the remote lot for a player.
	@within CleanupRemoteLot
	@param player Player
	@return Result.Result<nil>
]=]
function CleanupRemoteLot:Execute(player: Player): Result.Result<nil>
	-- Guard: ensure player has a remote lot to clean up
	if not self._tracker:Has(player) then
		return Err("NO_REMOTE_LOT", "Player has no remote lot to clean up")
	end

	-- Step 1: Destroy the Roblox model and clear tracker references
	local model = self._tracker:GetModel(player)
	assert(model, "[CleanupRemoteLot] Tracker reports lot exists but model is missing")
	self._modelFactory:DestroyRemoteLotModel(model)
	self._tracker:ClearModel(player)
	self._tracker:ClearSpawnCFrame(player)

	-- Step 2: Delete the ECS entity (cascades to zone children)
	local entity = self._entityFactory:FindRemoteLotByUserId(player.UserId)
	assert(entity, "[CleanupRemoteLot] Tracker reports lot exists but ECS entity is missing")
	self._entityFactory:DeleteRemoteLot(entity)

	-- Step 3: Free the grid slot and clear terrain
	local slot = self._tracker:GetSlot(player)
	self._tracker:FreeSlot(player)

	if slot ~= nil then
		local slotOffset = RemoteLotConfig.SlotStride * slot
		local lotCFrame = RemoteLotConfig.RemoteLotOrigin * CFrame.new(slotOffset)
		self._terrainTemplate:ClearTerrain(lotCFrame.Position)
	end
	MentionSuccess("RemoteLot:CleanupRemoteLot:Execute", "Cleaned remote lot resources and released slot", {
		userId = player.UserId,
	})

	return Ok(nil)
end

return CleanupRemoteLot
