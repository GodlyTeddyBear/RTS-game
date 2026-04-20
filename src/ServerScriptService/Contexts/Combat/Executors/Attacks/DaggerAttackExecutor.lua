--!strict

--[[
    DaggerAttackExecutor - Committed dagger attack against a target entity.

    Produced by AttackExecutorFactory. Short-range melee with fast cooldown.
]]

local AttackExecutorFactory = require(script.Parent.Parent.Factories.AttackExecutorFactory)

return AttackExecutorFactory({ ActionId = "DaggerAttack", IsInterruptible = false })
