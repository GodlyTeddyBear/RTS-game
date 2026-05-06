--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local WaypointsAtom = require(script.Parent.Parent.Parent.Infrastructure.WaypointsAtom)

local function useWaypointsState()
	return ReactCharm.useAtom(WaypointsAtom.GetAtom())
end

return useWaypointsState
