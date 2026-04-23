--!strict

local ActionStateTransitionSpec = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Specs.ActionStateTransitionSpec)
local Types = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Types)

type TActionState = Types.TActionState
type TTickActionResult = Types.TTickActionResult
type TResolveFinishedActionResult = Types.TResolveFinishedActionResult

local ResolveFinishedAction = {}

function ResolveFinishedAction.Execute(
	actionState: TActionState,
	tickResult: TTickActionResult,
	finishedAt: any?
): TResolveFinishedActionResult
	-- Reject malformed tick results before mutating the action-state table
	assert(type(tickResult) == "table", "BehaviorSystem ResolveFinishedAction requires a tickResult table")

	-- Skip non-terminal or no-op results because they do not resolve the current action
	local status = tickResult.Status
	if status == "Running" or status == "NoCurrentAction" then
		return {
			Status = "Skipped",
			ActionId = tickResult.ActionId,
		}
	end

	-- Only terminal statuses may clear the current action state
	if not ActionStateTransitionSpec.IsTickResultTerminal(status) then
		return {
			Status = "InvalidResult",
			ActionId = tickResult.ActionId,
		}
	end

	-- Ensure the tick result still matches the action currently held by the state table
	local currentActionId = actionState.CurrentActionId
	if tickResult.ActionId ~= currentActionId then
		return {
			Status = "InvalidResult",
			ActionId = tickResult.ActionId,
		}
	end

	-- Clear the current action and record the finishing marker if one was supplied
	local resolvedActionId = currentActionId
	actionState.CurrentActionId = nil
	actionState.ActionData = nil
	actionState.ActionState = "Idle"

	if finishedAt ~= nil then
		actionState.FinishedAt = finishedAt
	end

	return {
		Status = "Resolved",
		ActionId = resolvedActionId,
	}
end

return table.freeze(ResolveFinishedAction)
