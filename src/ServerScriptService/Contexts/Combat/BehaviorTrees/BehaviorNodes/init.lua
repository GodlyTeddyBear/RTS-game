--!strict

local Conditions = require(script.Conditions)
local Commands = require(script.Commands)

--[=[
	@class BehaviorNodes
	Re-exports combat behavior tree condition and command node builders.
]=]
local BehaviorNodes = {
	Conditions = Conditions,
	Commands = Commands,
}

return table.freeze(BehaviorNodes)
