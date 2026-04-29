--!strict

--[=[
	@class BehaviorSystemEntry
	Module table that exposes the shared BehaviorSystem builder, validator, types, and helper surface.
	@prop Builder BehaviorSystemBuilder -- Build facade for symbolic behavior compilation
	@prop Runtime BehaviorSystemRuntime -- Runtime facade for action registration and dispatch
	@prop Validator BehaviorSystemValidator -- Shared registry and definition validator
	@prop Types BehaviorSystemTypes -- Shared type definitions for the module surface
	@prop Helpers BehaviorSystemHelpers -- Helper constructors and node predicates
	@server
	@client
]=]

local Builder = require(script.Contexts.BuildContext.Builder)
local Runtime = require(script.Contexts.RuntimeContext.Runtime)
local Validator = require(script.SharedDomain.Services.Validator)
local Types = require(script.SharedDomain.Types)
local Helpers = require(script.Infrastructure.Helpers)

local BehaviorSystem = {
	Builder = Builder,
	Runtime = Runtime,
	Validator = Validator,
	Types = Types,
	Helpers = Helpers,
}

--[=[
	Creates a runtime facade for the supplied condition and command registries.
	@within BehaviorSystemEntry
	@param config Types.TBuilderConfig -- Registry bundle used to configure runtime compilation and dispatch
	@return BehaviorSystemRuntime -- Runtime facade instance
]=]
function BehaviorSystem.new(config: Types.TBuilderConfig)
	return Runtime.new(config)
end

return table.freeze(BehaviorSystem)
