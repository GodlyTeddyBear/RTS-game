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
Errors.MOVEMENT_MISSING_GOAL_POSITION = "CombatContext: movement goal position is missing"
Errors.MOVEMENT_MISSING_ENTITY_FACTORY = "CombatContext: movement entity factory is missing"
Errors.MOVEMENT_INVALID_MODE = "CombatContext: movement mode is invalid"
Errors.MOVEMENT_MISSING_STATE = "CombatContext: movement state is missing"
Errors.MOVEMENT_FLOW_NOT_CONFIGURED = "CombatContext: flow movement is not configured"
Errors.MOVEMENT_FLOW_GENERATE_FAILED = "CombatContext: flow movement generation failed"
Errors.MOVEMENT_FLOW_RECOVER_FAILED = "CombatContext: flow movement recovery failed"
Errors.MOVEMENT_FLOW_UNRECOVERABLE = "CombatContext: flow movement could not recover direction"
Errors.MOVEMENT_MISSING_MODEL_POSITION = "CombatContext: movement model position is missing"
Errors.MOVEMENT_MISSING_PUBLISHED_INPUTS = "CombatContext: published flow inputs are missing"
Errors.MOVEMENT_MISSING_PUBLISHED_VELOCITY = "CombatContext: published flow velocity is missing"
Errors.MOVEMENT_GOAL_KEY_MISMATCH = "CombatContext: published flow goal key does not match"
Errors.MOVEMENT_MISSING_PATH_PROMISE = "CombatContext: path promise is missing"
Errors.MOVEMENT_PATH_REJECTED = "CombatContext: path promise rejected"
Errors.MOVEMENT_PARALLEL_REGISTER_FAILED = "CombatContext: movement parallel job registration failed"
Errors.MOVEMENT_PARALLEL_SHARED_MEMORY_FAILED = "CombatContext: movement parallel shared memory operation failed"
Errors.MOVEMENT_PARALLEL_DISPATCH_FAILED = "CombatContext: movement parallel dispatch failed"
Errors.MOVEMENT_PARALLEL_RESULT_FAILED = "CombatContext: movement parallel result processing failed"
Errors.MOVEMENT_PIPELINE_TRANSITION_FAILED = "CombatContext: movement pipeline transition failed"

return table.freeze(Errors)
