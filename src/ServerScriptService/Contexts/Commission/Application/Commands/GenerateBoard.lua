--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommissionTierConfig = require(ReplicatedStorage.Contexts.Commission.Config.CommissionTierConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok, Try, Ensure, fromNilable = Result.Ok, Result.Try, Result.Ensure, Result.fromNilable
local MentionSuccess = Result.MentionSuccess

--[[
	GenerateBoard

	Orchestrates board generation: calls domain generator, updates sync, persists.
]]

--[=[
	@class GenerateBoard
	Application command that generates a full commission board and persists it for a player.
	@server
]=]
local GenerateBoard = {}
GenerateBoard.__index = GenerateBoard

--[=[
	Construct a new GenerateBoard service.
	@within GenerateBoard
	@return GenerateBoard
]=]
function GenerateBoard.new()
	return setmetatable({}, GenerateBoard)
end

--[=[
	Wire registry dependencies (called by Registry:InitAll).
	@within GenerateBoard
	@param registry any -- The context registry
]=]
function GenerateBoard:Init(registry: any)
	self.CommissionGenerator = registry:Get("CommissionGenerator")
	self.CommissionSyncService = registry:Get("CommissionSyncService")
	self.CommissionPersistenceService = registry:Get("CommissionPersistenceService")
end

--[=[
	Generate a fresh commission board for the player based on their current tier and persist it.
	@within GenerateBoard
	@param player Player -- The player to generate a board for
	@param userId number -- The player's UserId
	@return Result<boolean> -- `Ok(true)` on success
]=]
function GenerateBoard:Execute(player: Player, userId: number): Result.Result<boolean>
	Ensure(player and userId > 0, "InvalidInput", "Invalid player or userId")

	-- Load player's commission state
	local state = Try(
		fromNilable(
			self.CommissionSyncService:GetCommissionStateReadOnly(userId),
			"PlayerNotFound",
			Errors.PLAYER_NOT_FOUND,
			{ userId = userId }
		)
	)

	-- Load tier config for board size
	local currentTier = state.CurrentTier
	local tierConfig = Try(
		fromNilable(
			CommissionTierConfig[currentTier],
			"InvalidTier",
			"Invalid tier configuration",
			{ tier = currentTier }
		)
	)

	-- Generate board with current tier, excluding active commissions
	local board = self.CommissionGenerator:GenerateBoard(currentTier, tierConfig.BoardSize, state.Active)

	-- Update state with new board and refresh time
	self.CommissionSyncService:SetBoard(userId, board)
	self.CommissionSyncService:SetLastRefreshTime(userId, os.time())

	-- Persist updated state to profile
	local updatedState = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	if updatedState then
		Try(self.CommissionPersistenceService:SaveCommissionData(player, updatedState))
	end

	-- Sync state to client
	self.CommissionSyncService:HydratePlayer(player)

	MentionSuccess("Commission:GenerateBoard:Execute", "Generated and persisted commission board", {
		userId = userId,
		currentTier = currentTier,
		boardSize = #board,
	})

	return Ok(true)
end

return GenerateBoard
