--!strict

--[=[
	@class BehaviorSystemBuilder
	Compiles symbolic behavior definitions into concrete `BehaviorTree` instances after validating the registered condition and command builders.
	@server
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorTree = require(ReplicatedStorage.Utilities.BehaviorTree)

local NodeResolver = require(script.Parent.Internal.NodeResolver)
local Validator = require(script.Parent.Validator)
local Types = require(script.Parent.Types)

type TBuilderConfig = Types.TBuilderConfig

local Builder = {}
Builder.__index = Builder

-- Public

--[=[
	Creates a builder with validated condition and command registries.
	@within BehaviorSystemBuilder
	@param config TBuilderConfig -- Registry table used to compile behavior definitions
	@return BehaviorSystemBuilder -- Configured builder instance
]=]
function Builder.new(config: TBuilderConfig)
	Validator.ValidateRegistries(config)

	local self = setmetatable({}, Builder)
	self._conditions = config.Conditions
	self._commands = config.Commands
	self._resolver = NodeResolver.new(config.Conditions, config.Commands)
	return self
end

--[=[
	Validates a symbolic behavior definition against the builder's registries.
	@within BehaviorSystemBuilder
	@param definition TBehaviorDefinitionNode -- Symbolic tree root to validate
]=]
function Builder:Validate(definition: Types.TBehaviorDefinitionNode)
	Validator.ValidateDefinition(definition, {
		Conditions = self._conditions,
		Commands = self._commands,
	})
end

--[=[
	Validates and compiles a symbolic behavior definition into a concrete `BehaviorTree`.
	@within BehaviorSystemBuilder
	@param definition TBehaviorDefinitionNode -- Symbolic tree root to compile
	@return BehaviorTree -- Compiled behavior tree instance
]=]
function Builder:Build(definition: Types.TBehaviorDefinitionNode)
	self:Validate(definition)

	return BehaviorTree:new({
		tree = self._resolver:ResolveNode(definition, "Root"),
	})
end

return table.freeze(Builder)
