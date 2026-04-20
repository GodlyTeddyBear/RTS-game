--!strict

--[=[
	@class ClearWavePolicy
	Validates wave clearing eligibility for an active dungeon.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DungeonSpecs = require(script.Parent.Parent.Specs.DungeonSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

local ClearWavePolicy = {}
ClearWavePolicy.__index = ClearWavePolicy

export type TClearWavePolicy = typeof(setmetatable({}, ClearWavePolicy))

function ClearWavePolicy.new(): TClearWavePolicy
	return setmetatable({}, ClearWavePolicy)
end

function ClearWavePolicy:Init(registry: any)
	self.DungeonSyncService = registry:Get("DungeonSyncService")
end

--[=[
	Check if the current wave can be cleared for a player's dungeon.
	@within ClearWavePolicy
	@param userId number -- The player's user ID
	@return Result<{ State: DungeonState }> -- Full dungeon state if valid, error if no dungeon or wave out of range
]=]
function ClearWavePolicy:Check(userId: number): Result.Result<{ State: any }>
	local state = self.DungeonSyncService:GetDungeonStateReadOnly(userId)
	Ensure(state, "NoActiveDungeon", Errors.NO_ACTIVE_DUNGEON)

	local isActive = state.Status == "Active"

	local candidate: DungeonSpecs.TClearWaveCandidate = {
		DungeonActive = isActive,
		-- Defensive: passes when not active — DungeonActive:And short-circuits first
		WaveInRange   = not isActive
			or (state.CurrentWave >= 1 and state.CurrentWave <= state.TotalWaves),
	}

	Try(DungeonSpecs.CanClearWave:IsSatisfiedBy(candidate))

	return Ok({ State = state })
end

return ClearWavePolicy
