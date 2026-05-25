--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)

type RunState = RunTypes.RunState

local ACTIVE_PLACEMENT_STATES: { [RunState]: boolean } = table.freeze({
	Prep = true,
	Wave = true,
	Resolution = true,
	Climax = true,
	Endless = true,
})

local function CanPlaceInRunState(runState: RunState): boolean
	return ACTIVE_PLACEMENT_STATES[runState] == true
end

return CanPlaceInRunState
