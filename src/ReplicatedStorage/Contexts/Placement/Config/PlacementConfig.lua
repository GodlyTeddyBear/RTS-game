--!strict

--[=[
	@class PlacementConfig
	Defines shared placement rules and structure metadata.
	@server
	@client
]=]
local PlacementConfig = {}

-- Keep the placement costs frozen so the command layer reads stable pricing.
PlacementConfig.STRUCTURE_PLACEMENT_COSTS = table.freeze({
	turret = 15,
})

-- Base disallowed zones are global: placement is allowed by default outside these zones.
PlacementConfig.BASE_DISALLOWED_ZONE_TYPES = table.freeze({
	lane = true,
	blocked = true,
})

-- Resource-tile requirements stay data-driven for future structures, even in turret-only Phase 2.
PlacementConfig.REQUIRES_RESOURCE_TILE = table.freeze({
	turret = false,
})

PlacementConfig.MAX_STRUCTURES = 20
PlacementConfig.PLACEMENT_FOLDER_NAME = "Placements"

return table.freeze(PlacementConfig)
