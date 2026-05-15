--!strict

local MapConfig = {}

MapConfig.RUNTIME_MAP_NAME = "Map"
MapConfig.TEMPLATE_NAME = "Default"
MapConfig.WORKSPACE_MAP_CONTAINER_NAME = "Map"
MapConfig.WORKSPACE_GAME_CONTAINER_NAME = "Game"
MapConfig.WORKSPACE_LOBBY_CONTAINER_NAME = "Lobby"
MapConfig.RUNTIME_MAP_TARGET_POSITION = Vector3.new(0, 0, 0)
MapConfig.LOBBY_SPAWN_PATH = "LobbyReturnSpawn"
MapConfig.LOBBY_SPAWN_MARKER_NAME = "LobbyReturnSpawn"
MapConfig.RUN_ENTRY_PATH = "Phase2EntrySpawn"
MapConfig.RUN_ENTRY_MARKER_NAME = "Phase2EntrySpawn"

MapConfig.ZONE_PATHS = table.freeze({
	Bases = "Environment.Zones.Bases",
	Spawns = "Environment.Zones.Spawns",
	PlacementGrids = "Environment.Zones.PlacementGrids",
	PlacementProhibited = "Environment.Zones.PlacementProhibited",
	Lanes = "Environment.Zones.Lanes",
	SidePockets = "Environment.Zones.SidePockets",
	Resources = "Environment.Zones.Resources",
})

MapConfig.REQUIRED_ZONES = table.freeze({
	"Spawns",
	"PlacementGrids",
	"Lanes",
	"SidePockets",
	"Resources",
})

return table.freeze(MapConfig)
