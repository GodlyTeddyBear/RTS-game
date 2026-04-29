--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorTree = require(ReplicatedStorage.Utilities.BehaviorTree)

local Types = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Types)
local ValidateDefinition = require(script.Parent.ValidateDefinition)

type TNodeResolver = {
	ResolveNode: (self: TNodeResolver, definition: Types.TBehaviorDefinitionNode, path: string) -> any,
}

local BuildBehaviorTree = {}

function BuildBehaviorTree.Execute(
	definition: Types.TBehaviorDefinitionNode,
	resolver: TNodeResolver,
	config: Types.TBuilderConfig
)
	-- Validate first so tree construction only happens for known-good definitions
	ValidateDefinition.Execute(definition, config)

	-- Resolve the symbolic root into a concrete BehaviorTree node and wrap it in the runtime tree
	return BehaviorTree:new({
		tree = resolver:ResolveNode(definition, "Root"),
	})
end

return table.freeze(BuildBehaviorTree)
