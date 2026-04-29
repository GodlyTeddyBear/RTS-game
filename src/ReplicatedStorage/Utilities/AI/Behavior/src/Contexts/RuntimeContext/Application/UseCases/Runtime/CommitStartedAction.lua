--!strict

--[=[
	@class CommitStartedAction
	Commits a pending action start into the current action fields after validation.
	@server
	@client
]=]

local ActionId = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.ValueObjects.ActionId)
local ActionStateTransitionSpec = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Specs.ActionStateTransitionSpec)
local Types = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Types)

type TActionState = Types.TActionState
type TStartActionResult = Types.TStartActionResult
type TCommitStartResult = Types.TCommitStartResult

local CommitStartedAction = {}

--[=[
	Commits a pending action start into the current action fields after validation.
	@within CommitStartedAction
	@param actionState TActionState -- Owning action-state table
	@param startResult TStartActionResult -- Result returned from the pending-start executor boundary
	@param startedAt any? -- Optional timestamp or transition marker stored on `StartedAt`
	@return TCommitStartResult -- Structured commit result
]=]
function CommitStartedAction.Execute(
	actionState: TActionState,
	startResult: TStartActionResult,
	startedAt: any?
): TCommitStartResult
	-- Reject malformed transition results before mutating the action-state table
	assert(type(startResult) == "table", "BehaviorSystem CommitStartedAction requires a startResult table")

	-- Skip results that do not represent a commit-worthy start transition
	if not ActionStateTransitionSpec.IsStartResultCommittable(startResult.Status) then
		return {
			Status = "Skipped",
			ActionId = startResult.ActionId,
		}
	end

	-- Ensure the pending action still matches the result before promoting it to current
	local pendingActionId = actionState.PendingActionId
	if type(pendingActionId) ~= "string" then
		return {
			Status = "InvalidResult",
			ActionId = nil,
		}
	end
	pendingActionId = ActionId.From(pendingActionId, "actionState.PendingActionId")

	if startResult.ActionId ~= pendingActionId then
		-- Mismatched ids mean the caller tried to commit a stale or unrelated result
		return {
			Status = "InvalidResult",
			ActionId = startResult.ActionId,
		}
	end

	-- Promote pending state to current state and clear the pending fields in one atomic transition
	actionState.CurrentActionId = pendingActionId
	actionState.ActionData = actionState.PendingActionData
	actionState.PendingActionId = nil
	actionState.PendingActionData = nil
	actionState.ActionState = "Running"

	if startedAt ~= nil then
		actionState.StartedAt = startedAt
	end

	return {
		Status = "Committed",
		ActionId = pendingActionId,
	}
end

return table.freeze(CommitStartedAction)
