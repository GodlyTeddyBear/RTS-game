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

-- Template names mirror the assets folder names used by PlacementService.
PlacementConfig.STRUCTURE_TEMPLATES = table.freeze({
	turret = "Turret",
})

-- Phase 2 locks placement to side pads only; lane placement is intentionally disallowed.
PlacementConfig.VALID_ZONE_TYPES = table.freeze({
	turret = table.freeze({ "side_pocket" }),
})

-- Resource-tile requirements stay data-driven for future structures, even in turret-only Phase 2.
PlacementConfig.REQUIRES_RESOURCE_TILE = table.freeze({
	turret = false,
})

PlacementConfig.MAX_STRUCTURES = 20
PlacementConfig.PLACEMENT_FOLDER_NAME = "Placements"

return table.freeze(PlacementConfig)
