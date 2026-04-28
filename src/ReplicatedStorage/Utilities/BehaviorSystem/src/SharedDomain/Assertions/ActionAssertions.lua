--!strict

--[=[
    @class ActionAssertions
    Shared assertion helpers that enforce BehaviorSystem action-definition, executor, and action-state invariants.
    @server
    @client
]=]

local ActionAssertions = {}
local ActionId = require(script.Parent.Parent.ValueObjects.ActionId)
local ActionStatus = require(script.Parent.Parent.ValueObjects.ActionStatus)

-- Asserts a condition with the caller-supplied message so public helpers can stay domain focused.
local function _assert(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

-- ── Public ──────────────────────────────────────────────────────────────────────────────────────────────────────────

--[=[
    Asserts that an executor exposes the full BehaviorSystem lifecycle surface.
    @within ActionAssertions
    @param executor any -- Executor candidate
    @param actionId string -- Action id used in the error message
]=]
function ActionAssertions.AssertExecutor(executor: any, actionId: string)
	_assert(type(executor) == "table", ("BehaviorSystem action '%s' executor must be a table"):format(actionId))
	_assert(type(executor.Start) == "function", ("BehaviorSystem action '%s' executor.Start must be a function"):format(actionId))
	_assert(type(executor.Tick) == "function", ("BehaviorSystem action '%s' executor.Tick must be a function"):format(actionId))
	_assert(type(executor.Cancel) == "function", ("BehaviorSystem action '%s' executor.Cancel must be a function"):format(actionId))
	_assert(type(executor.Complete) == "function", ("BehaviorSystem action '%s' executor.Complete must be a function"):format(actionId))
	_assert(type(executor.Death) == "function", ("BehaviorSystem action '%s' executor.Death must be a function"):format(actionId))
end

--[=[
    Asserts that an action definition provides either a factory or a prebuilt executor.
    @within ActionAssertions
    @param definition any -- Action-definition candidate
]=]
function ActionAssertions.AssertActionDefinition(definition: any)
	_assert(type(definition) == "table", "BehaviorSystem action definition must be a table")
	local actionId = ActionId.From(definition.ActionId, "action definition ActionId")

	local hasFactory = definition.CreateExecutor ~= nil
	local hasExecutor = definition.Executor ~= nil

	_assert(
		hasFactory or hasExecutor,
		("BehaviorSystem action '%s' requires CreateExecutor or Executor"):format(actionId)
	)
	_assert(
		not (hasFactory and hasExecutor),
		("BehaviorSystem action '%s' cannot define both CreateExecutor and Executor"):format(actionId)
	)

	if hasFactory then
		_assert(
			type(definition.CreateExecutor) == "function",
			("BehaviorSystem action '%s' CreateExecutor must be a function"):format(actionId)
		)
	end

	if hasExecutor then
		ActionAssertions.AssertExecutor(definition.Executor, actionId)
	end
end

--[=[
    Asserts that an action-state table contains valid action ids and status labels.
    @within ActionAssertions
    @param actionState any -- Action-state candidate
]=]
function ActionAssertions.AssertActionState(actionState: any)
	_assert(type(actionState) == "table", "BehaviorSystem actionState must be a table")

	if actionState.PendingActionId ~= nil then
		ActionId.From(actionState.PendingActionId, "actionState.PendingActionId")
	end

	if actionState.CurrentActionId ~= nil then
		ActionId.From(actionState.CurrentActionId, "actionState.CurrentActionId")
	end

	if actionState.ActionState ~= nil then
		ActionStatus.Assert(actionState.ActionState, "actionState.ActionState")
	end
end

--[=[
    Asserts that an action id is a non-empty string.
    @within ActionAssertions
    @param actionId any -- Action id candidate
    @param label string -- Label used in the error message
]=]
function ActionAssertions.AssertActionId(actionId: any, label: string)
	ActionId.From(actionId, label)
end

return table.freeze(ActionAssertions)
