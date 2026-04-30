--!strict

local Conditions = require(script.Conditions)
local Commands = require(script.Commands)

--[=[
	@class CombatBehaviorNodes
	Re-exports Combat-local BehaviorSystem node registries.
	@server
]=]
local Nodes = {
	Conditions = Conditions,
	Commands = Commands,
}

return table.freeze(Nodes)
