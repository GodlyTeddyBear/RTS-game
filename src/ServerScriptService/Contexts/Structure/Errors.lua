--!strict

--[=[
	@class Errors
	Defines centralized error constants for the Structure context.
	@server
]=]
local Errors = {}

Errors.UNKNOWN_STRUCTURE_TYPE = "StructureContext: unknown structure type"
Errors.INVALID_PLACEMENT_RECORD = "StructureContext: invalid placement record"
Errors.INVALID_OWNER_USER_ID = "StructureContext: owner user id is invalid"
Errors.ENTITY_NOT_FOUND = "StructureContext: structure entity not found"
Errors.INVALID_DAMAGE_AMOUNT = "StructureContext: damage amount must be positive"
Errors.INVALID_CONSTRUCTION_WORK_AMOUNT = "StructureContext: construction work amount must be positive and finite"
Errors.STRUCTURE_ALREADY_COMPLETED = "StructureContext: structure construction is already completed"

return table.freeze(Errors)
