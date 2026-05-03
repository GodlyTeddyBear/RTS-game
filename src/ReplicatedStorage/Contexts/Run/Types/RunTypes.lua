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
	.State RunState -- Current authoritative run state.
	.WaveNumber number -- Current authoritative wave counter.
	.PhaseStartedAt number? -- Server timestamp when the current timed phase started.
	.PhaseEndsAt number? -- Server timestamp when the current timed phase ends.
	.PhaseDuration number? -- Current timed phase duration in seconds.
]=]
export type RunSnapshot = {
	State: RunState,
	WaveNumber: number,
	PhaseStartedAt: number?,
	PhaseEndsAt: number?,
	PhaseDuration: number?,
}

return table.freeze(RunTypes)
