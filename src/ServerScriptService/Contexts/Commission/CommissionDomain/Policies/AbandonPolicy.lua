--!strict

--[[
	AbandonPolicy — Domain Policy

	Answers: can this player abandon the given active commission?

	RESPONSIBILITIES:
	  1. Fetch the player's commission state from CommissionSyncService
	  2. Build a TAbandonCommissionCandidate from the fetched state + params
	  3. Evaluate the CanAbandonCommission spec against the candidate
	  4. Return Ok(nil) on success (command only needs commissionId to remove)

	RESULT:
	  Ok(nil) — abandon is valid
	  Err(...) — player not found or commission not in active list

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  Try(self.AbandonPolicy:Check(userId, commissionId))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommissionSpecs = require(script.Parent.Parent.Specs.CommissionSpecs)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

--[=[
	@class AbandonPolicy
	Domain policy that answers whether a player may abandon an active commission.
	@server
]=]
local AbandonPolicy = {}
AbandonPolicy.__index = AbandonPolicy

--[=[
	@type TAbandonPolicy typeof(setmetatable({}, AbandonPolicy))
	@within AbandonPolicy
]=]
export type TAbandonPolicy = typeof(setmetatable({}, AbandonPolicy))

--[=[
	Construct a new AbandonPolicy.
	@within AbandonPolicy
	@return TAbandonPolicy
]=]
function AbandonPolicy.new(): TAbandonPolicy
	return setmetatable({}, AbandonPolicy)
end

--[=[
	Wire registry dependencies (called by Registry:InitAll).
	@within AbandonPolicy
	@param registry any -- The context registry
]=]
function AbandonPolicy:Init(registry: any)
	self.CommissionSyncService = registry:Get("CommissionSyncService")
end

local function _IsCommissionInActive(active: { any }, commissionId: string): boolean
	for _, c in ipairs(active) do
		if c.Id == commissionId then
			return true
		end
	end
	return false
end

--[=[
	Evaluate whether the player may abandon the given commission.
	@within AbandonPolicy
	@param userId number -- The player's UserId
	@param commissionId string -- The ID of the commission to abandon
	@return Result<nil> -- `Ok(nil)` if abandon is valid, `Err` otherwise
]=]
function AbandonPolicy:Check(userId: number, commissionId: string): Result.Result<nil>
	local state = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	Ensure(state, "PlayerNotFound", Errors.PLAYER_NOT_FOUND)

	local candidate: CommissionSpecs.TAbandonCommissionCandidate = {
		CommissionIdValid  = commissionId ~= nil and commissionId ~= "",
		-- Defensive: passes when commissionId invalid — only the root error fires
		CommissionInActive = commissionId == nil or commissionId == "" or _IsCommissionInActive(state.Active, commissionId),
	}

	Try(CommissionSpecs.CanAbandonCommission:IsSatisfiedBy(candidate))

	return Ok(nil)
end

return AbandonPolicy
