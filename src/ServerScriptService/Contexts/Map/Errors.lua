--!strict

--[=[
	@class Errors
	Defines centralized error constants for the Map context.
	@server
]=]
return table.freeze({
	INVALID_ZONE_NAME = "MapContext: zone name must be a non-empty string",
	MISSING_ASSETS_FOLDER = "MapContext: ReplicatedStorage.Assets folder is missing",
	MISSING_MAPS_FOLDER = "MapContext: ReplicatedStorage.Assets.Maps folder is missing",
	MISSING_WORKSPACE_MAP_CONTAINER = "MapContext: Workspace.Map container is missing",
	MISSING_WORKSPACE_GAME_CONTAINER = "MapContext: Workspace.Map.Game container is missing",
	MAP_TEMPLATE_NOT_FOUND = "MapContext: map template model not found",
	MAP_TEMPLATE_INVALID = "MapContext: map template is not a Model",
	REQUIRED_ZONE_MISSING = "MapContext: required zone marker missing on runtime map",
	RUNTIME_MAP_NOT_READY = "MapContext: runtime map is not prepared",
})
