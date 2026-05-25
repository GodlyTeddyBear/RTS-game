--!strict

--[=[
    @class UnitBehaviorCommands
    Exposes the unit behavior command nodes used by the unit behavior graph.

    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AI = require(ServerStorage.Utilities.ContextUtilities.AI)
local BehaviorSystem = AI.GetBehaviorSystem()

local Commands = {
	UnitIdle = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			-- Clear any pending action so the unit remains in the idle behavior state.
			context.ActionFactory:SetPendingAction(context.Entity, "Unit.Idle", nil)

			task:success()
		end)
	end,
	UnitManualMove = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			-- Hand the action factory a manual-move action so the movement executor can take over.
			context.ActionFactory:SetPendingAction(context.Entity, "Unit.ManualMove", nil)

			task:success()
		end)
	end,
}

return table.freeze(Commands)
