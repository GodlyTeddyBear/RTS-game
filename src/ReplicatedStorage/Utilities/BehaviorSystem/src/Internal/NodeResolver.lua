--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorTree = require(ReplicatedStorage.Utilities.BehaviorTree)
local DefinitionAssertions = require(script.Parent.DefinitionAssertions)

local NodeResolver = {}
NodeResolver.__index = NodeResolver

function NodeResolver.new(conditions: { [string]: any }, commands: { [string]: any })
	local self = setmetatable({}, NodeResolver)
	self._conditions = conditions
	self._commands = commands
	return self
end

function NodeResolver:ResolveLeaf(name: string, path: string)
	DefinitionAssertions.AssertKnownLeaf(self._conditions, self._commands, name, path)

	local conditionBuilder = self._conditions[name]
	if conditionBuilder ~= nil then
		return conditionBuilder()
	end

	local commandBuilder = self._commands[name]
	return commandBuilder()
end

function NodeResolver:ResolveSequence(children: { any }, path: string)
	return BehaviorTree.Sequence:new({
		nodes = self:_ResolveChildren(children, path .. ".Sequence"),
	})
end

function NodeResolver:ResolvePriority(children: { any }, path: string)
	return BehaviorTree.Priority:new({
		nodes = self:_ResolveChildren(children, path .. ".Priority"),
	})
end

function NodeResolver:_ResolveChildren(children: { any }, path: string)
	local resolved = table.create(#children)

	for index, child in ipairs(children) do
		resolved[index] = self:ResolveNode(child, ("%s[%d]"):format(path, index))
	end

	return resolved
end

function NodeResolver:ResolveNode(node: any, path: string)
	if type(node) == "string" then
		return self:ResolveLeaf(node, path)
	end

	if node.Sequence ~= nil then
		return self:ResolveSequence(node.Sequence, path)
	end

	return self:ResolvePriority(node.Priority, path)
end

return table.freeze(NodeResolver)
