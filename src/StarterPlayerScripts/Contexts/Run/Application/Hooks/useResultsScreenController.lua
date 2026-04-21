--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Knit = require(ReplicatedStorage.Packages.Knit)

local useRunState = require(script.Parent.useRunState)

local useMemo = React.useMemo

export type TResultScreenController = {
	waveNumber: number,
	score: number,
	onPlayAgain: () -> (),
}

local PHASE1_SCORE = 0

local function _RequestRestartRun()
	local runContext = Knit.GetService("RunContext")
	local ok, didRestart = pcall(function()
		return runContext:RequestRestartRun()
	end)

	if not ok or not didRestart then
		warn("[ResultsScreen] Failed to request run restart")
	end
end

local function useResultsScreenController(): TResultScreenController
	local runState = useRunState()

	local onPlayAgain = useMemo(function()
		return _RequestRestartRun
	end, {})

	return {
		waveNumber = runState.waveNumber,
		score = PHASE1_SCORE,
		onPlayAgain = onPlayAgain,
	}
end

return useResultsScreenController
