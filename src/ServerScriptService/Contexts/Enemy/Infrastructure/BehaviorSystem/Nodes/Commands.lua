--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local BehaviorSystem = AI.GetBehaviorSystem()

local function _requireActionFactory(context: any): any
	local actionFactory = context.ActionFactory
	assert(
		type(actionFactory) == "table" and type(actionFactory.SetPendingAction) == "function",
		"Combat command nodes require context.ActionFactory:SetPendingAction"
	)
	return actionFactory
end

--[=[
	@class CombatBehaviorCommands
	Provides Combat-local BehaviorSystem command node builders.
	@server
]=]
local Commands = {
	Advance = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			local actionFactory = _requireActionFactory(context)
			actionFactory:SetPendingAction(context.Entity, "Advance", nil)
			task:success()
		end)
	end,
	Idle = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			local actionFactory = _requireActionFactory(context)
			actionFactory:SetPendingAction(context.Entity, "Idle", nil)
			task:success()
		end)
	end,
	AttackStructure = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			local actionFactory = _requireActionFactory(context)
			actionFactory:SetPendingAction(context.Entity, "AttackStructure", {
				TargetStructureEntity = context.Facts.TargetStructureEntity,
			})
			task:success()
		end)
	end,
	AttackBase = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			local actionFactory = _requireActionFactory(context)
			actionFactory:SetPendingAction(context.Entity, "AttackBase", nil)
			task:success()
		end)
	end,
	StructureAttack = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			local actionFactory = _requireActionFactory(context)
			actionFactory:SetPendingAction(context.Entity, "StructureAttack", {
				TargetEnemyEntity = context.Facts.TargetEnemyEntity,
			})
			task:success()
		end)
	end,
}

return table.freeze(Commands)
