--!strict

--[=[
	@class BehaviorSystemTypes
	Shared type definitions for BehaviorSystem registries, builder config, and symbolic tree nodes.
	@server
	@client
]=]

local Types = {}

--[=[
	Builder function that creates a condition task from optional configuration.
	@within BehaviorSystemTypes
	@type TConditionBuilder (options: any?) -> any
]=]
export type TConditionBuilder = (options: any?) -> any

--[=[
	Builder function that creates a command task from optional configuration.
	@within BehaviorSystemTypes
	@type TCommandBuilder (options: any?) -> any
]=]
export type TCommandBuilder = (options: any?) -> any

--[=[
	Registry map from condition symbol names to builder functions.
	@within BehaviorSystemTypes
	@type TConditionRegistry { [string]: TConditionBuilder }
]=]
export type TConditionRegistry = { [string]: TConditionBuilder }

--[=[
	Registry map from command symbol names to builder functions.
	@within BehaviorSystemTypes
	@type TCommandRegistry { [string]: TCommandBuilder }
]=]
export type TCommandRegistry = { [string]: TCommandBuilder }

--[=[
	Registry bundle required to construct a BehaviorSystem builder.
	@within BehaviorSystemTypes
	@interface TBuilderConfig
	.Conditions TConditionRegistry -- Condition builder registry used to resolve leaf symbols
	.Commands TCommandRegistry -- Command builder registry used to resolve leaf symbols
]=]
export type TBuilderConfig = {
	Conditions: TConditionRegistry,
	Commands: TCommandRegistry,
}

--[=[
	Sequence node shape used by symbolic behavior definitions.
	@within BehaviorSystemTypes
	@interface TBehaviorSequenceNode
	.Sequence { TBehaviorDefinitionNode } -- Ordered child nodes evaluated left to right
]=]
export type TBehaviorSequenceNode = {
	Sequence: { TBehaviorDefinitionNode },
}

--[=[
	Priority node shape used by symbolic behavior definitions.
	@within BehaviorSystemTypes
	@interface TBehaviorPriorityNode
	.Priority { TBehaviorDefinitionNode } -- Ordered child nodes evaluated until one succeeds
]=]
export type TBehaviorPriorityNode = {
	Priority: { TBehaviorDefinitionNode },
}

--[=[
	Symbolic behavior definitions accepted by the builder and validator.
	@within BehaviorSystemTypes
	@type TBehaviorDefinitionNode string | TBehaviorSequenceNode | TBehaviorPriorityNode
]=]
export type TBehaviorDefinitionNode = string | TBehaviorSequenceNode | TBehaviorPriorityNode

return table.freeze(Types)
