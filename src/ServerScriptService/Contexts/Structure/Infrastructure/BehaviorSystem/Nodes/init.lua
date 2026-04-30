--!strict

local Conditions = require(script.Conditions)
local Commands = require(script.Commands)

local Nodes = {
	Conditions = Conditions,
	Commands = Commands,
}

return table.freeze(Nodes)
