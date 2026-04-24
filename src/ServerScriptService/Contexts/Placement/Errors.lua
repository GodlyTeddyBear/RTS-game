--!strict

--[=[
	@class Errors
	Defines centralized Placement context error constants.
	@server
]=]
local Errors = {}

Errors.INVALID_REQUEST_COORD = "PlacementContext: invalid placement coordinates in request"
Errors.INVALID_REQUEST_STRUCTURE_TYPE = "PlacementContext: invalid structure type in request"
Errors.NOT_PREP_STATE = "PlacementContext: placement only allowed during Prep phase"
Errors.UNKNOWN_STRUCTURE_TYPE = "PlacementContext: structure type not in config"
Errors.INVALID_COORD = "PlacementContext: grid coordinate is invalid or out of bounds"
Errors.TILE_UNAVAILABLE = "PlacementContext: tile is blocked or already occupied"
Errors.INCOMPATIBLE_TILE_ZONE = "PlacementContext: structure cannot be placed on this tile (zone or prohibited marker)"
Errors.RESOURCE_TILE_REQUIRED = "PlacementContext: structure requires a resource side-pocket tile"
Errors.MAX_STRUCTURES_REACHED = "PlacementContext: structure cap reached for this run"
Errors.TEMPLATE_NOT_FOUND = "PlacementContext: structure template missing from ReplicatedStorage"
Errors.OCCUPANCY_UPDATE_FAILED = "PlacementContext: failed to mark tile occupied"
Errors.REFUND_FAILED = "PlacementContext: failed to refund energy after placement rollback"
Errors.INVALID_INSTANCE_ID = "PlacementContext: invalid structure instance id"

return table.freeze(Errors)
