--!strict

--[=[
	@class GeneratePolicy
	Validates dungeon generation eligibility for a player and zone.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ZoneConfig = require(ReplicatedStorage.Contexts.Quest.Config.ZoneConfig)
local DungeonSpecs = require(script.Parent.Parent.Specs.DungeonSpecs)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

local GeneratePolicy = {}
GeneratePolicy.__index = GeneratePolicy

export type TGeneratePolicy = typeof(setmetatable({}, GeneratePolicy))

function GeneratePolicy.new(): TGeneratePolicy
	return setmetatable({}, GeneratePolicy)
end

function GeneratePolicy:Init(registry: any)
	self.DungeonSyncService = registry:Get("DungeonSyncService")
end

--[=[
	Check if a dungeon can be generated for a player in a zone.
	@within GeneratePolicy
	@param userId number -- The player's user ID
	@param zoneId string -- The zone ID to generate
	@return Result<{ TotalWaves: number }> -- Wave count if valid, error if zone missing or dungeon already active
]=]
function GeneratePolicy:Check(userId: number, zoneId: string): Result.Result<{ TotalWaves: number }>
	local hasActiveDungeon = self.DungeonSyncService:HasActiveDungeon(userId)
	local zoneData = ZoneConfig[zoneId]

	local candidate: DungeonSpecs.TGenerateDungeonCandidate = {
		ZoneExists      = zoneData ~= nil,
		-- Defensive: passes when zone unknown — ZoneExists:And short-circuits first
		NoDungeonActive = zoneData == nil or not hasActiveDungeon,
	}

	Try(DungeonSpecs.CanGenerateDungeon:IsSatisfiedBy(candidate))

	return Ok({ TotalWaves = zoneData.WaveCount })
end

return GeneratePolicy
