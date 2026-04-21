--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)

local RunPhaseViewModel = require(script.Parent.Parent.ViewModels.RunPhaseViewModel)
local useRunState = require(script.Parent.useRunState)

local function useRunPhaseHud(): RunPhaseViewModel.TRunPhaseViewData
	local runState = useRunState()
	local now, setNow = React.useState(function()
		return Workspace:GetServerTimeNow()
	end)

	React.useEffect(function()
		local isMounted = true
		task.spawn(function()
			while isMounted do
				setNow(Workspace:GetServerTimeNow())
				task.wait(0.25)
			end
		end)

		return function()
			isMounted = false
		end
	end, {})

	return RunPhaseViewModel.fromSnapshot(runState, now)
end

return useRunPhaseHud
