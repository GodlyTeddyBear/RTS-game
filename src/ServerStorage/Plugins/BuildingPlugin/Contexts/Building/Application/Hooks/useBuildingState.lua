--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local BuildingAtom = require(script.Parent.Parent.Parent.Infrastructure.BuildingAtom)

local function useBuildingState()
	return ReactCharm.useAtom(BuildingAtom.GetAtom())
end

return useBuildingState
