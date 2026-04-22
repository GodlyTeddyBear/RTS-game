--!strict

local MapConfig = {}

MapConfig.RUNTIME_MAP_NAME = "Map"
MapConfig.TEMPLATE_NAME = "Default"
MapConfig.WORKSPACE_MAP_CONTAINER_NAME = "Map"
MapConfig.WORKSPACE_GAME_CONTAINER_NAME = "Game"

MapConfig.ZONE_PATHS = table.freeze({
	Goal = "Environment.Zones.Goal",
	PlacementGrid = "Environment.Zones.PlacementGrid",
	SidePockets = "Environment.Zones.SidePockets",
})

MapConfig.REQUIRED_ZONES = table.freeze({
	"Goal",
	"PlacementGrid",
	"SidePockets",
})

return table.freeze(MapConfig)
