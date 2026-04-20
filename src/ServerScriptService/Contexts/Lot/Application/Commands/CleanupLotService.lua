--!strict

--[[
	Cleanup Lot Service - Orchestrate lot cleanup workflow

	Responsibility: Coordinate the cleanup process:
	1. Policy check — player has an active lot entity (Infrastructure via Policy)
	2. Delete GameObject (Infrastructure)
	3. Delete entity (Infrastructure)
	4. Remove tracking (Application)

	Constructor injection for all dependencies.
	Returns Result pattern.
]]

--[=[
	@class CleanupLotService
	Orchestrates the lot cleanup workflow with policy checks and entity deletion.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try, fromPcall = Result.Ok, Result.Try, Result.fromPcall
local MentionSuccess = Result.MentionSuccess

local CleanupLotService = {}
CleanupLotService.__index = CleanupLotService

export type CleanupLotService = typeof(setmetatable(
	{} :: {
		_cleanupPolicy: any,
		_entityFactory: any,
		_syncService: any,
		_playersWithLots: { [any]: any },
	},
	CleanupLotService
))

--[=[
	Create a new CleanupLotService instance.
	@within CleanupLotService
	@return CleanupLotService -- Service instance
]=]
function CleanupLotService.new(): CleanupLotService
	local self = setmetatable({}, CleanupLotService)
	return self
end

--[=[
	Initialize with injected dependencies.
	@within CleanupLotService
	@param registry any -- Registry to resolve dependencies from
]=]
function CleanupLotService:Init(registry: any)
	self._cleanupPolicy = registry:Get("CleanupPolicy")
	self._entityFactory = registry:Get("LotEntityFactory")
	self._syncService = registry:Get("GameObjectSyncService")
	self._playersWithLots = registry:Get("PlayersWithLots")
end

--[=[
	Execute the lot cleanup workflow for a player.
	@within CleanupLotService
	@param player Player -- The player whose lot should be cleaned up
	@return Result<boolean> -- Ok(true) on successful cleanup, Err on failure
]=]
function CleanupLotService:Execute(player: Player): Result.Result<boolean>
	local userId = player.UserId

	-- Policy: fetch entity + check player has active lot
	local ctx = Try(self._cleanupPolicy:Check(player))

	-- Delete GameObject and entity
	Try(fromPcall("CleanupFailed", function()
		self._syncService:DeleteEntity(ctx.Entity)
		self._entityFactory:DeleteLot(ctx.Entity)
	end))

	-- Remove tracking
	self._playersWithLots[player] = nil
	MentionSuccess("Lot:CleanupLotService:Execute", "Deleted lot entity and cleared active lot tracking", {
		userId = userId,
	})

	return Ok(true)
end

return CleanupLotService
