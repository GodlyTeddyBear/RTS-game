--!strict

--[[
    Module: WaveConfig
    Purpose: Defines shared scripted wave tables and endless scaling constants.
    Used In System: Imported by server wave orchestration and shared wave consumers.
    Boundaries: Owns static wave data only; does not own scheduling, spawning, or lifecycle transitions.
]]

-- [Utilities]

-- Recursively freezes nested wave tables so shared config stays immutable at runtime.
local function deepFreeze<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end

	-- Freeze nested tables first so the outer table closes over immutable children.
	for _, nested in value do
		if type(nested) == "table" then
			deepFreeze(nested)
		end
	end

	return table.freeze(value)
end

-- [Constants]

--[=[
	@class WaveConfig
	Defines the scripted wave tables and endless scaling constants.
	@server
	@client
]=]
local WaveConfig = {
	--[=[
		@prop SPAWN_DRIP_INTERVAL number
		@within WaveConfig
		Seconds between enemy spawns within a group.
	]=]
	-- Seconds between individual enemy spawns inside a group.
	SPAWN_DRIP_INTERVAL = 2,
	--[=[
		@prop ENDLESS_SCALE_FACTOR number
		@within WaveConfig
		Scale applied to endless-wave enemy counts.
	]=]
	-- Per-endless-wave multiplier applied to the last scripted wave.
	ENDLESS_SCALE_FACTOR = 0.15,

	--[=[
		@prop WAVE_TABLE table
		@within WaveConfig
		Scripted wave definitions used before endless scaling begins.
	]=]
	-- Scripted wave definitions used before the endless loop starts.
	-- Phase 2 one-family lock: prior Tank groups are converted to Swarm at a 1:4 count ratio.
	WAVE_TABLE = {
		[1] = {
			{ role = "Swarm", count = 5, groupDelay = 0 },
			{ role = "Swarm", count = 3, groupDelay = 8 },
		},
		[2] = {
			{ role = "Swarm", count = 6, groupDelay = 0 },
			{ role = "Swarm", count = 4, groupDelay = 12 },
		},
		[3] = {
			{ role = "Swarm", count = 8, groupDelay = 0 },
			{ role = "Swarm", count = 4, groupDelay = 10 },
		},
		[4] = {
			{ role = "Swarm", count = 10, groupDelay = 0 },
			{ role = "Swarm", count = 8, groupDelay = 12 },
		},
		[5] = {
			{ role = "Swarm", count = 12, groupDelay = 0 },
			{ role = "Swarm", count = 8, groupDelay = 9 },
		},
		[6] = {
			{ role = "Swarm", count = 14, groupDelay = 0 },
			{ role = "Swarm", count = 12, groupDelay = 10 },
		},
	},

	--[=[
		@prop ENDLESS_ROLE_THRESHOLDS table
		@within WaveConfig
		Threshold-based role additions for endless waves.
	]=]
	-- Extra role groups appended once the endless index reaches each threshold.
	ENDLESS_ROLE_THRESHOLDS = {},
}

deepFreeze(WaveConfig)

return WaveConfig
