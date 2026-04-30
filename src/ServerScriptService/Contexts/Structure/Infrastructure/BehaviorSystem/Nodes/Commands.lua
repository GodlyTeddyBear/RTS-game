--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local BehaviorSystem = AI.GetBehaviorSystem()

local function _RequireActionFactory(context: any): any
	local actionFactory = context.ActionFactory
	assert(
		type(actionFactory) == "table" and type(actionFactory.SetPendingAction) == "function",
		"Structure command nodes require context.ActionFactory:SetPendingAction"
	)
	return actionFactory
end

local Commands = {
	StructureAttack = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			local actionFactory = _RequireActionFactory(context)
			actionFactory:SetPendingAction(context.Entity, "Structure.Attack", {
				TargetEnemyEntity = context.Facts.TargetEnemyEntity,
			})
			task:success()
		end)
	end,
}

return table.freeze(Commands)
