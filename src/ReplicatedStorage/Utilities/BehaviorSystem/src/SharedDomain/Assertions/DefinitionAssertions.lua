--!strict

--[=[
    @class DefinitionAssertions
    Shared assertion helpers that enforce symbolic-definition registry and node invariants.
    @server
    @client
]=]

local DefinitionPath = require(script.Parent.Parent.ValueObjects.DefinitionPath)
local ChildArraySpec = require(script.Parent.Parent.Specs.ChildArraySpec)
local DefinitionNodeSpec = require(script.Parent.Parent.Specs.DefinitionNodeSpec)

local DefinitionAssertions = {}

-- ── Private ─────────────────────────────────────────────────────────────────────────────────────────────────────────

-- Asserts a condition with the caller-supplied message so the public helpers can stay focused on domain wording.
local function _assert(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

-- Checks whether a registry contains a leaf symbol without forcing the caller to know the registry shape.
local function _hasEntry(registry: { [string]: any }, name: string): boolean
	return type(registry) == "table" and registry[name] ~= nil
end

-- Distinguishes Sequence nodes from leaf symbols while keeping the public assertions concise.
local function _isSequenceNode(node: any): boolean
	return type(node) == "table" and type(node.Sequence) == "table"
end

-- Distinguishes Priority nodes from leaf symbols while keeping the public assertions concise.
local function _isPriorityNode(node: any): boolean
	return type(node) == "table" and type(node.Priority) == "table"
end

-- ── Public ──────────────────────────────────────────────────────────────────────────────────────────────────────────

--[=[
    Asserts that a registry table exists before registry entries are inspected.
    @within DefinitionAssertions
    @param registry any -- Registry candidate
    @param label string -- Registry label used in the error message
]=]
function DefinitionAssertions.AssertRegistryTable(registry: any, label: string)
	_assert(type(registry) == "table", ("BehaviorSystem %s registry must be a table"):format(label))
end

--[=[
    Asserts that a registry entry is a function.
    @within DefinitionAssertions
    @param name string -- Registry entry name
    @param builder any -- Registry entry candidate
    @param label string -- Registry label used in the error message
]=]
function DefinitionAssertions.AssertRegistryFunction(name: string, builder: any, label: string)
	_assert(
		type(builder) == "function",
		("BehaviorSystem %s registry entry '%s' must be a function"):format(label, name)
	)
end

--[=[
    Asserts that a symbolic node has a valid outer shape.
    @within DefinitionAssertions
    @param node any -- Node candidate
    @param path string -- Symbolic definition path used in the error message
]=]
function DefinitionAssertions.AssertNodeShape(node: any, path: string)
	local normalizedPath = DefinitionPath.From(path)
	local isValid, reason = DefinitionNodeSpec.ValidateNodeShape(node)
	_assert(isValid, ("BehaviorSystem definition node at %s %s"):format(normalizedPath, tostring(reason)))
end

--[=[
    Asserts that a composite node contains a dense, non-empty child array.
    @within DefinitionAssertions
    @param children any -- Child collection candidate
    @param path string -- Symbolic definition path used in the error message
    @param nodeType string -- Composite node label used in the error message
]=]
function DefinitionAssertions.AssertNonEmptyChildren(children: any, path: string, nodeType: string)
	local normalizedPath = DefinitionPath.From(path)
	local isValid, reason = ChildArraySpec.Validate(children)
	_assert(isValid, ("BehaviorSystem %s node at %s %s"):format(nodeType, normalizedPath, tostring(reason)))
end

--[=[
    Asserts that a leaf symbol resolves to exactly one registry.
    @within DefinitionAssertions
    @param conditions { [string]: any } -- Condition registry
    @param commands { [string]: any } -- Command registry
    @param name string -- Leaf symbol name
    @param path string -- Symbolic definition path used in the error message
]=]
function DefinitionAssertions.AssertKnownLeaf(
	conditions: { [string]: any },
	commands: { [string]: any },
	name: string,
	path: string
)
	local inConditions = _hasEntry(conditions, name)
	local inCommands = _hasEntry(commands, name)

	_assert(inConditions or inCommands, ("BehaviorSystem leaf '%s' at %s is not registered"):format(name, path))
	_assert(
		not (inConditions and inCommands),
		("BehaviorSystem leaf '%s' at %s is ambiguous across condition and command registries"):format(name, path)
	)
end

--[=[
    Asserts that a composite node is either a Sequence or Priority node.
    @within DefinitionAssertions
    @param node { [any]: any } -- Node candidate
    @param path string -- Symbolic definition path used in the error message
]=]
function DefinitionAssertions.AssertCompositeShape(node: { [any]: any }, path: string)
	local normalizedPath = DefinitionPath.From(path)
	local isValid, reason = DefinitionNodeSpec.ValidateCompositeShape(node)
	_assert(isValid, ("BehaviorSystem composite node at %s %s"):format(normalizedPath, tostring(reason)))
end

--[=[
    Asserts that a node is a valid Sequence composite.
    @within DefinitionAssertions
    @param node any -- Node candidate
    @param path string -- Symbolic definition path used in the error message
]=]
function DefinitionAssertions.AssertSequenceNode(node: any, path: string)
	_assert(_isSequenceNode(node), ("BehaviorSystem node at %s is not a valid Sequence node"):format(path))
end

--[=[
    Asserts that a node is a valid Priority composite.
    @within DefinitionAssertions
    @param node any -- Node candidate
    @param path string -- Symbolic definition path used in the error message
]=]
function DefinitionAssertions.AssertPriorityNode(node: any, path: string)
	_assert(_isPriorityNode(node), ("BehaviorSystem node at %s is not a valid Priority node"):format(path))
end

return table.freeze(DefinitionAssertions)
