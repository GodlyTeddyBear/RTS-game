--!strict

--[[
    StaffAttackExecutor - Committed ranged staff attack against a target entity.

    Produced by AttackExecutorFactory. Ranged hitbox spawns at target position.
]]

local AttackExecutorFactory = require(script.Parent.Parent.Factories.AttackExecutorFactory)

return AttackExecutorFactory({ ActionId = "StaffAttack", IsInterruptible = false })
