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
	turret = table.freeze({
		Energy = 15,
		Metal = 5,
	}),
	Extractor = table.freeze({
		Energy = 10,
	}),
})

-- Base disallowed zones are global: placement is allowed by default outside these zones.
PlacementConfig.BASE_DISALLOWED_ZONE_TYPES = table.freeze({
	blocked = true,
})

-- Resource-tile requirements stay data-driven for future structures, even in turret-only Phase 2.
PlacementConfig.REQUIRES_RESOURCE_TILE = table.freeze({
	turret = false,
	Extractor = true,
})

PlacementConfig.MAX_STRUCTURES = 20
PlacementConfig.PLACEMENT_FOLDER_NAME = "Placements"

return table.freeze(PlacementConfig)
