--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Contexts.Economy.Config.EconomyConfig)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)

type RunState = RunTypes.RunState
type RunSnapshot = RunTypes.RunSnapshot

export type TRunPhaseViewData = {
	phaseLabel: string,
	waveLabel: string,
	countdownText: string,
	statusText: string,
	rewardText: string?,
}

local RunPhaseViewModel = {}

local function _GetPhaseLabel(state: RunState): string
	if state == "Prep" then
		return "Prep"
	end

	if state == "Wave" or state == "Endless" then
		return "Combat"
	end

	if state == "Resolution" then
		return "Breather"
	end

	if state == "Climax" then
		return "Climax"
	end

	if state == "RunEnd" then
		return "Run End"
	end

	return "Lobby"
end

local function _GetStatusText(state: RunState): string
	if state == "Prep" then
		return "Prepare defenses"
	end

	if state == "Wave" or state == "Endless" then
		return "Hold the lane"
	end

	if state == "Resolution" then
		return "Wave cleared"
	end

	if state == "RunEnd" then
		return "Returning to lobby"
	end

	return "Awaiting run"
end

local function _GetCountdownText(snapshot: RunSnapshot, now: number): string
	local phaseEndsAt = snapshot.phaseEndsAt
	if phaseEndsAt == nil then
		return "--"
	end

	local remaining = math.max(0, math.ceil(phaseEndsAt - now))
	return string.format("%ds", remaining)
end

function RunPhaseViewModel.fromSnapshot(snapshot: RunSnapshot, now: number): TRunPhaseViewData
	local rewardText = nil
	if snapshot.state == "Resolution" then
		rewardText = string.format("+%d Energy", EconomyConfig.WAVE_CLEAR_BONUS)
	end

	return table.freeze({
		phaseLabel = _GetPhaseLabel(snapshot.state),
		waveLabel = if snapshot.waveNumber > 0 then string.format("Wave %d", snapshot.waveNumber) else "Wave --",
		countdownText = _GetCountdownText(snapshot, now),
		statusText = _GetStatusText(snapshot.state),
		rewardText = rewardText,
	} :: TRunPhaseViewData)
end

return table.freeze(RunPhaseViewModel)
