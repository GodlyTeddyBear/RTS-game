--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommissionTierConfig = require(ReplicatedStorage.Contexts.Commission.Config.CommissionTierConfig)
local CommissionRewardConfig = require(ReplicatedStorage.Contexts.Commission.Config.CommissionRewardConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok, Try, Ensure, fromNilable = Result.Ok, Result.Try, Result.Ensure, Result.fromNilable
local MentionSuccess = Result.MentionSuccess

--[[
	RefreshBoard

	Filters out expired board entries, generates replacements,
	and merges them with non-expired entries.
]]

--[=[
	@class RefreshBoard
	Application command that replaces expired commission board entries with newly generated ones.
	@server
]=]
local RefreshBoard = {}
RefreshBoard.__index = RefreshBoard

--[=[
	Construct a new RefreshBoard service.
	@within RefreshBoard
	@return RefreshBoard
]=]
function RefreshBoard.new()
	return setmetatable({}, RefreshBoard)
end

--[=[
	Wire registry dependencies (called by Registry:InitAll).
	@within RefreshBoard
	@param registry any -- The context registry
]=]
function RefreshBoard:Init(registry: any)
	self.CommissionGenerator = registry:Get("CommissionGenerator")
	self.CommissionSyncService = registry:Get("CommissionSyncService")
	self.CommissionPersistenceService = registry:Get("CommissionPersistenceService")
end

--[=[
	Return whether the player's board has exceeded the refresh interval.
	@within RefreshBoard
	@param userId number -- The player's UserId
	@return boolean -- `true` if a refresh is due
]=]
function RefreshBoard:NeedsRefresh(userId: number): boolean
	local state = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	if not state then
		return false
	end

	return (os.time() - state.LastRefreshTime) >= CommissionRewardConfig.REFRESH_INTERVAL
end

--[=[
	Force a full board refresh, discarding all existing entries and regenerating from scratch.
	@within RefreshBoard
	@param player Player -- The player whose board to refresh
	@param userId number -- The player's UserId
	@return Result<boolean> -- `Ok(true)` on success
]=]
function RefreshBoard:ExecuteForce(player: Player, userId: number): Result.Result<boolean>
	Ensure(player ~= nil and userId > 0, "InvalidInput", "Invalid player or userId")

	local loaded = Try(self:_LoadStateAndTier(userId))
	local state: any = loaded.State
	local tierConfig: any = loaded.TierConfig
	local now = os.time()

	local newEntries = self.CommissionGenerator:GenerateBoard(state.CurrentTier, tierConfig.BoardSize, state.Active)
	self:_ApplyRefreshedBoard(userId, newEntries, now)
	self:_PersistAndHydrate(player, userId)
	MentionSuccess("Commission:RefreshBoard:ExecuteForce", "Force refreshed entire commission board", {
		userId = userId,
		boardSize = #newEntries,
	})

	return Ok(true)
end

--[=[
	Refresh the board by replacing only expired entries, keeping non-expired ones.
	@within RefreshBoard
	@param player Player -- The player whose board to refresh
	@param userId number -- The player's UserId
	@return Result<boolean> -- `Ok(true)` on success
]=]
function RefreshBoard:Execute(player: Player, userId: number): Result.Result<boolean>
	Ensure(player ~= nil and userId > 0, "InvalidInput", "Invalid player or userId")

	-- Load state and tier config
	local loaded = Try(self:_LoadStateAndTier(userId))
	local state: any = loaded.State
	local tierConfig: any = loaded.TierConfig
	local now = os.time()

	-- Filter out expired entries; keep non-expired ones
	local keptEntries = self:_FilterNonExpiredEntries(state.Board, now)
	local slotsToFill = tierConfig.BoardSize - #keptEntries

	-- If no slots available, just update timestamp and return
	if slotsToFill <= 0 then
		self.CommissionSyncService:SetLastRefreshTime(userId, now)
		self.CommissionSyncService:HydratePlayer(player)
		MentionSuccess("Commission:RefreshBoard:Execute", "Commission board refresh skipped; no expired entries", {
			userId = userId,
		})
		return Ok(true)
	end

	-- Generate new entries for open slots and merge with kept entries
	local newEntries = self.CommissionGenerator:GenerateBoard(state.CurrentTier, slotsToFill, state.Active)
	self:_ApplyRefreshedBoard(userId, self:_MergeEntries(keptEntries, newEntries), now)
	self:_PersistAndHydrate(player, userId)

	MentionSuccess("Commission:RefreshBoard:Execute", "Refreshed expired commission board entries", {
		userId = userId,
		refreshedCount = #newEntries,
	})

	return Ok(true)
end

function RefreshBoard:_LoadStateAndTier(userId: number): Result.Result<any>
	local state = Try(fromNilable(
		self.CommissionSyncService:GetCommissionStateReadOnly(userId),
		"PlayerNotFound",
		Errors.PLAYER_NOT_FOUND,
		{ userId = userId }
	))
	local tierConfig = Try(fromNilable(
		CommissionTierConfig[state.CurrentTier],
		"InvalidTier",
		"Invalid tier configuration",
		{ tier = state.CurrentTier }
	))

	return Ok({ State = state, TierConfig = tierConfig })
end

function RefreshBoard:_FilterNonExpiredEntries(board: { any }, now: number): { any }
	local kept = {}

	-- Keep entries whose expiration time hasn't passed
	for _, entry in ipairs(board) do
		if entry.ExpiresAt > now then
			table.insert(kept, entry)
		end
	end

	return kept
end

function RefreshBoard:_MergeEntries(keptEntries: { any }, newEntries: { any }): { any }
	local merged = table.clone(keptEntries)

	-- Append newly generated entries to kept entries
	for _, entry in ipairs(newEntries) do
		table.insert(merged, entry)
	end

	return merged
end

function RefreshBoard:_ApplyRefreshedBoard(userId: number, mergedBoard: { any }, now: number)
	self.CommissionSyncService:SetBoard(userId, mergedBoard)
	self.CommissionSyncService:SetLastRefreshTime(userId, now)
end

function RefreshBoard:_PersistAndHydrate(player: Player, userId: number)
	-- Persist updated state to profile
	local updatedState: any = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	if updatedState then
		Try(self.CommissionPersistenceService:SaveCommissionData(player, updatedState))
	end

	-- Sync state to client
	self.CommissionSyncService:HydratePlayer(player)
end

return RefreshBoard
