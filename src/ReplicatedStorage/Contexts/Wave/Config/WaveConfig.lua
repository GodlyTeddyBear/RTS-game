--!strict

local function deepFreeze<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end

	for _, nested in value do
		if type(nested) == "table" then
			deepFreeze(nested)
		end
	end

	return table.freeze(value)
end

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
	WAVE_TABLE = {
		[1] = {
			{ role = "swarm", count = 5, groupDelay = 0 },
			{ role = "swarm", count = 3, groupDelay = 8 },
		},
		[2] = {
			{ role = "swarm", count = 6, groupDelay = 0 },
			{ role = "tank", count = 1, groupDelay = 12 },
		},
		[3] = {
			{ role = "swarm", count = 8, groupDelay = 0 },
			{ role = "ranged", count = 2, groupDelay = 10 },
		},
		[4] = {
			{ role = "swarm", count = 10, groupDelay = 0 },
			{ role = "tank", count = 2, groupDelay = 12 },
		},
		[5] = {
			{ role = "swarm", count = 10, groupDelay = 0 },
			{ role = "ranged", count = 4, groupDelay = 9 },
		},
		[6] = {
			{ role = "swarm", count = 12, groupDelay = 0 },
			{ role = "tank", count = 2, groupDelay = 10 },
			{ role = "ranged", count = 2, groupDelay = 14 },
		},
		[7] = {
			{ role = "swarm", count = 12, groupDelay = 0 },
			{ role = "tank", count = 3, groupDelay = 10 },
			{ role = "ranged", count = 3, groupDelay = 14 },
		},
		[8] = {
			{ role = "swarm", count = 14, groupDelay = 0 },
			{ role = "tank", count = 3, groupDelay = 10 },
			{ role = "ranged", count = 4, groupDelay = 15 },
		},
		[9] = {
			{ role = "swarm", count = 16, groupDelay = 0 },
			{ role = "tank", count = 4, groupDelay = 9 },
			{ role = "ranged", count = 4, groupDelay = 14 },
		},
		[10] = {
			{ role = "swarm", count = 18, groupDelay = 0 },
			{ role = "tank", count = 5, groupDelay = 8 },
			{ role = "ranged", count = 6, groupDelay = 12 },
		},
	},

	--[=[
		@prop ENDLESS_ROLE_THRESHOLDS table
		@within WaveConfig
		Threshold-based role additions for endless waves.
	]=]
	-- Extra role groups appended once the endless index reaches each threshold.
	ENDLESS_ROLE_THRESHOLDS = {
		[3] = { role = "disruptor", count = 1 },
		[6] = { role = "artillery", count = 1 },
	},
}

deepFreeze(WaveConfig)

return WaveConfig
