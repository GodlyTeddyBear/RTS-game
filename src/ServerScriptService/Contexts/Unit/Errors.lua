--!strict

local Errors = {}

Errors.INVALID_REQUEST = "UnitContext: spawn request is invalid"
Errors.INVALID_UNIT_ID = "UnitContext: unit id is invalid"
Errors.INVALID_FACTION = "UnitContext: faction is invalid"
Errors.INVALID_OWNER_KIND = "UnitContext: owner kind is invalid"
Errors.INVALID_OWNER_ID = "UnitContext: owner id is invalid"
Errors.INVALID_SPAWN_CFRAME = "UnitContext: spawn CFrame is invalid"
Errors.INVALID_LIFETIME = "UnitContext: lifetime must be positive"
Errors.MAX_CONCURRENT_REACHED = "UnitContext: max concurrent units reached for owner"
Errors.INVALID_ENTITY = "UnitContext: unit entity is invalid"
Errors.SPAWN_MODEL_FAILED = "UnitContext: failed to spawn unit model"
Errors.INVALID_MOVE_ORDER_REQUEST = "UnitContext: move order request is invalid"
Errors.INVALID_UNIT_GUIDS = "UnitContext: move order unit guids are invalid"
Errors.INVALID_MOVE_DESTINATION = "UnitContext: move order destination is invalid"
Errors.UNIT_NOT_MOVABLE = "UnitContext: unit cannot receive manual move orders"

return table.freeze(Errors)
