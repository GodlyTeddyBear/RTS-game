--!strict

--[=[
	@class BehaviorSystemEntry
	Module table that exposes the shared BehaviorSystem builder, validator, types, and helper surface.
	@server
	@client
]=]

local Builder = require(script.Builder)
local Validator = require(script.Validator)
local Types = require(script.Types)
local Helpers = require(script.Helpers)

local BehaviorSystem = {
	Builder = Builder,
	Validator = Validator,
	Types = Types,
	Helpers = Helpers,
}

return table.freeze(BehaviorSystem)
