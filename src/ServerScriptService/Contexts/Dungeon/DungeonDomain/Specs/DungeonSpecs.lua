--!strict

--[=[
	@class DungeonSpecs
	Composable eligibility rules for dungeon generation and wave clearing.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

-- Candidate types

--[=[
	@interface TGenerateDungeonCandidate
	@within DungeonSpecs
	.ZoneExists boolean -- Zone ID exists in ZoneConfig
	.NoDungeonActive boolean -- Player has no currently active dungeon
]=]
export type TGenerateDungeonCandidate = {
	ZoneExists: boolean,
	NoDungeonActive: boolean,
}

--[=[
	@interface TClearWaveCandidate
	@within DungeonSpecs
	.DungeonActive boolean -- Current dungeon status is "Active"
	.WaveInRange boolean -- Current wave number is within [1, totalWaves]
]=]
export type TClearWaveCandidate = {
	DungeonActive: boolean,
	WaveInRange: boolean,
}

-- Individual specs — Generate dungeon

local ZoneExists = Spec.new("ZoneNotFound", Errors.ZONE_NOT_FOUND,
	function(ctx: TGenerateDungeonCandidate) return ctx.ZoneExists end
)

local NoDungeonActive = Spec.new("DungeonAlreadyActive", Errors.DUNGEON_ALREADY_ACTIVE,
	function(ctx: TGenerateDungeonCandidate) return ctx.NoDungeonActive end
)

-- Individual specs — Clear wave

local DungeonActive = Spec.new("DungeonNotActive", Errors.DUNGEON_NOT_ACTIVE,
	function(ctx: TClearWaveCandidate) return ctx.DungeonActive end
)

local WaveInRange = Spec.new("WaveOutOfRange", Errors.WAVE_OUT_OF_RANGE,
	function(ctx: TClearWaveCandidate) return ctx.WaveInRange end
)

-- Composed specs

--[=[
	@prop CanGenerateDungeon Spec
	@within DungeonSpecs
	Composed eligibility check: ZoneExists AND NoDungeonActive.
]=]

--[=[
	@prop CanClearWave Spec
	@within DungeonSpecs
	Composed eligibility check: DungeonActive AND WaveInRange.
]=]

return table.freeze({
	CanGenerateDungeon = ZoneExists:And(NoDungeonActive),
	CanClearWave       = DungeonActive:And(WaveInRange),
})
