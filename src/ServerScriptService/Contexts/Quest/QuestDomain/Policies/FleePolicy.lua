--!strict

--[[
	FleePolicy — Domain Policy

	Answers: is this player in a state that permits fleeing their expedition?

	RESPONSIBILITIES:
	  1. Fetch active expedition state from Infrastructure (QuestSyncService)
	  2. Build a TFleeCandidate from that state
	  3. Evaluate the CanFlee spec against the candidate
	  4. Return Ok(nil) on success (no state needed by the command beyond the check)

	RESULT:
	  Ok(nil)   — player has an active expedition currently in combat
	  Err(...)  — no expedition, or expedition is not in combat

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  Try(self._fleePolicy:Check(userId))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

local QuestSpecs = require(script.Parent.Parent.Specs.QuestSpecs)

local FleePolicy = {}
FleePolicy.__index = FleePolicy

export type TFleePolicy = typeof(setmetatable(
	{} :: {
		_questSyncService: any,
	},
	FleePolicy
))

function FleePolicy.new(): TFleePolicy
	local self = setmetatable({}, FleePolicy)
	self._questSyncService = nil :: any
	return self
end

function FleePolicy:Init(registry: any, _name: string)
	self._questSyncService = registry:Get("QuestSyncService")
end

function FleePolicy:Check(userId: number): Result.Result<nil>
	local activeExpedition = self._questSyncService:GetActiveExpeditionReadOnly(userId)

	local candidate: QuestSpecs.TFleeCandidate = {
		ExpeditionExists   = activeExpedition ~= nil,
		-- Pass when expedition is nil — ExpeditionExists:And short-circuits before this runs
		ExpeditionInCombat = activeExpedition ~= nil and activeExpedition.Status == "InCombat",
	}

	Try(QuestSpecs.CanFlee:IsSatisfiedBy(candidate))

	return Ok(nil)
end

return FleePolicy
