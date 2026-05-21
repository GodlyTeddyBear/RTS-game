--!strict

--[=[
	@class CommitStartedAction
	Commits a pending action start into the current action fields after validation.
	@server
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RuntimeEnums = require(ReplicatedStorage.Utilities.AI.Runtime.src.RuntimeEnums)
local ActionId = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.ValueObjects.ActionId)
local ActionStateTransitionSpec = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Specs.ActionStateTransitionSpec)
local ScratchRecycler = require(ReplicatedStorage.Utilities.AI.src.Infrastructure.ScratchRecycler)
local Types = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Types)

type TActionState = Types.TActionState
type TStartActionResult = Types.TStartActionResult
type TCommitStartResult = Types.TCommitStartResult

local CommitStartedAction = {}

local function _createResult(status: any, actionId: string?): TCommitStartResult
	return {
		Status = status.Name,
		ActionId = actionId,
	}
end

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
	local transitionCandidate = ScratchRecycler.AcquireMap()
	transitionCandidate.StartResult = startResult
	local committableResult = ActionStateTransitionSpec.HasCommittableStartResult:IsSatisfiedBy(transitionCandidate)
	ScratchRecycler.ReleaseMap(transitionCandidate)
	if not committableResult.success then
		return _createResult(RuntimeEnums.CommitStatus.Skipped, startResult.ActionId)
	end

	-- Ensure the pending action still matches the result before promoting it to current
	local pendingActionId = actionState.PendingActionId
	if type(pendingActionId) ~= "string" then
		return _createResult(RuntimeEnums.CommitStatus.InvalidResult, nil)
	end
	pendingActionId = ActionId.From(pendingActionId, "actionState.PendingActionId")

	if startResult.ActionId ~= pendingActionId then
		-- Mismatched ids mean the caller tried to commit a stale or unrelated result
		return _createResult(RuntimeEnums.CommitStatus.InvalidResult, startResult.ActionId)
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

	return _createResult(RuntimeEnums.CommitStatus.Committed, pendingActionId)
end

return table.freeze(CommitStartedAction)
