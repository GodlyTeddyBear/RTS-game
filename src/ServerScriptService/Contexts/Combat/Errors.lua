--!strict

--[=[
	@class Errors
	Defines centralized Combat context error constants.
	@server
]=]
local Errors = {}

Errors.INVALID_WAVE_NUMBER = "CombatContext: invalid wave number"
Errors.INVALID_ENEMY_ENTITY = "CombatContext: invalid enemy entity"
Errors.INVALID_ROLE = "CombatContext: invalid enemy role"
Errors.MISSING_PRIMARY_PLAYER = "CombatContext: no primary player found"
Errors.NO_LANE_TILES = "CombatContext: no lane tiles available"
Errors.MISSING_GOAL_POINT = "CombatContext: goal point not available"
Errors.COMBAT_NOT_ACTIVE = "CombatContext: combat is not active"

return table.freeze(Errors)
