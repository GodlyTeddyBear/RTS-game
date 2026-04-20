--!strict

--[=[
	@class RunConfig
	Defines the shared timing groups that drive the run state machine.
	@server
	@client
]=]

local RunConfig = {}

--[=[
	@type PhaseDurations
	@within RunConfig
	Prep number -- Seconds spent in `Prep` before advancing to `Wave`.
	Wave number -- Seconds spent in `Wave` before advancing to `Resolution`.
	Resolution number -- Seconds spent in `Resolution` before the next branch.
]=]
export type PhaseDurations = {
	Prep: number,
	Wave: number,
	Resolution: number,
}

--[=[
	@prop Phases PhaseDurations
	@within RunConfig
	Grouped phase durations used by the run timer service.
]=]
RunConfig.Phases = table.freeze({
	Prep = 30,
	Wave = 90,
	Resolution = 5,
} :: PhaseDurations)

--[=[
	@prop CLIMAX_WAVE number
	@within RunConfig
	Wave number that routes the next resolution into `Climax`.
]=]
RunConfig.CLIMAX_WAVE = 10

return table.freeze(RunConfig)
