--!strict

--[=[
	@class RunTypes
	Defines the shared run state types used by the server and client sync layers.
	@server
	@client
]=]

local RunTypes = {}

--[=[
	@type RunState "Idle" | "Prep" | "Wave" | "Resolution" | "Climax" | "Endless" | "RunEnd"
	@within RunTypes
	Valid states in the run lifecycle state machine.
]=]
export type RunState = "Idle" | "Prep" | "Wave" | "Resolution" | "Climax" | "Endless" | "RunEnd"

--[=[
	@interface RunSnapshot
	@within RunTypes
	.state RunState -- Current authoritative run state.
	.waveNumber number -- Current authoritative wave counter.
]=]
export type RunSnapshot = {
	state: RunState,
	waveNumber: number,
}

return table.freeze(RunTypes)
