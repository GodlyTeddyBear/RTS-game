--!strict

--[[
	UnlockTierPolicy — Domain Policy

	Answers: can this player unlock the next commission tier?

	RESPONSIBILITIES:
	  1. Fetch the player's commission state from CommissionSyncService
	  2. Build a TUnlockTierCandidate from the fetched state + TierConfig
	  3. Evaluate the CanUnlockTier spec against the candidate
	  4. Return Ok({ NextTier, UnlockCost }) so the command avoids re-reading config

	RESULT:
	  Ok({ NextTier, UnlockCost }) — unlock is valid; tier and cost returned for command use
	  Err(...)                     — player not found, already at max tier, or insufficient tokens

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  local ctx = Try(self.UnlockTierPolicy:Check(userId))
	  local nextTier   = ctx.NextTier
	  local unlockCost = ctx.UnlockCost
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommissionTierConfig = require(ReplicatedStorage.Contexts.Commission.Config.CommissionTierConfig)
local CommissionSpecs = require(script.Parent.Parent.Specs.CommissionSpecs)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

--[=[
	@class UnlockTierPolicy
	Domain policy that answers whether a player may unlock the next commission tier.
	@server
]=]
local UnlockTierPolicy = {}
UnlockTierPolicy.__index = UnlockTierPolicy

--[=[
	@type TUnlockTierPolicy typeof(setmetatable({}, UnlockTierPolicy))
	@within UnlockTierPolicy
]=]
export type TUnlockTierPolicy = typeof(setmetatable({}, UnlockTierPolicy))

--[=[
	Construct a new UnlockTierPolicy.
	@within UnlockTierPolicy
	@return TUnlockTierPolicy
]=]
function UnlockTierPolicy.new(): TUnlockTierPolicy
	return setmetatable({}, UnlockTierPolicy)
end

--[=[
	Wire registry dependencies (called by Registry:InitAll).
	@within UnlockTierPolicy
	@param registry any -- The context registry
]=]
function UnlockTierPolicy:Init(registry: any)
	self.CommissionSyncService = registry:Get("CommissionSyncService")
	self._registry = registry
end

function UnlockTierPolicy:Start()
	self.UnlockContext = self._registry:Get("UnlockContext")
end

--[=[
	Evaluate whether the player may unlock the next tier and return the tier data needed by the command.
	@within UnlockTierPolicy
	@param userId number -- The player's UserId
	@return Result<{NextTier: number, UnlockCost: number, BoardSize: number}> -- Validated tier data, or `Err`
]=]
function UnlockTierPolicy:Check(userId: number): Result.Result<{ NextTier: number, UnlockCost: number, BoardSize: number }>
	-- Fetch player's commission state (fails if not loaded)
	local state = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	Ensure(state, "PlayerNotFound", Errors.PLAYER_NOT_FOUND)

	-- Calculate next tier and look up its config
	local nextTier = state.CurrentTier + 1
	local nextTierConfig = CommissionTierConfig[nextTier]

	-- Check if tier is unlocked by UnlockContext (story progression gate)
	local tierTargetId = "CommissionTier" .. tostring(nextTier)
	Ensure(self.UnlockContext:IsUnlocked(userId, tierTargetId), "TierLocked", Errors.TIER_LOCKED)

	-- Build candidate for spec evaluation (check tier exists and sufficient tokens)
	local candidate: CommissionSpecs.TUnlockTierCandidate = {
		NextTierExists   = nextTierConfig ~= nil,
		-- Defensive: passes when tier doesn't exist — only the root error fires
		SufficientTokens = nextTierConfig == nil or state.Tokens >= nextTierConfig.UnlockCost,
	}

	-- Evaluate all eligibility requirements
	Try(CommissionSpecs.CanUnlockTier:IsSatisfiedBy(candidate))

	return Ok({ NextTier = nextTier, UnlockCost = nextTierConfig.UnlockCost, BoardSize = nextTierConfig.BoardSize })
end

return UnlockTierPolicy
