--!strict

--[[
	CleanupPolicy — Domain Policy

	Answers: is this player in a state that permits cleaning up their lot?

	RESPONSIBILITIES:
	  1. Fetch the player's lot entity from Infrastructure (LotEntityFactory)
	  2. Build a TCleanupCandidate from that state
	  3. Evaluate the CanCleanup spec against the candidate
	  4. Return the fetched entity on success (avoids double-read by the caller)

	RESULT:
	  Ok({ Entity })  — player has an active lot entity that can be cleaned up
	  Err(...)        — no lot entity found for this player

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  local ctx = Try(self._cleanupPolicy:Check(player))
	  self._syncService:DeleteEntity(ctx.Entity)
]]

--[=[
	@class CleanupPolicy
	Domain policy for evaluating lot cleanup eligibility.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

local LotSpecs = require(script.Parent.Parent.Specs.LotSpecs)

local CleanupPolicy = {}
CleanupPolicy.__index = CleanupPolicy

export type TCleanupPolicy = typeof(setmetatable(
	{} :: {
		_entityFactory: any,
	},
	CleanupPolicy
))

--[=[
	@interface TCleanupPolicyResult
	@within CleanupPolicy
	.Entity any -- The lot entity that can be cleaned up
]=]
export type TCleanupPolicyResult = {
	Entity: any,
}

--[=[
	Create a new CleanupPolicy instance.
	@within CleanupPolicy
	@return TCleanupPolicy -- Service instance
]=]
function CleanupPolicy.new(): TCleanupPolicy
	local self = setmetatable({}, CleanupPolicy)
	self._entityFactory = nil :: any
	return self
end

--[=[
	Initialize with injected dependencies.
	@within CleanupPolicy
	@param registry any -- Registry to resolve dependencies from
	@param _name string -- Service name (unused)
]=]
function CleanupPolicy:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("LotEntityFactory")
end

--[=[
	Evaluate whether a player's lot can be cleaned up.
	@within CleanupPolicy
	@param player Player -- The player whose lot to check
	@return Result<TCleanupPolicyResult> -- Ok(result) with entity if eligible, Err if no lot found
]=]
function CleanupPolicy:Check(player: Player): Result.Result<TCleanupPolicyResult>
	local entity = self._entityFactory:FindVillageLotByUserId(player.UserId)

	local candidate: LotSpecs.TCleanupCandidate = {
		Entity = entity,
	}

	Try(LotSpecs.CanCleanup:IsSatisfiedBy(candidate))

	return Ok({
		Entity = entity,
	})
end

return CleanupPolicy
