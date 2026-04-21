--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)

type RunState = RunTypes.RunState

export type TRunState = {
	state: RunState,
	waveNumber: number,
	phaseStartedAt: number?,
	phaseEndsAt: number?,
	phaseDuration: number?,
}

local DEFAULT_RUN_STATE: TRunState = table.freeze({
	state = "Idle",
	waveNumber = 0,
	phaseStartedAt = nil,
	phaseEndsAt = nil,
	phaseDuration = nil,
})

local runAtom: (() -> TRunState)? = nil

local function _GetRunAtom(): () -> TRunState
	if runAtom == nil then
		local runController = Knit.GetController("RunController")
		runAtom = runController:GetAtom()
	end
	return runAtom
end

local function useRunState(): TRunState
	local state = ReactCharm.useAtom(_GetRunAtom())
	if state == nil then
		return DEFAULT_RUN_STATE
	end
	return state
end

return useRunState
