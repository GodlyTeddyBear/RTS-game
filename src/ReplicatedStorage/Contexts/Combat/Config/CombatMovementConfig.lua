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
	-- Master switch for the flow separation parallel path.
	Enabled = true,
	KForce = 80,
	VelAlpha = 0.15,
	MinSeparationDistance = 1e-4,
	-- Skip isolation checks when nearby entities are obviously too far away to matter.
	IsolationSkipEnabled = true,
	-- Radius used by the isolation skip check.
	IsolationSkipRadiusStuds = 6,
	-- Deprecated: dense-cell local calculation fallback is disabled in parallel-only mode.
	DenseCellFallbackEnabled = false,
	-- Cell occupancy limit before dense-cell fallback kicks in.
	DenseCellOccupancyThreshold = 10,
	-- Reduce separation force near the goal so units can clump more naturally.
	NearGoalSeparationScale = 0.35,
	-- Radius around the goal where the reduced separation scale applies.
	NearGoalSeparationRadiusStuds = 8,
	-- Minimum movement before neighboring separation cells are marked dirty again.
	NeighborDirtyMoveThresholdStuds = 2,
	WalkSpeedWriteEpsilon = 0.05,
	-- Let settled units stop actively pushing movement while they are already clumped.
	ClumpIdleEnabled = true,
	-- Radius inside which clump-idle behavior can activate.
	ClumpIdleRadiusStuds = 8,
	-- Extra padding used when checking whether settled units are touching.
	ClumpTouchDistancePaddingStuds = 0.5,
	-- Minimum time between shared flowfield refreshes for the same goal.
	SharedFlowfieldRefreshCooldownSeconds = 0.35,
	-- Master switch for worker-based separation and velocity solves.
	ParallelEnabled = true,
	-- Number of worker actors available for separation jobs.
	ParallelActorCount = 256,
	-- Chunk size used when dispatching separation work to workers.
	ParallelBatchSize = 1,
	-- Timeout for separation worker jobs.
	ParallelTimeoutSeconds = 1,
	-- Minimum pair count before pair solving is offloaded to workers.
	ParallelMinPairCount = 1,
	-- Master switch for worker-based pair snapshot building.
	ParallelSnapshotBuildEnabled = true,
	-- Minimum candidate cell count before snapshot building is offloaded.
	ParallelSnapshotBuildMinCandidateCount = 1,
	-- Maximum entity count a snapshot-build worker task may inspect before the planner falls back locally.
	ParallelSnapshotBuildMaxEntitiesPerTask = 256,
	-- Oversized snapshot-build work is either chunked into multiple tasks or resolved locally.
	ParallelSnapshotBuildOverflowMode = "Chunk",
	-- Chunk size used when building pair snapshots in parallel.
	ParallelSnapshotBuildBatchSize = 1,
	-- Timeout for snapshot-building worker jobs.
	ParallelSnapshotBuildTimeoutSeconds = 1,
	-- Minimum entity count before velocity solving is offloaded to workers.
	ParallelMinVelocityEntityCount = 1,
	-- Chunk size used when dispatching velocity solve work.
	ParallelVelocityBatchSize = 1,
	-- Timeout for velocity solve worker jobs.
	ParallelVelocityTimeoutSeconds = 1,
	-- Allow the movement system to keep using async worker results.
	ParallelAsyncEnabled = true,
	-- Maximum time a worker job may stay in flight before it is dropped.
	ParallelAsyncMaxInFlightSeconds = 1,
	-- Reuse the most recent completed result while a newer one is still running.
	ParallelAsyncUsePreviousResult = true,
	-- Deprecated: local calculation fallback is disabled in parallel-only mode.
	ParallelFallbackOnError = false,
})

return table.freeze(CombatMovementConfig)
