--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

--[=[
	Exposes building mutation actions without subscribing to any atom (no re-renders).
	@within useBuildingActions
	@return table -- Object with constructBuilding and upgradeBuilding methods
]=]
local function useBuildingActions()
	-- Requests a new building construction in the specified zone slot
	local function constructBuilding(zoneName: string, slotIndex: number, buildingType: string)
		local controller = Knit.GetController("BuildingController")
		if not controller then
			warn("useBuildingActions: BuildingController not available")
			return
		end
		return controller:ConstructBuilding(zoneName, slotIndex, buildingType)
	end

	-- Requests an upgrade of the building at the specified zone slot
	local function upgradeBuilding(zoneName: string, slotIndex: number)
		local controller = Knit.GetController("BuildingController")
		if not controller then
			warn("useBuildingActions: BuildingController not available")
			return
		end
		return controller:UpgradeBuilding(zoneName, slotIndex)
	end

	return {
		constructBuilding = constructBuilding,
		upgradeBuilding = upgradeBuilding,
	}
end

return useBuildingActions
