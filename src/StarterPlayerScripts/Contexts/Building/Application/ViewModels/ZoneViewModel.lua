--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingConfig = require(ReplicatedStorage.Contexts.Building.Config.BuildingConfig)

--[=[
	@type TZoneInfo
	@within ZoneViewModel
	.Name string -- Zone name identifier
	.MaxSlots number -- Maximum building slots in the zone
	.IsRemote boolean -- Whether this is a remote zone
]=]
export type TZoneInfo = {
	Name: string,
	MaxSlots: number,
	IsRemote: boolean,
}

--[=[
	@type TZoneGroup
	@within ZoneViewModel
	.Label string -- Display label for the zone group
	.Zones { TZoneInfo } -- Zones in this group
]=]
export type TZoneGroup = {
	Label: string,
	Zones: { TZoneInfo },
}

--[=[
	@type TZoneGroups
	@within ZoneViewModel
	.localGroup TZoneGroup -- Local zones (player-accessible)
	.remoteGroup TZoneGroup -- Remote zones (server-side)
]=]
export type TZoneGroups = {
	localGroup: TZoneGroup,
	remoteGroup: TZoneGroup,
}

-- Ordered zone lists — order controls tab display order
local LOCAL_ZONE_NAMES = { "Forge", "Brewery", "TailorShop" }
local REMOTE_ZONE_NAMES = { "Farm", "Garden", "Forest", "Mines" }

--[=[
	@class ZoneViewModel
	Transforms raw zone configuration into UI-ready zone metadata.
]=]
local ZoneViewModel = {}

--[=[
	Builds zone groups (local and remote) with their zone metadata.
	Zones missing from BuildingConfig are skipped gracefully.
	@within ZoneViewModel
	@return TZoneGroups -- Two grouped zone lists with metadata
]=]
function ZoneViewModel.buildZoneGroups(): TZoneGroups
	local localZones: { TZoneInfo } = {}
	for _, name in LOCAL_ZONE_NAMES do
		local def = BuildingConfig[name]
		if def then
			table.insert(localZones, {
				Name = name,
				MaxSlots = def.MaxSlots,
				IsRemote = false,
			})
		end
	end

	local remoteZones: { TZoneInfo } = {}
	for _, name in REMOTE_ZONE_NAMES do
		local def = BuildingConfig[name]
		if def then
			table.insert(remoteZones, {
				Name = name,
				MaxSlots = def.MaxSlots,
				IsRemote = true,
			})
		end
	end

	return {
		localGroup = { Label = "Local", Zones = localZones },
		remoteGroup = { Label = "Remote", Zones = remoteZones },
	}
end

--[=[
	Builds a flat ordered list of all zones (local first, then remote).
	@within ZoneViewModel
	@return { TZoneInfo } -- All zones in tab display order
]=]
function ZoneViewModel.buildFlatZoneList(): { TZoneInfo }
	local groups = ZoneViewModel.buildZoneGroups()
	local list: { TZoneInfo } = {}
	for _, zoneInfo in groups.localGroup.Zones do
		table.insert(list, zoneInfo)
	end
	for _, zoneInfo in groups.remoteGroup.Zones do
		table.insert(list, zoneInfo)
	end
	return list
end

return ZoneViewModel
