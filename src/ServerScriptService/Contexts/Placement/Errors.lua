--!strict

--[=[
	@class Errors
	Defines centralized Placement context error constants.
	@server
]=]
local Errors = {}

Errors.INVALID_REQUEST_COORD = "PlacementContext: invalid placement coordinates in request"
Errors.INVALID_REQUEST_STRUCTURE_TYPE = "PlacementContext: invalid structure type in request"
Errors.NOT_ACTIVE_RUN_STATE = "PlacementContext: placement only allowed during active run phases"
Errors.UNKNOWN_STRUCTURE_TYPE = "PlacementContext: structure type not in config"
Errors.INVALID_COST_MAP = "PlacementContext: structure cost map is missing or malformed"
Errors.INVALID_COORD = "PlacementContext: grid coordinate is invalid or out of bounds"
Errors.TILE_UNAVAILABLE = "PlacementContext: tile is blocked or already occupied"
Errors.INCOMPATIBLE_TILE_ZONE = "PlacementContext: structure cannot be placed on this tile (zone or prohibited marker)"
Errors.RESOURCE_TILE_REQUIRED = "PlacementContext: structure requires a resource side-pocket tile"
Errors.MAX_STRUCTURES_REACHED = "PlacementContext: structure cap reached for this run"
Errors.TEMPLATE_NOT_FOUND = "PlacementContext: structure template missing from ReplicatedStorage"
Errors.NO_GROUND_HIT = "PlacementContext: no non-grid collidable ground found below tile"
Errors.INVALID_GROUND_SLOPE = "PlacementContext: ground surface must be perfectly flat"
Errors.OCCUPANCY_UPDATE_FAILED = "PlacementContext: failed to mark tile occupied"
Errors.OCCUPANCY_RELEASE_FAILED = "PlacementContext: failed to clear tile occupancy"
Errors.REFUND_FAILED = "PlacementContext: failed to refund energy after placement rollback"
Errors.INVALID_INSTANCE_ID = "PlacementContext: invalid structure instance id"
Errors.MISSING_FOOTPRINT_CACHE = "PlacementContext: footprint cache entry missing for structure type or rotation"

return table.freeze(Errors)
