--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingConfig = require(ReplicatedStorage.Contexts.Building.Config.BuildingConfig)

--[=[
	@class MachineEligibility
	Provides domain helpers for validating machine slot and recipe compatibility.
	@server
]=]
local MachineEligibility = {}

--[=[
	@type TAllBuildings { [string]: { [number]: { BuildingType: string, Level: number } } }
	@within MachineEligibility
]=]
export type TAllBuildings = { [string]: { [number]: { BuildingType: string, Level: number } } }

--[=[
	Check whether a slot's building type satisfies recipe machine requirements.
	@within MachineEligibility
	@param slotBuildingType string -- Slot building type key.
	@param requiredMachines { string }? -- Accepted machine type keys for the recipe.
	@return boolean -- True when slot machine is allowed for the recipe.
]=]
function MachineEligibility.SlotBuildingMatchesRecipe(slotBuildingType: string, requiredMachines: { string }?): boolean
	if not requiredMachines or #requiredMachines == 0 then
		return true
	end
	for _, req in requiredMachines do
		if req == slotBuildingType then
			return true
		end
	end
	return false
end

--[=[
	Get machine-capable building definition for a slot.
	@within MachineEligibility
	@param zoneName string -- Zone name containing the slot.
	@param buildingType string -- Building type key in that slot.
	@return any -- Building config definition, or `nil` when not found.
]=]
function MachineEligibility.GetMachineDefForSlot(zoneName: string, buildingType: string)
	local zoneDef = BuildingConfig[zoneName]
	local def = zoneDef and zoneDef.Buildings[buildingType]
	return def
end

--[=[
	Check whether a slot building supports fuel-driven machine processing.
	@within MachineEligibility
	@param zoneName string -- Zone name containing the slot.
	@param buildingType string -- Building type key in that slot.
	@return boolean -- True when building has valid fuel machine config.
]=]
function MachineEligibility.SlotIsFuelMachine(zoneName: string, buildingType: string): boolean
	local def = MachineEligibility.GetMachineDefForSlot(zoneName, buildingType)
	if not def or not def.FuelItemId or not def.FuelBurnDurationSeconds then
		return false
	end
	return def.FuelBurnDurationSeconds > 0
end

return MachineEligibility
