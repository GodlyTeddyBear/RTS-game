--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingConfig = require(ReplicatedStorage.Contexts.Building.Config.BuildingConfig)
local SharedAtoms = require(ReplicatedStorage.Contexts.Building.Sync.SharedAtoms)
local UnlockConfig = require(ReplicatedStorage.Contexts.Unlock.Config.UnlockConfig)
local UnlockTypes = require(ReplicatedStorage.Contexts.Unlock.Types.UnlockTypes)

type TUnlockState = UnlockTypes.TUnlockState

--[=[
	@type TSlotData
	@within SlotViewModel
	.SlotIndex number -- The slot position (1-based)
	.IsEmpty boolean -- Whether the slot has no building
	.BuildingType string? -- The building type if occupied
	.Level number? -- Current building level if occupied
	.MaxLevel number? -- Maximum level for this building
	.UpgradeCost { [string]: number }? -- Cost to upgrade to next level
	.IsMaxLevel boolean -- Whether building is at maximum level
	.DisplayLabel string -- Primary label text for the slot card
	.DisplaySublabel string? -- Secondary label text for the slot card
	.LevelText string -- Formatted "Level X / Y" string
	.UpgradeCostText string -- Formatted upgrade cost or "MAX LEVEL"
]=]
export type TSlotData = {
	SlotIndex: number,
	IsEmpty: boolean,
	BuildingType: string?,
	Level: number?,
	MaxLevel: number?,
	UpgradeCost: { [string]: number }?,
	IsMaxLevel: boolean,
	DisplayLabel: string,
	DisplaySublabel: string?,
	LevelText: string,
	UpgradeCostText: string,
}

--[=[
	@type TBuildingOption
	@within SlotViewModel
	.BuildingType string -- The building type identifier
	.Cost { [string]: number } -- Currency cost to construct
	.MaxLevel number -- Maximum upgradeable level
	.IsLocked boolean -- Whether this building type is unlocked
]=]
export type TBuildingOption = {
	BuildingType: string,
	Cost: { [string]: number },
	MaxLevel: number,
	IsLocked: boolean,
}

--[=[
	@class SlotViewModel
	Transforms player buildings data into UI-ready slot and picker data.
]=]
local SlotViewModel = {}

-- Formats a cost map into a display string (e.g. "100 Gold, 50 Stone")
local function _formatCost(cost: { [string]: number }): string
	local parts: { string } = {}
	for currency, amount in cost do
		table.insert(parts, tostring(amount) .. " " .. currency)
	end
	return table.concat(parts, ", ")
end

-- Checks if a building type is unlocked for a zone based on unlock state
local function _isBuildingUnlocked(zoneName: string, buildingType: string, unlockState: TUnlockState): boolean
	local targetId = zoneName .. "_" .. buildingType
	local entry = UnlockConfig[targetId]
	if not entry or entry.StartsUnlocked then
		return true
	end
	return unlockState[targetId] == true
end

--[=[
	Merges BuildingConfig and player buildings into per-slot display data for a zone.
	Returns exactly MaxSlots entries in slot-index order.
	@within SlotViewModel
	@param zoneName string -- The zone to build the grid for
	@param playerBuildings SharedAtoms.TBuildingsMap -- Current player buildings state
	@return { TSlotData } -- Slot data for every slot in the zone
]=]
function SlotViewModel.buildSlotGrid(
	zoneName: string,
	playerBuildings: SharedAtoms.TBuildingsMap
): { TSlotData }
	local zoneDef = BuildingConfig[zoneName]
	if not zoneDef then
		return {}
	end

	local zoneSlots = playerBuildings[zoneName]
	local slots: { TSlotData } = {}

	-- Build slot data for every slot in the zone (empty or occupied)
	for i = 1, zoneDef.MaxSlots do
		local slotData = zoneSlots and zoneSlots[i]
		if slotData then
			local buildingDef = zoneDef.Buildings[slotData.BuildingType]
			local maxLevel = buildingDef and buildingDef.MaxLevel or 1
			local isMaxLevel = slotData.Level >= maxLevel
			-- Calculate upgrade cost as (base cost * current level)
			local upgradeCost: { [string]: number }? = nil
			if not isMaxLevel and buildingDef then
				upgradeCost = {}
				for currency, amount in buildingDef.Cost do
					upgradeCost[currency] = amount * slotData.Level
				end
			end
			local upgradeCostText = if isMaxLevel
				then "MAX LEVEL"
				else if upgradeCost then "Upgrade: " .. _formatCost(upgradeCost) else "MAX LEVEL"
			table.insert(slots, {
				SlotIndex = i,
				IsEmpty = false,
				BuildingType = slotData.BuildingType,
				Level = slotData.Level,
				MaxLevel = maxLevel,
				UpgradeCost = upgradeCost,
				IsMaxLevel = isMaxLevel,
				DisplayLabel = slotData.BuildingType,
				DisplaySublabel = if isMaxLevel then "MAX LEVEL" else "Lv. " .. tostring(slotData.Level),
				LevelText = "Level " .. tostring(slotData.Level) .. " / " .. tostring(maxLevel),
				UpgradeCostText = upgradeCostText,
			})
		else
			table.insert(slots, {
				SlotIndex = i,
				IsEmpty = true,
				BuildingType = nil,
				Level = nil,
				MaxLevel = nil,
				UpgradeCost = nil,
				IsMaxLevel = false,
				DisplayLabel = "Empty",
				DisplaySublabel = "Tap to build",
				LevelText = "",
				UpgradeCostText = "",
			})
		end
	end

	return slots
end

--[=[
	Returns the list of building options available to place in a zone.
	Options are sorted alphabetically by building type.
	@within SlotViewModel
	@param zoneName string -- The zone to get building options for
	@param unlockState TUnlockState? -- Current player unlock state (optional)
	@return { TBuildingOption } -- Available building options in alphabetical order
]=]
function SlotViewModel.buildBuildingOptions(zoneName: string, unlockState: TUnlockState?): { TBuildingOption }
	local zoneDef = BuildingConfig[zoneName]
	if not zoneDef then
		return {}
	end

	local resolvedUnlockState = unlockState or {}
	local options: { TBuildingOption } = {}
	for buildingType, def in zoneDef.Buildings do
		table.insert(options, {
			BuildingType = buildingType,
			Cost = def.Cost,
			MaxLevel = def.MaxLevel,
			IsLocked = not _isBuildingUnlocked(zoneName, buildingType, resolvedUnlockState),
		})
	end

	-- Sort alphabetically for consistent UI display
	table.sort(options, function(a, b)
		return a.BuildingType < b.BuildingType
	end)

	return options
end

return SlotViewModel
