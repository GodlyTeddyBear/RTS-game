--!strict

--[=[
	@class BehaviorSystemValidator
	Validates BehaviorSystem registries and symbolic behavior definition shapes before compilation.
	@server
	@client
]=]

local DefinitionAssertions = require(script.Parent.Parent.Assertions.DefinitionAssertions)
local DefinitionPath = require(script.Parent.Parent.ValueObjects.DefinitionPath)

local Validator = {}

local assertRegistryTable = DefinitionAssertions.AssertRegistryTable
local assertRegistryFunction = DefinitionAssertions.AssertRegistryFunction
local assertNodeShape = DefinitionAssertions.AssertNodeShape
local assertKnownLeaf = DefinitionAssertions.AssertKnownLeaf
local assertCompositeShape = DefinitionAssertions.AssertCompositeShape
local assertSequenceNode = DefinitionAssertions.AssertSequenceNode
local assertPriorityNode = DefinitionAssertions.AssertPriorityNode
local assertNonEmptyChildren = DefinitionAssertions.AssertNonEmptyChildren

local MAX_DEFINITION_DEPTH = 128

-- Validate a registry table and its builder entries before recursive definition checks begin.
local function _validateRegistry(registry: { [string]: any }, label: string)
	-- Validate the registry container before checking individual entries
	assertRegistryTable(registry, label)

	-- Ensure every registry key is a stable, non-empty symbol name
	for name, builder in pairs(registry) do
		assert(type(name) == "string" and #name > 0, ("BehaviorSystem %s registry keys must be non-empty strings"):format(label))
		assertRegistryFunction(name, builder, label)
	end
end

-- Recursively validate a definition node while preserving the path for clearer errors.
local function _validateNode(
	node: any,
	conditions: { [string]: any },
	commands: { [string]: any },
	path: string,
	depth: number
)
	-- Normalize the path and enforce the recursion limit before inspecting node shape
	local normalizedPath = DefinitionPath.From(path)
	assert(
		depth <= MAX_DEFINITION_DEPTH,
		("BehaviorSystem definition node at %s exceeds max depth (%d)"):format(normalizedPath, MAX_DEFINITION_DEPTH)
	)

	-- Validate the outer node shape before branching into leaf or composite handling
	assertNodeShape(node, normalizedPath)

	if type(node) == "string" then
		-- Resolve leaves directly against the registries so ambiguous symbols fail early
		assertKnownLeaf(conditions, commands, node, normalizedPath)
		return
	end

	-- Composite nodes must declare exactly one supported child collection
	assertCompositeShape(node, normalizedPath)

	if node.Sequence ~= nil then
		-- Validate the sequence node and recurse through its ordered children
		assertSequenceNode(node, normalizedPath)
		assertNonEmptyChildren(node.Sequence, normalizedPath, "Sequence")

		for index, child in ipairs(node.Sequence) do
			_validateNode(child, conditions, commands, ("%s.Sequence[%d]"):format(normalizedPath, index), depth + 1)
		end

		return
	end

	-- Priority nodes reuse the same recursion path but preserve priority-specific labels in errors
	assertPriorityNode(node, normalizedPath)
	assertNonEmptyChildren(node.Priority, normalizedPath, "Priority")

	for index, child in ipairs(node.Priority) do
		_validateNode(child, conditions, commands, ("%s.Priority[%d]"):format(normalizedPath, index), depth + 1)
	end
end

--[=[
	Validates the condition and command registry tables that feed behavior compilation.
	@within BehaviorSystemValidator
	@param registries { Conditions: { [string]: any }, Commands: { [string]: any } } -- Registry tables used during validation
]=]
function Validator.ValidateRegistries(registries: { Conditions: { [string]: any }, Commands: { [string]: any } })
	assert(type(registries) == "table", "BehaviorSystem registries must be provided as a table")
	_validateRegistry(registries.Conditions, "Conditions")
	_validateRegistry(registries.Commands, "Commands")
end

--[=[
	Validates a symbolic behavior definition against a pair of registries.
	@within BehaviorSystemValidator
	@param definition any -- Symbolic tree root to validate
	@param registries { Conditions: { [string]: any }, Commands: { [string]: any } } -- Registry tables used during validation
]=]
function Validator.ValidateDefinition(
	definition: any,
	registries: { Conditions: { [string]: any }, Commands: { [string]: any } }
)
	Validator.ValidateRegistries(registries)
	_validateNode(definition, registries.Conditions, registries.Commands, "Root", 1)
end

return table.freeze(Validator)
