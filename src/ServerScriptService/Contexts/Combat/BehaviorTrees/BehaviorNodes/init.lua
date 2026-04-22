--!strict

local Conditions = require(script.Conditions)
local Commands = require(script.Commands)

--[=[
	@class BehaviorNodes
	Re-exports combat behavior tree condition and command node builders.
	@server
]=]
local BehaviorNodes = {
	Conditions = Conditions,
	Commands = Commands,
}

--[=[
	@prop Conditions table
	@within BehaviorNodes
	Combat condition node builders.
]=]
--[=[
	@prop Commands table
	@within BehaviorNodes
	Combat action node builders.
]=]
return table.freeze(BehaviorNodes)
