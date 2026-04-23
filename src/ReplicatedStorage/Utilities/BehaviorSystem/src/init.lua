--!strict

--[=[
	@class BehaviorSystemEntry
	Module table that exposes the shared BehaviorSystem builder, validator, types, and helper surface.
	@server
	@client
]=]

local Builder = require(script.Builder)
local Runtime = require(script.Runtime)
local Validator = require(script.Validator)
local Types = require(script.Types)
local Helpers = require(script.Helpers)

local BehaviorSystem = {
	Builder = Builder,
	Runtime = Runtime,
	Validator = Validator,
	Types = Types,
	Helpers = Helpers,
}

function BehaviorSystem.new(config: Types.TBuilderConfig)
	return Runtime.new(config)
end

return table.freeze(BehaviorSystem)
