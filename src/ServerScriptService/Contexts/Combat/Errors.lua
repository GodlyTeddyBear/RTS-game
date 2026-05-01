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
Errors.INACTIVE_BASE = "CombatContext: base is not active"
Errors.INVALID_STRUCTURE_ATTACK_PAYLOAD = "CombatContext: invalid structure attack payload"
Errors.INVALID_STRUCTURE_ATTACK_DAMAGE = "CombatContext: invalid structure attack damage"
Errors.MISSING_PROJECTILE_ORIGIN = "CombatContext: projectile origin is missing"
Errors.MISSING_PROJECTILE_TARGET = "CombatContext: projectile target is missing"
Errors.PROJECTILE_FIRE_FAILED = "CombatContext: projectile fire failed"
Errors.INVALID_ACTOR_TYPE_PAYLOAD = "CombatContext: invalid actor type registration payload"
Errors.INVALID_ACTOR_PAYLOAD = "CombatContext: invalid combat actor registration payload"
Errors.RUNTIME_ALREADY_STARTED = "CombatContext: generic combat runtime is already started"
Errors.RUNTIME_NOT_STARTED = "CombatContext: generic combat runtime is not started"
Errors.RUNTIME_START_FAILED = "CombatContext: generic combat runtime failed to start"
Errors.ILLEGAL_SESSION_TRANSITION = "CombatContext: combat session state transition is not allowed"
Errors.COMBAT_SESSION_INVARIANT_FAILED = "CombatContext: combat session lifecycle invariants are not satisfied"
Errors.COMBAT_SESSION_MISSING = "CombatContext: combat session does not exist"

return table.freeze(Errors)
