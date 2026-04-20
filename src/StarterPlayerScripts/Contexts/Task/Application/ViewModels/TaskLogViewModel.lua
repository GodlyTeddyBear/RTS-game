--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TaskConfig = require(ReplicatedStorage.Contexts.Task.Config.TaskConfig)
local TaskTypes = require(ReplicatedStorage.Contexts.Task.Types.TaskTypes)

type TTaskState = TaskTypes.TTaskState
type TPlayerTaskProgress = TaskTypes.TPlayerTaskProgress

export type TObjectiveVM = {
	Text: string,
	Amount: number,
	Required: number,
	IsComplete: boolean,
}

export type TTaskVM = {
	TaskId: string,
	Title: string,
	Description: string,
	Status: string,
	StatusLabel: string,
	Objectives: { TObjectiveVM },
	RewardLabel: string,
	CanClaim: boolean,
}

export type TTaskLogVM = {
	ActiveTasks: { TTaskVM },
	ClaimableTasks: { TTaskVM },
	ClaimedTasks: { TTaskVM },
	IsEmpty: boolean,
}

local TaskLogViewModel = {}

local function _BuildObjectiveVMs(definition: any, taskProgress: TPlayerTaskProgress): { TObjectiveVM }
	local objectiveVMs = {}
	for _, objective in ipairs(definition.Objectives) do
		local progress = taskProgress.Objectives[objective.Id]
		local amount = progress and progress.Amount or 0
		table.insert(objectiveVMs, {
			Text = objective.Description,
			Amount = amount,
			Required = objective.Required,
			IsComplete = amount >= objective.Required,
		})
	end
	return objectiveVMs
end

local function _BuildRewardLabel(rewards: any): string
	if not rewards then
		return "No reward"
	end

	local labels = {}
	if rewards.Gold and rewards.Gold > 0 then
		table.insert(labels, tostring(rewards.Gold) .. " Gold")
	end

	if rewards.Items then
		for _, item in ipairs(rewards.Items) do
			table.insert(labels, tostring(item.Quantity) .. " " .. item.ItemId)
		end
	end

	if #labels == 0 then
		return "No reward"
	end

	return table.concat(labels, ", ")
end

local function _BuildTaskVM(taskProgress: TPlayerTaskProgress): TTaskVM?
	local definition = TaskConfig[taskProgress.TaskId]
	if not definition then
		return nil
	end

	return {
		TaskId = taskProgress.TaskId,
		Title = definition.Title,
		Description = definition.Description,
		Status = taskProgress.Status,
		StatusLabel = taskProgress.Status,
		Objectives = _BuildObjectiveVMs(definition, taskProgress),
		RewardLabel = _BuildRewardLabel(definition.Rewards),
		CanClaim = taskProgress.Status == "Claimable",
	}
end

local function _SortTasks(left: TTaskVM, right: TTaskVM): boolean
	return left.Title < right.Title
end

function TaskLogViewModel.fromTaskState(taskState: TTaskState?): TTaskLogVM
	local activeTasks = {}
	local claimableTasks = {}
	local claimedTasks = {}

	local tasks = taskState and taskState.Tasks or {}
	for _, taskProgress in pairs(tasks) do
		local taskVM = _BuildTaskVM(taskProgress)
		if taskVM then
			if taskVM.Status == "Claimable" then
				table.insert(claimableTasks, taskVM)
			elseif taskVM.Status == "Claimed" then
				table.insert(claimedTasks, taskVM)
			else
				table.insert(activeTasks, taskVM)
			end
		end
	end

	table.sort(activeTasks, _SortTasks)
	table.sort(claimableTasks, _SortTasks)
	table.sort(claimedTasks, _SortTasks)

	return table.freeze({
		ActiveTasks = activeTasks,
		ClaimableTasks = claimableTasks,
		ClaimedTasks = claimedTasks,
		IsEmpty = #activeTasks == 0 and #claimableTasks == 0,
	})
end

return TaskLogViewModel
