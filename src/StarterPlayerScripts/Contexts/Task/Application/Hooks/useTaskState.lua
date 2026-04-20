--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local taskStateAtom = nil

local function useTaskState()
	if taskStateAtom == nil then
		local taskController = Knit.GetController("TaskController")
		taskStateAtom = taskController:GetTaskStateAtom()
	end

	return ReactCharm.useAtom(taskStateAtom)
end

return useTaskState
