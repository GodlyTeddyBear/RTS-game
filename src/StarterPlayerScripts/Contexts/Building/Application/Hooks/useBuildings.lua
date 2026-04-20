--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local useAtom = ReactCharm.useAtom
local useEffect = React.useEffect

local SharedAtoms = require(ReplicatedStorage.Contexts.Building.Sync.SharedAtoms)

--[=[
	Subscribes to the buildings atom and returns the current player's full buildings map.
	Requests fresh hydration on mount to ensure data is up to date.
	@within useBuildings
	@return SharedAtoms.TBuildingsMap -- The reactive buildings map
	@yields
]=]
local function useBuildings(): SharedAtoms.TBuildingsMap
	local buildingController = Knit.GetController("BuildingController")

	-- Request fresh buildings state on component mount
	useEffect(function()
		if buildingController then
			task.spawn(function()
				buildingController:RequestBuildingsState()
			end)
		end
	end, {})

	if not buildingController then
		warn("useBuildings: BuildingController not available")
		return {}
	end

	local buildingsAtom = buildingController:GetBuildingsAtom()
	return useAtom(buildingsAtom)
end

return useBuildings
