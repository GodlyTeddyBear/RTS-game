--!strict

--[[
    PunchAttackExecutor - Committed unarmed punch attack against a target entity.

    Produced by AttackExecutorFactory. Shortest range, slowest cooldown, 50% damage.
    Used as fallback when no weapon is equipped.
]]

local AttackExecutorFactory = require(script.Parent.Parent.Factories.AttackExecutorFactory)

return AttackExecutorFactory({ ActionId = "PunchAttack", DamageMultiplier = 0.5, IsInterruptible = false })
