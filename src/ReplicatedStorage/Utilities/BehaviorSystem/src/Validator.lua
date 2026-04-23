--!strict

--[=[
	@class BehaviorSystemValidator
	Validates BehaviorSystem registries and symbolic behavior definition shapes before compilation.
	@server
	@client
]=]

local DefinitionAssertions = require(script.Parent.Internal.DefinitionAssertions)

local Validator = {}

-- Validate a registry table and its builder entries before recursive definition checks begin.
local function _validateRegistry(registry: { [string]: any }, label: string)
	DefinitionAssertions.AssertRegistryTable(registry, label)

	for name, builder in pairs(registry) do
		assert(type(name) == "string" and #name > 0, ("BehaviorSystem %s registry keys must be non-empty strings"):format(label))
		DefinitionAssertions.AssertRegistryFunction(name, builder, label)
	end
end

-- Recursively validate a definition node while preserving the path for clearer errors.
local function _validateNode(node: any, conditions: { [string]: any }, commands: { [string]: any }, path: string)
	DefinitionAssertions.AssertNodeShape(node, path)

	if type(node) == "string" then
		DefinitionAssertions.AssertKnownLeaf(conditions, commands, node, path)
		return
	end

	DefinitionAssertions.AssertCompositeShape(node, path)

	if node.Sequence ~= nil then
		DefinitionAssertions.AssertSequenceNode(node, path)
		DefinitionAssertions.AssertNonEmptyChildren(node.Sequence, path, "Sequence")

		for index, child in ipairs(node.Sequence) do
			_validateNode(child, conditions, commands, ("%s.Sequence[%d]"):format(path, index))
		end

		return
	end

	DefinitionAssertions.AssertPriorityNode(node, path)
	DefinitionAssertions.AssertNonEmptyChildren(node.Priority, path, "Priority")

	for index, child in ipairs(node.Priority) do
		_validateNode(child, conditions, commands, ("%s.Priority[%d]"):format(path, index))
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
	_validateNode(definition, registries.Conditions, registries.Commands, "Root")
end

return table.freeze(Validator)
