--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess
local Events = GameEvents.Events

--[[
	UnlockTier

	Spends tokens to unlock the next commission tier,
	then regenerates the board with the new tier's board size.
]]

--[=[
	@class UnlockTier
	Application command that spends tokens to unlock the next commission tier and regenerates the board.
	@server
]=]
local UnlockTier = {}
UnlockTier.__index = UnlockTier

--[=[
	Construct a new UnlockTier service.
	@within UnlockTier
	@return UnlockTier
]=]
function UnlockTier.new()
	return setmetatable({}, UnlockTier)
end

--[=[
	Wire registry dependencies (called by Registry:InitAll).
	@within UnlockTier
	@param registry any -- The context registry
]=]
function UnlockTier:Init(registry: any)
	self.UnlockTierPolicy = registry:Get("UnlockTierPolicy")
	self.CommissionGenerator = registry:Get("CommissionGenerator")
	self.CommissionSyncService = registry:Get("CommissionSyncService")
	self.CommissionPersistenceService = registry:Get("CommissionPersistenceService")
end

--[=[
	Unlock the next commission tier for the player, deducting tokens and regenerating the board.
	@within UnlockTier
	@param player Player -- The player unlocking the tier
	@param userId number -- The player's UserId
	@return Result<boolean> -- `Ok(true)` on success
]=]
function UnlockTier:Execute(player: Player, userId: number): Result.Result<boolean>
	Ensure(player ~= nil and userId > 0, "InvalidInput", "Invalid player or userId")

	-- Validate tier unlock (check tokens and config)
	local ctx = Try(self.UnlockTierPolicy:Check(userId))

	-- Deduct tokens, update tier, regenerate board
	self:_ApplyTierUnlock(userId, ctx)

	-- Persist and sync to client
	self:_PersistAndHydrate(player, userId)

	-- Emit event for dependent systems (quest tracking, UI, etc.)
	GameEvents.Bus:Emit(Events.Commission.CommissionTierUnlocked, userId, ctx.NextTier)

	MentionSuccess("Commission:UnlockTier:Execute", "Unlocked next commission tier and regenerated board", {
		userId = userId,
		nextTier = ctx.NextTier,
		unlockCost = ctx.UnlockCost,
	})

	return Ok(true)
end

function UnlockTier:_ApplyTierUnlock(userId: number, ctx: { NextTier: number, UnlockCost: number, BoardSize: number })
	local state = self.CommissionSyncService:GetCommissionStateReadOnly(userId)

	-- Deduct unlock cost from token balance
	self.CommissionSyncService:SetTokens(userId, state.Tokens - ctx.UnlockCost)

	-- Update tier level
	self.CommissionSyncService:SetCurrentTier(userId, ctx.NextTier)

	-- Generate new board for the unlocked tier (respects active commissions)
	local updatedState = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	if updatedState then
		local board = self.CommissionGenerator:GenerateBoard(ctx.NextTier, ctx.BoardSize, updatedState.Active)
		self.CommissionSyncService:SetBoard(userId, board)
		self.CommissionSyncService:SetLastRefreshTime(userId, os.time())
	end
end

function UnlockTier:_PersistAndHydrate(player: Player, userId: number)
	-- Persist updated state to profile
	local finalState = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	if finalState then
		Try(self.CommissionPersistenceService:SaveCommissionData(player, finalState))
	end

	-- Sync state to client
	self.CommissionSyncService:HydratePlayer(player)
end

return UnlockTier
