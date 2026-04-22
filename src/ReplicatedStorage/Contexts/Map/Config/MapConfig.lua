--!strict

local MapConfig = {}

MapConfig.RUNTIME_MAP_NAME = "Map"
MapConfig.TEMPLATE_NAME = "Default"
MapConfig.WORKSPACE_MAP_CONTAINER_NAME = "Map"
MapConfig.WORKSPACE_GAME_CONTAINER_NAME = "Game"

MapConfig.ZONE_PATHS = table.freeze({
	Spawns = "Environment.Zones.Spawns",
	Goals = "Environment.Zones.Goals",
	PlacementGrids = "Environment.Zones.PlacementGrids",
	Lanes = "Environment.Zones.Lanes",
	SidePockets = "Environment.Zones.SidePockets",
})

MapConfig.REQUIRED_ZONES = table.freeze({
	"Spawns",
	"Goals",
	"PlacementGrids",
	"Lanes",
	"SidePockets",
})

return table.freeze(MapConfig)
