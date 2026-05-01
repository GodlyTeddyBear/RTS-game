--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[=[
	@class BehaviorSystemValidator
	Validates BehaviorSystem registries and symbolic behavior definition shapes before compilation.
	@server
	@client
]=]

local DefinitionValidationPolicy = require(script.Parent.Parent.Policies.DefinitionValidationPolicy)
local Result = require(ReplicatedStorage.Utilities.Result)

local Try = Result.Try

local Validator = {}

local MAX_DEFINITION_DEPTH = 128

-- Validate a registry table and its builder entries before recursive definition checks begin.
local function _validateRegistry(registry: { [string]: any }, label: string)
	-- Validate the registry container before checking individual entries
	Try(DefinitionValidationPolicy.CheckRegistryTable(registry, label))

	-- Ensure every registry key is a stable, non-empty symbol name
	for name, builder in pairs(registry) do
		Try(DefinitionValidationPolicy.CheckRegistryFunction(name, builder, label))
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
	-- Enforce the recursion limit before inspecting node shape
	Try(DefinitionValidationPolicy.CheckDefinitionDepth(depth, MAX_DEFINITION_DEPTH, path))

	-- Validate the outer node shape before branching into leaf or composite handling
	Try(DefinitionValidationPolicy.CheckNodeShape(node, path))

	if type(node) == "string" then
		-- Resolve leaves directly against the registries so ambiguous symbols fail early
		Try(DefinitionValidationPolicy.CheckKnownLeaf(conditions, commands, node, path))
		return
	end

	-- Composite nodes must declare exactly one supported child collection
	Try(DefinitionValidationPolicy.CheckCompositeShape(node, path))

	if node.Sequence ~= nil then
		-- Validate the sequence node and recurse through its ordered children
		Try(DefinitionValidationPolicy.CheckSequenceNode(node, path))
		Try(DefinitionValidationPolicy.CheckNonEmptyChildren(node.Sequence, path, "Sequence"))

		for index, child in ipairs(node.Sequence) do
			_validateNode(child, conditions, commands, ("%s.Sequence[%d]"):format(path, index), depth + 1)
		end

		return
	end

	-- Priority nodes reuse the same recursion path but preserve priority-specific labels in errors
	Try(DefinitionValidationPolicy.CheckPriorityNode(node, path))
	Try(DefinitionValidationPolicy.CheckNonEmptyChildren(node.Priority, path, "Priority"))

	for index, child in ipairs(node.Priority) do
		_validateNode(child, conditions, commands, ("%s.Priority[%d]"):format(path, index), depth + 1)
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
