--!strict

--[[
	AcceptPolicy — Domain Policy

	Answers: can this player accept the given commission from the board?

	RESPONSIBILITIES:
	  1. Fetch the player's commission state from CommissionSyncService
	  2. Build a TAcceptCommissionCandidate from the fetched state + params
	  3. Evaluate the CanAcceptCommission spec against the candidate
	  4. Return Ok({ State, Commission, BoardWithout }) so the command avoids
	     re-reading and re-scanning commission state

	RESULT:
	  Ok({ State, Commission, BoardWithout }) — accept is valid
	  Err(...) — player not found, max active reached, or commission not on board

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  local ctx = Try(self.AcceptPolicy:Check(userId, commissionId))
	  local commission = ctx.Commission
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommissionRewardConfig = require(ReplicatedStorage.Contexts.Commission.Config.CommissionRewardConfig)
local CommissionSpecs = require(script.Parent.Parent.Specs.CommissionSpecs)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

--[=[
	@class AcceptPolicy
	Domain policy that answers whether a player may accept a commission from the board.
	@server
]=]
local AcceptPolicy = {}
AcceptPolicy.__index = AcceptPolicy

--[=[
	@type TAcceptPolicy typeof(setmetatable({}, AcceptPolicy))
	@within AcceptPolicy
]=]
export type TAcceptPolicy = typeof(setmetatable({}, AcceptPolicy))

--[=[
	Construct a new AcceptPolicy.
	@within AcceptPolicy
	@return TAcceptPolicy
]=]
function AcceptPolicy.new(): TAcceptPolicy
	return setmetatable({}, AcceptPolicy)
end

--[=[
	Wire registry dependencies (called by Registry:InitAll).
	@within AcceptPolicy
	@param registry any -- The context registry
]=]
function AcceptPolicy:Init(registry: any)
	self.CommissionSyncService = registry:Get("CommissionSyncService")
end

--[=[
	Evaluate whether the player may accept the given commission and return data needed by the command.
	@within AcceptPolicy
	@param userId number -- The player's UserId
	@param commissionId string -- The ID of the board commission to accept
	@return Result<{State: any, Commission: any, BoardWithout: {any}}> -- Validated state and filtered board, or `Err`
]=]
function AcceptPolicy:Check(userId: number, commissionId: string): Result.Result<{ State: any, Commission: any, BoardWithout: { any } }>
	-- Fetch player's commission state (fails if not loaded)
	local state = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	Ensure(state, "PlayerNotFound", Errors.PLAYER_NOT_FOUND)

	-- Find commission and build filtered board in a single pass
	local commission = nil
	local boardWithout = {}
	for _, bc in ipairs(state.Board) do
		if bc.Id == commissionId then
			commission = bc
		else
			table.insert(boardWithout, bc)
		end
	end

	-- Build candidate for spec evaluation (check ID, slot availability, and board presence)
	local candidate: CommissionSpecs.TAcceptCommissionCandidate = {
		CommissionIdValid = commissionId ~= nil and commissionId ~= "",
		SlotAvailable     = #state.Active < CommissionRewardConfig.MAX_ACTIVE,
		-- Defensive: passes when commissionId invalid — only the root error fires
		CommissionOnBoard = commissionId == nil or commissionId == "" or commission ~= nil,
	}

	-- Evaluate all eligibility requirements
	Try(CommissionSpecs.CanAcceptCommission:IsSatisfiedBy(candidate))

	return Ok({ State = state, Commission = commission, BoardWithout = boardWithout })
end

return AcceptPolicy
