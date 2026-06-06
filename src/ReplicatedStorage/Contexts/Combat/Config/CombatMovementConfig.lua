--!strict

--[=[
	@class CombatMovementConfig
	Defines SimplePath tuning for combat-owned lane movement.
	@server
	@client
]=]
local CombatMovementConfig = {}

CombatMovementConfig.AGENT_PARAMS_BY_UNIT_ROLE = table.freeze({
	Builder = table.freeze({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	}),
	Combat = table.freeze({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	}),
})

--[=[
	@prop DEFAULT_AGENT_PARAMS table
	@within CombatMovementConfig
	Default SimplePath agent settings used when a role has no override.
]=]
CombatMovementConfig.DEFAULT_AGENT_PARAMS = table.freeze({
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
})

--[=[
	@prop PATHFINDING table
	@within CombatMovementConfig
	Runtime SimplePath options used by combat movement.
]=]
CombatMovementConfig.PATHFINDING = table.freeze({
	VisualizeSimplePath = true,
	DebugTarget = false,
	InitialRunDelaySeconds = 0.1,
	RetryComputationErrors = true,
	ReconcileTargetYOnWaypointFailure = true,
	MaxTargetYReconcileAttempts = 2,
})

CombatMovementConfig.GOAL_NORMALIZATION = table.freeze({
	HeightOffset = 1024,
	RayLength = 4096,
	MinimumUpDot = 0.5,
	ExcludedFolderNames = table.freeze({
		"Units",
		"Placements",
	}),
})

--[=[
	@prop FASTFLOW_GRID table
	@within CombatMovementConfig
	Core FastFlow grid tuning. `Subdivisions` controls how many FastFlow cells each world tile is split into per axis.
]=]
CombatMovementConfig.FASTFLOW_GRID = table.freeze({
	Subdivisions = 2,
})

--[=[
	@prop FLOW_SOFT_SEPARATION table
	@within CombatMovementConfig
	FastFlow advance only: overlaps flow steering with local pairwise soft collision (spatial hash + quadratic penetration push), matching FlowExample.lua-style separation.
]=]
CombatMovementConfig.FLOW_SOFT_SEPARATION = table.freeze({
	-- Master switch for the flow separation parallel path.
	Enabled = true,
	KForce = 80,
	VelAlpha = 0.15,
	MinSeparationDistance = 1e-4,
	-- Dense-cell aggregate fallback tuning.
	AggregateCellMinMembers = 2,
	AggregateForceScale = 1.0,
	AggregateInfluenceRadiusMultiplier = 1.0,
	-- Extra padding used when checking whether settled units are touching.
	ClumpTouchDistancePaddingStuds = 0.5,
	-- Master switch for worker-based separation and velocity solves.
	ParallelEnabled = true,
	-- Number of worker actors available for separation jobs.
	ParallelActorCount = 16,
	-- Chunk size used when dispatching velocity solve work.
	ParallelVelocityBatchSize = 16,
	-- Maximum time a worker job may stay in flight before it is dropped.
	ParallelAsyncMaxInFlightSeconds = 2,
	-- Example-faithful wall collision controls for the live flow movement solve.
	WallCollisionEnabled = true,
	WallCollisionAxisClampEnabled = true,
	WallCollisionCornerClampEnabled = true,
	WallCollisionUseUnitRadiusPadding = true,
	WallCollisionCellProbePaddingStuds = 0,
	WallCollisionVelocityEpsilon = 1e-4,
})

return table.freeze(CombatMovementConfig)
