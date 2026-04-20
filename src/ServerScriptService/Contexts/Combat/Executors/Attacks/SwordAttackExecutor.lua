--!strict

--[[
    SwordAttackExecutor - Committed sword attack against a target entity.

    Produced by AttackExecutorFactory. Medium-range melee with standard hitbox.
]]

local AttackExecutorFactory = require(script.Parent.Parent.Factories.AttackExecutorFactory)

return AttackExecutorFactory({ ActionId = "SwordAttack", IsInterruptible = false })
