--!strict

--[=[
	@class BehaviorSystemHelpers
	Public helper functions for constructing behavior-tree nodes and inspecting symbolic behavior definitions.
	@server
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorTree = require(ReplicatedStorage.Utilities.BehaviorTree)

local Helpers = {}

-- Public task constructors

--[=[
	Wraps a raw task config in a `BehaviorTree` task instance.
	@within BehaviorSystemHelpers
	@param config { [string]: any } -- Task config, including a `run` function
	@return any -- BehaviorTree task instance
]=]
function Helpers.CreateTask(config: { [string]: any })
	assert(type(config) == "table", "BehaviorSystem.Helpers.CreateTask requires a config table")
	assert(type(config.run) == "function", "BehaviorSystem.Helpers.CreateTask requires a run function")
	return BehaviorTree.Task:new(config)
end

--[=[
	Creates a condition task that resolves to success or failure.
	@within BehaviorSystemHelpers
	@param run (task: any, ctx: any) -> () -- Condition task body
	@return any -- BehaviorTree task instance
]=]
function Helpers.CreateConditionTask(run: (task: any, ctx: any) -> ())
	assert(type(run) == "function", "BehaviorSystem.Helpers.CreateConditionTask requires a run function")
	return Helpers.CreateTask({
		run = run,
	})
end

--[=[
	Creates a command task that requests intent from runtime context state.
	@within BehaviorSystemHelpers
	@param run (task: any, ctx: any) -> () -- Command task body
	@return any -- BehaviorTree task instance
]=]
function Helpers.CreateCommandTask(run: (task: any, ctx: any) -> ())
	assert(type(run) == "function", "BehaviorSystem.Helpers.CreateCommandTask requires a run function")
	return Helpers.CreateTask({
		run = run,
	})
end

--[=[
	Creates a sequence node from already resolved children.
	@within BehaviorSystemHelpers
	@param nodes { any } -- Ordered child nodes
	@return any -- BehaviorTree sequence instance
]=]
function Helpers.CreateSequence(nodes: { any })
	assert(type(nodes) == "table", "BehaviorSystem.Helpers.CreateSequence requires a node array")
	assert(next(nodes) ~= nil, "BehaviorSystem.Helpers.CreateSequence requires at least one node")
	return BehaviorTree.Sequence:new({
		nodes = nodes,
	})
end

--[=[
	Creates a priority node from already resolved children.
	@within BehaviorSystemHelpers
	@param nodes { any } -- Ordered child nodes
	@return any -- BehaviorTree priority instance
]=]
function Helpers.CreatePriority(nodes: { any })
	assert(type(nodes) == "table", "BehaviorSystem.Helpers.CreatePriority requires a node array")
	assert(next(nodes) ~= nil, "BehaviorSystem.Helpers.CreatePriority requires at least one node")
	return BehaviorTree.Priority:new({
		nodes = nodes,
	})
end

-- Symbol predicates

--[=[
	Checks whether a definition node is a leaf symbol.
	@within BehaviorSystemHelpers
	@param node any -- Node to inspect
	@return boolean -- Whether the node is a leaf symbol
]=]
function Helpers.IsLeafNode(node: any): boolean
	return type(node) == "string"
end

--[=[
	Checks whether a definition node uses sequence composition.
	@within BehaviorSystemHelpers
	@param node any -- Node to inspect
	@return boolean -- Whether the node is a sequence node
]=]
function Helpers.IsSequenceNode(node: any): boolean
	return type(node) == "table" and type(node.Sequence) == "table"
end

--[=[
	Checks whether a definition node uses priority composition.
	@within BehaviorSystemHelpers
	@param node any -- Node to inspect
	@return boolean -- Whether the node is a priority node
]=]
function Helpers.IsPriorityNode(node: any): boolean
	return type(node) == "table" and type(node.Priority) == "table"
end

--[=[
	Checks whether a condition registry contains a symbol.
	@within BehaviorSystemHelpers
	@param registry { [string]: any } -- Registry to inspect
	@param name string -- Symbol name to look up
	@return boolean -- Whether the symbol is present in the condition registry
]=]
function Helpers.HasCondition(registry: { [string]: any }, name: string): boolean
	return type(registry) == "table" and registry[name] ~= nil
end

--[=[
	Checks whether a command registry contains a symbol.
	@within BehaviorSystemHelpers
	@param registry { [string]: any } -- Registry to inspect
	@param name string -- Symbol name to look up
	@return boolean -- Whether the symbol is present in the command registry
]=]
function Helpers.HasCommand(registry: { [string]: any }, name: string): boolean
	return type(registry) == "table" and registry[name] ~= nil
end

return table.freeze(Helpers)
