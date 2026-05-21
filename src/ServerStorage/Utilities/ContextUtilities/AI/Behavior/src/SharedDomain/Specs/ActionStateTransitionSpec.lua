--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)
local RuntimeEnums = require(ReplicatedStorage.Utilities.AI.Runtime.src.RuntimeEnums)

export type TStartTransitionCandidate = {
	ActionState: any,
}

export type TCommitStartCandidate = {
	StartResult: any,
}

export type TResolveTickCandidate = {
	TickResult: any,
}

local CanStartFromActionState = Spec.new(
	"BlockedActionTransition",
	"BehaviorSystem cannot start a pending action while current action state is Committed",
	function(candidate: TStartTransitionCandidate): boolean
		return candidate.ActionState == nil or candidate.ActionState ~= "Committed"
	end
)

local HasCommittableStartResult = Spec.new(
	"UncommittableStartResult",
	"BehaviorSystem startResult.Status must be Started or Replaced to commit",
	function(candidate: TCommitStartCandidate): boolean
		local startResult = candidate.StartResult
		return type(startResult) == "table"
			and (
				startResult.Status == RuntimeEnums.StartStatus.Started.Name
				or startResult.Status == RuntimeEnums.StartStatus.Replaced.Name
			)
	end
)

local HasTerminalTickResult = Spec.new(
	"NonTerminalTickResult",
	"BehaviorSystem tickResult.Status must be Success, Fail, or MissingAction to resolve",
	function(candidate: TResolveTickCandidate): boolean
		local tickResult = candidate.TickResult
		return type(tickResult) == "table"
			and (
				tickResult.Status == RuntimeEnums.TickStatus.Success.Name
				or tickResult.Status == RuntimeEnums.TickStatus.Fail.Name
				or tickResult.Status == RuntimeEnums.TickStatus.MissingAction.Name
			)
	end
)

return table.freeze({
	CanStartFromActionState = CanStartFromActionState,
	HasCommittableStartResult = HasCommittableStartResult,
	HasTerminalTickResult = HasTerminalTickResult,
})
