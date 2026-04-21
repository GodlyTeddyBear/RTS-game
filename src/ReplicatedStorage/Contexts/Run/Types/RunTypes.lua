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
	.phaseStartedAt number? -- Server timestamp when the current timed phase started.
	.phaseEndsAt number? -- Server timestamp when the current timed phase ends.
	.phaseDuration number? -- Current timed phase duration in seconds.
]=]
export type RunSnapshot = {
	state: RunState,
	waveNumber: number,
	phaseStartedAt: number?,
	phaseEndsAt: number?,
	phaseDuration: number?,
}

return table.freeze(RunTypes)
