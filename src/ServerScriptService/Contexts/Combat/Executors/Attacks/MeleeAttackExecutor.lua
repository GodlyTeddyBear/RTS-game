--!strict

--[[
    MeleeAttackExecutor - Committed melee attack against a target entity.

    Produced by AttackExecutorFactory. Checks target alive, attack cooldown,
    then calculates and applies damage via BaseExecutor:_ExecuteAttackTick.

    Returns "Success" after a single attack lands (one-shot per activation).
    The BT will re-select this executor on the next tick if still in range.
]]

local AttackExecutorFactory = require(script.Parent.Parent.Factories.AttackExecutorFactory)

return AttackExecutorFactory({ ActionId = "MeleeAttack", IsInterruptible = false })
