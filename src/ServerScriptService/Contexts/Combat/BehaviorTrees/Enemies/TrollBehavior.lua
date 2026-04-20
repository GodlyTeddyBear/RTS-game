--!strict

--[[
    TrollBehavior - Behavior tree for Troll enemies.

    Currently uses the same tree structure as GoblinBehavior.
    Can be customized with different conditions/actions as needed.
    Trolls differentiate via higher stats and different BehaviorConfig values.
]]

local GoblinBehavior = require(script.Parent.GoblinBehavior)

return {
	CreateTree = GoblinBehavior.CreateTree,
}
