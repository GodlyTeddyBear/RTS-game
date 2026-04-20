--!strict

--[[
    BehaviorNodes - Shared BT node factory functions.

    Re-exports all condition and command nodes from sub-modules so that
    existing consumers can keep the same `BehaviorNodes.XYZ()` call-site.
]]

local Conditions = require(script.Conditions)
local Commands = require(script.Commands)
local PlayerCommandNodes = require(script.PlayerCommandNodes)

local BehaviorNodes = {}

-- Conditions
BehaviorNodes.FleeCondition = Conditions.FleeCondition
BehaviorNodes.InAttackRangeCondition = Conditions.InAttackRangeCondition
BehaviorNodes.InRangeBandCondition = Conditions.InRangeBandCondition
BehaviorNodes.TooCloseCondition = Conditions.TooCloseCondition
BehaviorNodes.InAttackRangeOnlyCondition = Conditions.InAttackRangeOnlyCondition
BehaviorNodes.InRangeBandOnlyCondition = Conditions.InRangeBandOnlyCondition
BehaviorNodes.EnemyDetectedCondition = Conditions.EnemyDetectedCondition
BehaviorNodes.IncomingAttackCondition = Conditions.IncomingAttackCondition

-- Commands
BehaviorNodes.Flee = Commands.Flee
BehaviorNodes.MeleeAttack = Commands.MeleeAttack
BehaviorNodes.RangedAttack = Commands.RangedAttack
BehaviorNodes.WeaponAttack = Commands.WeaponAttack
BehaviorNodes.Chase = Commands.Chase
BehaviorNodes.Wander = Commands.Wander
BehaviorNodes.Idle = Commands.Idle
BehaviorNodes.Block = Commands.Block

-- Skills
BehaviorNodes.SkillReadyCondition = Conditions.SkillReadyCondition
BehaviorNodes.UseSkill = Commands.UseSkill

-- Player Command
BehaviorNodes.HasPlayerCommandCondition = PlayerCommandNodes.HasPlayerCommandCondition
BehaviorNodes.ExecutePlayerCommand = PlayerCommandNodes.ExecutePlayerCommand

return BehaviorNodes
