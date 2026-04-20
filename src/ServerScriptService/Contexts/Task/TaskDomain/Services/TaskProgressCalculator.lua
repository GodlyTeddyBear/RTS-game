--!strict

local TaskTypes = require(game:GetService("ReplicatedStorage").Contexts.Task.Types.TaskTypes)

type TTaskDefinition = TaskTypes.TTaskDefinition
type TPlayerTaskProgress = TaskTypes.TPlayerTaskProgress
type TTaskProgressInput = TaskTypes.TTaskProgressInput

local TaskProgressCalculator = {}
TaskProgressCalculator.__index = TaskProgressCalculator

function TaskProgressCalculator.new()
	return setmetatable({}, TaskProgressCalculator)
end

function TaskProgressCalculator:ApplyProgress(
	definition: TTaskDefinition,
	taskProgress: TPlayerTaskProgress,
	input: TTaskProgressInput
): TPlayerTaskProgress?
	if taskProgress.Status ~= "Active" then
		return nil
	end

	local nextProgress = self:_CloneTaskProgress(taskProgress)
	local changed = false

	for _, objective in ipairs(definition.Objectives) do
		if self:_ObjectiveMatches(objective, input) then
			local objectiveProgress = nextProgress.Objectives[objective.Id]
			local currentAmount = objectiveProgress and objectiveProgress.Amount or 0
			local nextAmount = math.min(objective.Required, currentAmount + input.Amount)

			if nextAmount ~= currentAmount then
				nextProgress.Objectives[objective.Id] = { Amount = nextAmount }
				changed = true
			end
		end
	end

	if not changed then
		return nil
	end

	if self:_AreAllObjectivesComplete(definition, nextProgress) then
		nextProgress.Status = "Claimable"
		nextProgress.ClaimableAt = os.time()
	end

	return nextProgress
end

function TaskProgressCalculator:_CloneTaskProgress(taskProgress: TPlayerTaskProgress): TPlayerTaskProgress
	local objectives = {}
	for objectiveId, objectiveProgress in pairs(taskProgress.Objectives) do
		objectives[objectiveId] = {
			Amount = objectiveProgress.Amount,
		}
	end

	return {
		TaskId = taskProgress.TaskId,
		Status = taskProgress.Status,
		Objectives = objectives,
		StartedAt = taskProgress.StartedAt,
		ClaimableAt = taskProgress.ClaimableAt,
		ClaimedAt = taskProgress.ClaimedAt,
	}
end

function TaskProgressCalculator:_ObjectiveMatches(objective: any, input: TTaskProgressInput): boolean
	return objective.Kind == input.Kind and objective.TargetId == input.TargetId
end

function TaskProgressCalculator:_AreAllObjectivesComplete(
	definition: TTaskDefinition,
	taskProgress: TPlayerTaskProgress
): boolean
	for _, objective in ipairs(definition.Objectives) do
		local progress = taskProgress.Objectives[objective.Id]
		if not progress or progress.Amount < objective.Required then
			return false
		end
	end
	return true
end

return TaskProgressCalculator
