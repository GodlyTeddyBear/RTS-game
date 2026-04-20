--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

export type TTaskEligibilityCandidate = {
	Chapter: number,
	UnlockedTargets: { [string]: boolean },
	ClaimedTaskIds: { [string]: boolean },
	ExpeditionsCompleted: number,
	Flags: { [string]: any },
	Conditions: any,
}

export type TClaimCandidate = {
	TaskExists: boolean,
	Status: string?,
}

local ChapterMet = Spec.new("ChapterLocked", "Required chapter has not been reached", function(candidate: TTaskEligibilityCandidate)
	local requiredChapter = candidate.Conditions and candidate.Conditions.Chapter
	return requiredChapter == nil or candidate.Chapter >= requiredChapter
end)

local UnlocksMet = Spec.new("UnlocksMissing", "Required unlocks are missing", function(candidate: TTaskEligibilityCandidate)
	local requiredUnlocks = candidate.Conditions and candidate.Conditions.Unlocks
	if not requiredUnlocks then
		return true
	end

	for _, targetId in ipairs(requiredUnlocks) do
		if candidate.UnlockedTargets[targetId] ~= true then
			return false
		end
	end
	return true
end)

local CompletedTasksMet = Spec.new("TasksIncomplete", "Required tasks are incomplete", function(candidate: TTaskEligibilityCandidate)
	local requiredTaskIds = candidate.Conditions and candidate.Conditions.CompletedTaskIds
	if not requiredTaskIds then
		return true
	end

	for _, taskId in ipairs(requiredTaskIds) do
		if candidate.ClaimedTaskIds[taskId] ~= true then
			return false
		end
	end
	return true
end)

local ExpeditionsCompletedMet = Spec.new("ExpeditionsIncomplete", "Required expedition count has not been reached",
	function(candidate: TTaskEligibilityCandidate)
		local requiredCount = candidate.Conditions and candidate.Conditions.ExpeditionsCompleted
		return requiredCount == nil or candidate.ExpeditionsCompleted >= requiredCount
	end
)

local FlagsMet = Spec.new("FlagsMissing", "Required flags are missing", function(candidate: TTaskEligibilityCandidate)
	local requiredFlags = candidate.Conditions and candidate.Conditions.Flags
	if not requiredFlags then
		return true
	end

	for flagName, requiredValue in pairs(requiredFlags) do
		if candidate.Flags[flagName] ~= requiredValue then
			return false
		end
	end
	return true
end)

local TaskExists = Spec.new("TaskNotFound", Errors.TASK_NOT_FOUND, function(candidate: TClaimCandidate)
	return candidate.TaskExists
end)

local TaskClaimable = Spec.new("TaskNotClaimable", Errors.TASK_NOT_CLAIMABLE, function(candidate: TClaimCandidate)
	return candidate.Status == "Claimable"
end)

return table.freeze({
	CanStartTask = Spec.All({
		ChapterMet,
		UnlocksMet,
		CompletedTasksMet,
		ExpeditionsCompletedMet,
		FlagsMet,
	}),
	CanClaimTask = TaskExists:And(TaskClaimable),
})
