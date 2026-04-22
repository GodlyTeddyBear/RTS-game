--!strict

--[=[
	@class Errors
	Defines centralized error constants for the Structure context.
	@server
]=]
local Errors = {}

Errors.UNKNOWN_STRUCTURE_TYPE = "StructureContext: unknown structure type"
Errors.INVALID_PLACEMENT_RECORD = "StructureContext: invalid placement record"
Errors.ENTITY_NOT_FOUND = "StructureContext: structure entity not found"
Errors.INVALID_DAMAGE_AMOUNT = "StructureContext: damage amount must be positive"

return table.freeze(Errors)
