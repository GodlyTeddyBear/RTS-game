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
	SentryTurret = table.freeze({
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
	SentryTurret = false,
	Extractor = true,
})

PlacementConfig.MAX_STRUCTURES = 20
PlacementConfig.PLACEMENT_FOLDER_NAME = "Placements"

PlacementConfig.GROUND_RAYCAST = table.freeze({
	HeightOffset = 1024,
	Length = 4096,
	RequirePerfectlyFlat = true,
})

PlacementConfig.PREVIEW = table.freeze({
	HighlightColor = Color3.fromRGB(0, 200, 100),
	HoverColor = Color3.fromRGB(255, 230, 0),
	HighlightMaterial = Enum.Material.Neon,
	HighlightThickness = 0.05,
	HighlightYOffset = 0.025,
	HighlightTransparency = 0.8,
	HoverTransparency = 0.35,
})

PlacementConfig.GHOST = table.freeze({
	ValidColor = Color3.fromRGB(0, 200, 100),
	InvalidColor = Color3.fromRGB(200, 50, 50),
	Transparency = 0.5,
})

return table.freeze(PlacementConfig)
