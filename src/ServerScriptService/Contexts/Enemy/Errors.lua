--!strict

--[=[
	@class Errors
	Defines centralized Enemy context error constants.
	@server
]=]
local Errors = {}

Errors.INVALID_ROLE = "EnemyContext: invalid enemy role"
Errors.INVALID_SPAWN_CFRAME = "EnemyContext: invalid spawn CFrame"
Errors.INVALID_WAVE_NUMBER = "EnemyContext: invalid wave number"
Errors.INVALID_ENTITY = "EnemyContext: invalid enemy entity"
Errors.INVALID_DAMAGE_AMOUNT = "EnemyContext: damage amount must be positive"
Errors.MISSING_MODEL = "EnemyContext: model reference not found for entity"
Errors.MISSING_GOAL_POSITION = "EnemyContext: no goal position available"
Errors.MISSING_GOAL_POINT = "EnemyContext: goal point not available"
Errors.SPAWN_MODEL_FAILED = "EnemyContext: failed to spawn enemy model"
Errors.APPLY_DAMAGE_FAILED = "EnemyContext: failed to apply damage"

return table.freeze(Errors)
