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
	wall = 5,
	extractor = 10,
})

-- Template names mirror the assets folder names used by PlacementService.
PlacementConfig.STRUCTURE_TEMPLATES = table.freeze({
	turret = "Turret",
	wall = "Wall",
	extractor = "Extractor",
})

-- Zone compatibility is data-driven so future structure types can extend cleanly.
PlacementConfig.VALID_ZONE_TYPES = table.freeze({
	turret = table.freeze({ "lane" }),
	wall = table.freeze({ "lane" }),
	extractor = table.freeze({ "side_pocket" }),
})

-- Extractors need a real resource tile; other structures only need the zone.
PlacementConfig.REQUIRES_RESOURCE_TILE = table.freeze({
	turret = false,
	wall = false,
	extractor = true,
})

PlacementConfig.MAX_STRUCTURES = 20
PlacementConfig.PLACEMENT_FOLDER_NAME = "Placements"

return table.freeze(PlacementConfig)
