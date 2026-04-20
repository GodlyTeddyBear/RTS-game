--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local function useTaskActions()
	return {
		claimTaskReward = function(taskId: string)
			return Knit.GetController("TaskController"):ClaimTaskReward(taskId)
		end,
		requestTaskState = function()
			return Knit.GetController("TaskController"):RequestTaskState()
		end,
	}
end

return useTaskActions
