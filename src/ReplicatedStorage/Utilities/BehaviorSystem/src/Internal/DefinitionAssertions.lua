--!strict

local Helpers = require(script.Parent.Parent.Helpers)

local DefinitionAssertions = {}

local function _assert(condition: boolean, message: string)
	assert(condition, message)
end

function DefinitionAssertions.AssertRegistryTable(registry: any, label: string)
	_assert(type(registry) == "table", ("BehaviorSystem %s registry must be a table"):format(label))
end

function DefinitionAssertions.AssertRegistryFunction(name: string, builder: any, label: string)
	_assert(
		type(builder) == "function",
		("BehaviorSystem %s registry entry '%s' must be a function"):format(label, name)
	)
end

function DefinitionAssertions.AssertNodeShape(node: any, path: string)
	local nodeType = type(node)
	_assert(
		nodeType == "string" or nodeType == "table",
		("BehaviorSystem definition node at %s must be a string or table"):format(path)
	)
end

function DefinitionAssertions.AssertNonEmptyChildren(children: any, path: string, nodeType: string)
	_assert(type(children) == "table", ("BehaviorSystem %s node at %s must contain a child array"):format(nodeType, path))
	_assert(next(children) ~= nil, ("BehaviorSystem %s node at %s must contain at least one child"):format(nodeType, path))
end

function DefinitionAssertions.AssertKnownLeaf(
	conditions: { [string]: any },
	commands: { [string]: any },
	name: string,
	path: string
)
	local inConditions = Helpers.HasCondition(conditions, name)
	local inCommands = Helpers.HasCommand(commands, name)

	_assert(inConditions or inCommands, ("BehaviorSystem leaf '%s' at %s is not registered"):format(name, path))
	_assert(
		not (inConditions and inCommands),
		("BehaviorSystem leaf '%s' at %s is ambiguous across condition and command registries"):format(name, path)
	)
end

function DefinitionAssertions.AssertCompositeShape(node: { [any]: any }, path: string)
	local hasSequence = node.Sequence ~= nil
	local hasPriority = node.Priority ~= nil

	_assert(hasSequence or hasPriority, ("BehaviorSystem composite node at %s must declare Sequence or Priority"):format(path))
	_assert(
		not (hasSequence and hasPriority),
		("BehaviorSystem composite node at %s cannot declare both Sequence and Priority"):format(path)
	)

	for key in pairs(node) do
		_assert(
			key == "Sequence" or key == "Priority",
			("BehaviorSystem composite node at %s contains unsupported key '%s'"):format(path, tostring(key))
		)
	end
end

function DefinitionAssertions.AssertSequenceNode(node: any, path: string)
	_assert(Helpers.IsSequenceNode(node), ("BehaviorSystem node at %s is not a valid Sequence node"):format(path))
end

function DefinitionAssertions.AssertPriorityNode(node: any, path: string)
	_assert(Helpers.IsPriorityNode(node), ("BehaviorSystem node at %s is not a valid Priority node"):format(path))
end

return table.freeze(DefinitionAssertions)
