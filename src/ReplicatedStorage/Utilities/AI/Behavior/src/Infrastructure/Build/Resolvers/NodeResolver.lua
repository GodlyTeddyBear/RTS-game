--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorTree = require(ReplicatedStorage.Utilities.BehaviorTree)
local DefinitionAssertions = require(script.Parent.Parent.Parent.Parent.SharedDomain.Assertions.DefinitionAssertions)
local DefinitionPath = require(script.Parent.Parent.Parent.Parent.SharedDomain.ValueObjects.DefinitionPath)

local NodeResolver = {}
NodeResolver.__index = NodeResolver

local MAX_DEFINITION_DEPTH = 128

function NodeResolver.new(conditions: { [string]: any }, commands: { [string]: any })
	local self = setmetatable({}, NodeResolver)
	self._conditions = conditions
	self._commands = commands
	return self
end

function NodeResolver:ResolveLeaf(name: string, path: string)
	-- Normalize the path and verify the symbol is registered before invoking a builder
	local normalizedPath = DefinitionPath.From(path)
	DefinitionAssertions.AssertKnownLeaf(self._conditions, self._commands, name, normalizedPath)

	-- Prefer the condition registry when both tables are queried by name
	local conditionBuilder = self._conditions[name]
	if conditionBuilder ~= nil then
		return conditionBuilder()
	end

	-- Fall back to the command registry after the condition lookup fails
	local commandBuilder = self._commands[name]
	return commandBuilder()
end

function NodeResolver:ResolveSequence(children: { any }, path: string, depth: number)
	-- Validate the child array before recursing so sparse or empty arrays fail at the parent node
	local normalizedPath = DefinitionPath.From(path)
	DefinitionAssertions.AssertNonEmptyChildren(children, normalizedPath, "Sequence")
	return BehaviorTree.Sequence:new({
		nodes = self:_ResolveChildren(children, normalizedPath .. ".Sequence", depth + 1),
	})
end

function NodeResolver:ResolvePriority(children: { any }, path: string, depth: number)
	-- Validate the child array before recursing so the priority node keeps a dense ordered list
	local normalizedPath = DefinitionPath.From(path)
	DefinitionAssertions.AssertNonEmptyChildren(children, normalizedPath, "Priority")
	return BehaviorTree.Priority:new({
		nodes = self:_ResolveChildren(children, normalizedPath .. ".Priority", depth + 1),
	})
end

function NodeResolver:_ResolveChildren(children: { any }, path: string, depth: number)
	-- Resolve each child in order so the composed BehaviorTree preserves definition order
	local resolved = table.create(#children)

	for index, child in ipairs(children) do
		resolved[index] = self:ResolveNode(child, ("%s[%d]"):format(path, index), depth)
	end

	return resolved
end

function NodeResolver:ResolveNode(node: any, path: string, depth: number?)
	-- Normalize the path and enforce the recursion cap before branching on node shape
	local normalizedPath = DefinitionPath.From(path)
	local currentDepth = if depth ~= nil then depth else 1
	assert(
		currentDepth <= MAX_DEFINITION_DEPTH,
		("BehaviorSystem definition node at %s exceeds max depth (%d)"):format(normalizedPath, MAX_DEFINITION_DEPTH)
	)
	DefinitionAssertions.AssertNodeShape(node, normalizedPath)

	if type(node) == "string" then
		-- Leaf nodes resolve directly to a concrete task instance
		return self:ResolveLeaf(node, normalizedPath)
	end

	-- Composite nodes must be validated before choosing the branch-specific resolver
	DefinitionAssertions.AssertCompositeShape(node, normalizedPath)

	if node.Sequence ~= nil then
		-- Sequence nodes preserve left-to-right evaluation order
		DefinitionAssertions.AssertSequenceNode(node, normalizedPath)
		return self:ResolveSequence(node.Sequence, normalizedPath, currentDepth)
	end

	-- Priority nodes preserve first-success evaluation order
	DefinitionAssertions.AssertPriorityNode(node, normalizedPath)
	return self:ResolvePriority(node.Priority, normalizedPath, currentDepth)
end

return table.freeze(NodeResolver)
