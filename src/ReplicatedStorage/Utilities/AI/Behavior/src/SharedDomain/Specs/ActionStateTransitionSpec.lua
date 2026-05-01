--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)

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
			and (startResult.Status == "Started" or startResult.Status == "Replaced")
	end
)

local HasTerminalTickResult = Spec.new(
	"NonTerminalTickResult",
	"BehaviorSystem tickResult.Status must be Success, Fail, or MissingAction to resolve",
	function(candidate: TResolveTickCandidate): boolean
		local tickResult = candidate.TickResult
		return type(tickResult) == "table"
			and (tickResult.Status == "Success" or tickResult.Status == "Fail" or tickResult.Status == "MissingAction")
	end
)

return table.freeze({
	CanStartFromActionState = CanStartFromActionState,
	HasCommittableStartResult = HasCommittableStartResult,
	HasTerminalTickResult = HasTerminalTickResult,
})
