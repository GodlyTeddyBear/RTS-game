--!strict

--[=[
	@class CombatMovementConfig
	Defines SimplePath tuning for combat-owned lane movement.
	@server
	@client
]=]
local CombatMovementConfig = {}

--[=[
	@prop AGENT_PARAMS_BY_ROLE table
	@within CombatMovementConfig
	Role-specific SimplePath agent settings used by goal movement.
]=]
CombatMovementConfig.AGENT_PARAMS_BY_ROLE = table.freeze({
	Swarm = table.freeze({
		AgentRadius = 1.5,
		AgentHeight = 5,
		AgentCanJump = true,
	}),
	Tank = table.freeze({
		AgentRadius = 2.5,
		AgentHeight = 6,
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

--[=[
	@prop FASTFLOW_VISUALIZATION table
	@within CombatMovementConfig
	Debug visualization toggles for FastFlow pathfinder walls and grid.
]=]
CombatMovementConfig.FASTFLOW_VISUALIZATION = table.freeze({
	Enabled = true,
	YLevelOffset = 0.2,
	ShowWalls = true,
	ShowCellGrid = false,
	ShowChunkGrid = true,
	ShowHPA = false,
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
	@prop FASTFLOW_ARROW_VISUALIZATION table
	@within CombatMovementConfig
	Debug visualization toggles for sampled flow-direction arrows above terrain.
]=]
CombatMovementConfig.FASTFLOW_ARROW_VISUALIZATION = table.freeze({
	Enabled = false,
	SampleStepCells = 6,
	ArrowLengthStuds = 2,
	ArrowWidthStuds = 0.35,
	TerrainYOffset = 0.5,
	RaycastHeight = 256,
	Color = Color3.fromRGB(255, 170, 0),
	MaxArrows = 900,
})

--[=[
	@prop FASTFLOW_SHARED_FIELDS table
	@within CombatMovementConfig
	Shared flowfield generation and refresh throttles for FastFlow goal groups.
]=]
CombatMovementConfig.FASTFLOW_SHARED_FIELDS = table.freeze({
	UsePrunedGeneration = true,
	RefreshCooldownSeconds = 0.35,
	AllowSingleRefreshPerCooldown = true,
	RepresentativeStartCap = 8,
})

--[=[
	@prop FASTFLOW_PROFILING table
	@within CombatMovementConfig
	Debug-only throttled counters for FastFlow runtime profiling.
]=]
CombatMovementConfig.FASTFLOW_PROFILING = table.freeze({
	Enabled = false,
	LogIntervalSeconds = 1,
})

--[=[
	@prop FLOW_SOFT_SEPARATION table
	@within CombatMovementConfig
	FastFlow advance only: overlaps flow steering with local pairwise soft collision (spatial hash + quadratic penetration push), matching FlowExample.lua-style separation.
]=]
CombatMovementConfig.FLOW_SOFT_SEPARATION = table.freeze({
	Enabled = true,
	KForce = 80,
	VelAlpha = 0.15,
	MinSeparationDistance = 1e-4,
	IsolationSkipEnabled = true,
	IsolationSkipRadiusStuds = 6,
	DenseCellFallbackEnabled = true,
	DenseCellOccupancyThreshold = 10,
	NearGoalSeparationScale = 0.35,
	NearGoalSeparationRadiusStuds = 8,
	NeighborDirtyMoveThresholdStuds = 2,
	WalkSpeedWriteEpsilon = 0.05,
	ClumpIdleEnabled = true,
	ClumpIdleRadiusStuds = 8,
	ClumpTouchDistancePaddingStuds = 0.5,
	SharedFlowfieldRefreshCooldownSeconds = 0.35,
	ParallelEnabled = true,
	ParallelActorCount = 16,
	ParallelBatchSize = 64,
	ParallelTimeoutSeconds = 0.02,
	ParallelMinPairCount = 256,
	ParallelMinVelocityEntityCount = 64,
	ParallelVelocityBatchSize = 64,
	ParallelVelocityTimeoutSeconds = 0.02,
	ParallelAsyncEnabled = true,
	ParallelAsyncMaxInFlightSeconds = 0.05,
	ParallelAsyncUsePreviousResult = true,
	ParallelFallbackOnError = true,
})

return table.freeze(CombatMovementConfig)
