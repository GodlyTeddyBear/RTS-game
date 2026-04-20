--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ZoneConfig = require(ReplicatedStorage.Contexts.Quest.Config.ZoneConfig)
local ZoneUnlockConfig = require(ReplicatedStorage.Contexts.Quest.Config.ZoneUnlockConfig)
local UnlockTypes = require(ReplicatedStorage.Contexts.Unlock.Types.UnlockTypes)

type TUnlockState = UnlockTypes.TUnlockState

--[=[
	@interface TZoneViewModel
	View model for a single zone/quest display.
	@within ZoneViewModel
	.ZoneId string -- Unique identifier for the zone
	.DisplayName string -- Human-readable zone name
	.Description string -- Zone description text
	.TierLabel string -- Difficulty tier label (e.g. "Apprentice", "Expert")
	.WaveCountLabel string -- Formatted wave count (e.g. "3 Waves")
	.RecommendedATKLabel string -- Recommended ATK stat for zone (formatted)
	.RecommendedDEFLabel string -- Recommended DEF stat for zone (formatted)
	.MinPartySize number -- Minimum number of adventurers required
	.MaxPartySize number -- Maximum number of adventurers allowed
	.IsUnlocked boolean -- Whether this zone is currently unlocked for the player
]=]
export type TZoneViewModel = {
	ZoneId: string,
	DisplayName: string,
	Description: string,
	TierLabel: string,
	WaveCountLabel: string,
	RecommendedATKLabel: string,
	RecommendedDEFLabel: string,
	MinPartySize: number,
	MaxPartySize: number,
	IsUnlocked: boolean,
}

--[=[
	@class ZoneViewModel
	Transforms zone configuration into view models for quest board display.
	@client
]=]
local ZoneViewModel = {}

local function isZoneUnlocked(zoneId: string, unlockState: TUnlockState?): boolean
	local entry = ZoneUnlockConfig[zoneId]
	if not entry or entry.StartsUnlocked then
		return true
	end

	if not unlockState then
		return false
	end

	return unlockState[zoneId] == true
end

--[=[
	Transform a single zone config entry into a view model.
	@within ZoneViewModel
	@param zoneId string -- The ID of the zone to transform
	@return TZoneViewModel? -- Frozen view model or nil if zone not found
]=]
function ZoneViewModel.fromZoneConfig(zoneId: string, unlockState: TUnlockState?): TZoneViewModel?
	local zone = ZoneConfig[zoneId]
	if not zone then
		return nil
	end

	local tierNames = { "Apprentice", "Journeyman", "Expert" }
	local tierLabel = tierNames[zone.Tier] or ("Tier " .. tostring(zone.Tier))

	return table.freeze({
		ZoneId = zone.ZoneId,
		DisplayName = zone.DisplayName,
		Description = zone.Description,
		TierLabel = tierLabel,
		WaveCountLabel = tostring(zone.WaveCount) .. " Waves",
		RecommendedATKLabel = "ATK " .. tostring(zone.RecommendedATK) .. "+",
		RecommendedDEFLabel = "DEF " .. tostring(zone.RecommendedDEF) .. "+",
		MinPartySize = zone.MinPartySize,
		MaxPartySize = zone.MaxPartySize,
		IsUnlocked = isZoneUnlocked(zoneId, unlockState),
	} :: TZoneViewModel)
end

--[=[
	Build view models for all zones in the config, sorted by difficulty tier.
	@within ZoneViewModel
	@return { TZoneViewModel } -- Sorted array of zone view models
]=]
function ZoneViewModel.buildAll(unlockState: TUnlockState?): { TZoneViewModel }
	local vms = {}
	for zoneId in pairs(ZoneConfig) do
		local vm = ZoneViewModel.fromZoneConfig(zoneId, unlockState)
		if vm then
			table.insert(vms, vm)
		end
	end
	table.sort(vms, function(a, b)
		return ZoneConfig[a.ZoneId].Tier < ZoneConfig[b.ZoneId].Tier
	end)
	return vms
end

return ZoneViewModel
