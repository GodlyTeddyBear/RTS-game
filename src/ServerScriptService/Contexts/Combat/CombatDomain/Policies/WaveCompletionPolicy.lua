--!strict

--[[
	WaveCompletionPolicy — Domain Policy

	Answers: has the wave or the party been completed/wiped?

	RESPONSIBILITIES:
	  1. Query alive enemies for this user (Infrastructure - NPCEntityFactory)
	  2. Query alive adventurers for this user (Infrastructure - NPCEntityFactory)
	  3. Build a TWaveCompletionCandidate and evaluate specs
	  4. Return the completion status

	RESULT:
	  Ok({ Status }) where Status is "WaveComplete" | "PartyWiped" | "InProgress"

	USAGE:
	  -- At end of combat tick:
	  local ctx = self._waveCompletionPolicy:Check(userId)
	  if ctx.Status == "WaveComplete" then ...
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok = Result.Ok

local CombatSpecs = require(script.Parent.Parent.Specs.CombatSpecs)

local WaveCompletionPolicy = {}
WaveCompletionPolicy.__index = WaveCompletionPolicy

export type TWaveCompletionPolicy = typeof(setmetatable(
	{} :: {
		_npcEntityFactory: any,
	},
	WaveCompletionPolicy
))

export type TWaveCompletionPolicyResult = {
	Status: string,
}

function WaveCompletionPolicy.new(): TWaveCompletionPolicy
	local self = setmetatable({}, WaveCompletionPolicy)
	self._npcEntityFactory = nil :: any
	return self
end

function WaveCompletionPolicy:Start(registry: any, _name: string)
	self._npcEntityFactory = registry:Get("NPCEntityFactory")
end

function WaveCompletionPolicy:Check(userId: number): TWaveCompletionPolicyResult
	local aliveEnemies = self._npcEntityFactory:QueryAliveEnemies(userId)
	local aliveAdventurers = self._npcEntityFactory:QueryAliveAdventurers(userId)

	local candidate: CombatSpecs.TWaveCompletionCandidate = {
		AllEnemiesDead = #aliveEnemies == 0,
		AllAdventurersDead = #aliveAdventurers == 0,
	}

	local waveResult = CombatSpecs.IsWaveComplete:IsSatisfiedBy(candidate)
	if waveResult.success then
		return { Status = "WaveComplete" }
	end

	local partyResult = CombatSpecs.IsPartyWiped:IsSatisfiedBy(candidate)
	if partyResult.success then
		return { Status = "PartyWiped" }
	end

	return { Status = "InProgress" }
end

return WaveCompletionPolicy
