--!strict

--[=[
	@class ResolveFinishedAction
	Clears the current action after a terminal tick result and restores the idle state.
	@server
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RuntimeEnums = require(ServerStorage.Utilities.ContextUtilities.AI.Runtime.src.RuntimeEnums)
local ActionStateTransitionSpec = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Specs.ActionStateTransitionSpec)
local ScratchRecycler = require(ServerStorage.Utilities.ContextUtilities.AI.src.Infrastructure.ScratchRecycler)
local Types = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Types)

type TActionState = Types.TActionState
type TTickActionResult = Types.TTickActionResult
type TResolveFinishedActionResult = Types.TResolveFinishedActionResult

local ResolveFinishedAction = {}

local function _createResult(status: any, actionId: string?): TResolveFinishedActionResult
	return {
		Status = status.Name,
		ActionId = actionId,
	}
end

--[=[
	Clears the current action after a terminal tick result and restores the idle state.
	@within ResolveFinishedAction
	@param actionState TActionState -- Owning action-state table
	@param tickResult TTickActionResult -- Result returned from the current-action executor boundary
	@param finishedAt any? -- Optional timestamp or transition marker stored on `FinishedAt`
	@return TResolveFinishedActionResult -- Structured resolution result
]=]
function ResolveFinishedAction.Execute(
	actionState: TActionState,
	tickResult: TTickActionResult,
	finishedAt: any?
): TResolveFinishedActionResult
	-- Reject malformed tick results before mutating the action-state table
	assert(type(tickResult) == "table", "BehaviorSystem ResolveFinishedAction requires a tickResult table")

	-- Skip non-terminal or no-op results because they do not resolve the current action
	local status = tickResult.Status
	if status == RuntimeEnums.TickStatus.Running.Name or status == RuntimeEnums.TickStatus.NoCurrentAction.Name then
		return _createResult(RuntimeEnums.ResolveStatus.Skipped, tickResult.ActionId)
	end

	-- Only terminal statuses may clear the current action state
	local transitionCandidate = ScratchRecycler.AcquireMap()
	transitionCandidate.TickResult = tickResult
	local terminalResult = ActionStateTransitionSpec.HasTerminalTickResult:IsSatisfiedBy(transitionCandidate)
	ScratchRecycler.ReleaseMap(transitionCandidate)
	if not terminalResult.success then
		return _createResult(RuntimeEnums.ResolveStatus.InvalidResult, tickResult.ActionId)
	end

	-- Ensure the tick result still matches the action currently held by the state table
	local currentActionId = actionState.CurrentActionId
	if tickResult.ActionId ~= currentActionId then
		return _createResult(RuntimeEnums.ResolveStatus.InvalidResult, tickResult.ActionId)
	end

	-- Clear the current action and record the finishing marker if one was supplied
	local resolvedActionId = currentActionId
	actionState.CurrentActionId = nil
	actionState.ActionData = nil
	actionState.ActionState = "Idle"

	if finishedAt ~= nil then
		actionState.FinishedAt = finishedAt
	end

	return _createResult(RuntimeEnums.ResolveStatus.Resolved, resolvedActionId)
end

return table.freeze(ResolveFinishedAction)
