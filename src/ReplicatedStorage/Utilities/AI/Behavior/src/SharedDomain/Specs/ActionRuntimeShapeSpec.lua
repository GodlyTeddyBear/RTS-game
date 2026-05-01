--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)
local ActionStatus = require(script.Parent.Parent.ValueObjects.ActionStatus)

export type TExecutorCandidate = {
	ActionId: string,
	Executor: any,
}

export type TActionDefinitionCandidate = {
	ActionId: string,
	Definition: any,
	HasFactory: boolean,
	HasExecutor: boolean,
}

export type TActionStateCandidate = {
	ActionState: any,
}

local HasExecutorTable = Spec.new(
	"InvalidExecutor",
	"BehaviorSystem executor must be a table",
	function(candidate: TExecutorCandidate): boolean
		return type(candidate.Executor) == "table"
	end
)

local HasExecutorStart = Spec.new(
	"InvalidExecutor",
	"BehaviorSystem executor.Start must be a function",
	function(candidate: TExecutorCandidate): boolean
		local executor = candidate.Executor
		return type(executor) == "table" and type(executor.Start) == "function"
	end
)

local HasExecutorTick = Spec.new(
	"InvalidExecutor",
	"BehaviorSystem executor.Tick must be a function",
	function(candidate: TExecutorCandidate): boolean
		local executor = candidate.Executor
		return type(executor) == "table" and type(executor.Tick) == "function"
	end
)

local HasExecutorCancel = Spec.new(
	"InvalidExecutor",
	"BehaviorSystem executor.Cancel must be a function",
	function(candidate: TExecutorCandidate): boolean
		local executor = candidate.Executor
		return type(executor) == "table" and type(executor.Cancel) == "function"
	end
)

local HasExecutorComplete = Spec.new(
	"InvalidExecutor",
	"BehaviorSystem executor.Complete must be a function",
	function(candidate: TExecutorCandidate): boolean
		local executor = candidate.Executor
		return type(executor) == "table" and type(executor.Complete) == "function"
	end
)

local HasExecutorDeath = Spec.new(
	"InvalidExecutor",
	"BehaviorSystem executor.Death must be a function",
	function(candidate: TExecutorCandidate): boolean
		local executor = candidate.Executor
		return type(executor) == "table" and type(executor.Death) == "function"
	end
)

local HasActionDefinitionTable = Spec.new(
	"InvalidActionDefinition",
	"BehaviorSystem action definition must be a table",
	function(candidate: TActionDefinitionCandidate): boolean
		return type(candidate.Definition) == "table"
	end
)

local HasFactoryOrExecutor = Spec.new(
	"InvalidActionDefinition",
	"BehaviorSystem action definition requires CreateExecutor or Executor",
	function(candidate: TActionDefinitionCandidate): boolean
		return candidate.HasFactory or candidate.HasExecutor
	end
)

local HasSingleActionExecutorSource = Spec.new(
	"InvalidActionDefinition",
	"BehaviorSystem action definition cannot define both CreateExecutor and Executor",
	function(candidate: TActionDefinitionCandidate): boolean
		return not (candidate.HasFactory and candidate.HasExecutor)
	end
)

local HasFactoryFunction = Spec.new(
	"InvalidActionDefinition",
	"BehaviorSystem action definition CreateExecutor must be a function",
	function(candidate: TActionDefinitionCandidate): boolean
		if not candidate.HasFactory then
			return true
		end

		local definition = candidate.Definition
		return type(definition) == "table" and type(definition.CreateExecutor) == "function"
	end
)

local HasActionStateTable = Spec.new(
	"InvalidActionState",
	"BehaviorSystem actionState must be a table",
	function(candidate: TActionStateCandidate): boolean
		return type(candidate.ActionState) == "table"
	end
)

local HasValidPendingActionId = Spec.new(
	"InvalidActionState",
	"BehaviorSystem actionState.PendingActionId must be a non-empty string when present",
	function(candidate: TActionStateCandidate): boolean
		local actionState = candidate.ActionState
		if type(actionState) ~= "table" then
			return true
		end

		local pendingActionId = actionState.PendingActionId
		return pendingActionId == nil or (type(pendingActionId) == "string" and #pendingActionId > 0)
	end
)

local HasValidCurrentActionId = Spec.new(
	"InvalidActionState",
	"BehaviorSystem actionState.CurrentActionId must be a non-empty string when present",
	function(candidate: TActionStateCandidate): boolean
		local actionState = candidate.ActionState
		if type(actionState) ~= "table" then
			return true
		end

		local currentActionId = actionState.CurrentActionId
		return currentActionId == nil or (type(currentActionId) == "string" and #currentActionId > 0)
	end
)

local HasValidActionStateStatus = Spec.new(
	"InvalidActionState",
	"BehaviorSystem actionState.ActionState must be one of: Idle, Committed, Running",
	function(candidate: TActionStateCandidate): boolean
		local actionState = candidate.ActionState
		if type(actionState) ~= "table" then
			return true
		end

		local status = actionState.ActionState
		return status == nil or ActionStatus.IsValid(status)
	end
)

return table.freeze({
	HasValidExecutorShape = HasExecutorTable
		:And(HasExecutorStart)
		:And(HasExecutorTick)
		:And(HasExecutorCancel)
		:And(HasExecutorComplete)
		:And(HasExecutorDeath),
	HasValidActionDefinitionShape = HasActionDefinitionTable
		:And(HasFactoryOrExecutor)
		:And(HasSingleActionExecutorSource)
		:And(HasFactoryFunction),
	HasValidActionStateShape = HasActionStateTable
		:And(HasValidPendingActionId)
		:And(HasValidCurrentActionId)
		:And(HasValidActionStateStatus),
})
