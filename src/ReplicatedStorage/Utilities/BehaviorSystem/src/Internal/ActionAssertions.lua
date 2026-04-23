--!strict

local ActionAssertions = {}

local function _assert(condition: boolean, message: string)
	assert(condition, message)
end

function ActionAssertions.AssertActionDefinition(definition: any)
	_assert(type(definition) == "table", "BehaviorSystem action definition must be a table")
	_assert(
		type(definition.ActionId) == "string" and #definition.ActionId > 0,
		"BehaviorSystem action definition requires a non-empty ActionId"
	)

	local hasFactory = definition.CreateExecutor ~= nil
	local hasExecutor = definition.Executor ~= nil

	_assert(
		hasFactory or hasExecutor,
		("BehaviorSystem action '%s' requires CreateExecutor or Executor"):format(definition.ActionId)
	)
	_assert(
		not (hasFactory and hasExecutor),
		("BehaviorSystem action '%s' cannot define both CreateExecutor and Executor"):format(definition.ActionId)
	)

	if hasFactory then
		_assert(
			type(definition.CreateExecutor) == "function",
			("BehaviorSystem action '%s' CreateExecutor must be a function"):format(definition.ActionId)
		)
	end
end

function ActionAssertions.AssertActionState(actionState: any)
	_assert(type(actionState) == "table", "BehaviorSystem actionState must be a table")
end

function ActionAssertions.AssertActionId(actionId: any, label: string)
	_assert(type(actionId) == "string" and #actionId > 0, ("BehaviorSystem %s must be a non-empty string"):format(label))
end

return table.freeze(ActionAssertions)
