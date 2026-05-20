--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyTypes = require(ReplicatedStorage.Contexts.Enemy.Types.EnemyTypes)
local FastFlowHelper = require(ReplicatedStorage.Utilities.FastFlowHelper)
local ParallelRunner = require(ReplicatedStorage.Utilities.ParallelRunner)
local Result = require(ReplicatedStorage.Utilities.Result)
local TableRecycler = require(ReplicatedStorage.Utilities.TableRecycler)

--[=[
    @class Types
    Shared movement-service type aliases and table contracts used by combat movement modules.
    @server
]=]
local MovementServiceTypes = {}

--[=[
    @type EnemyMovementMode
    @within Types
    Enemy movement mode alias consumed by movement service entry points.
]=]
export type EnemyMovementMode = EnemyTypes.EnemyMovementMode
export type TFastFlowGridMapping = FastFlowHelper.TFlowGridMapping
export type TTableRecyclerLike = TableRecycler.TTableRecyclerHandle

export type TPathPromiseLike = {
	cancel: (self: TPathPromiseLike) -> (),
	getStatus: (self: TPathPromiseLike) -> any,
}

export type TAgentParams = {
	AgentRadius: number?,
	AgentHeight: number?,
	AgentCanJump: boolean?,
}

export type TEnemyPathStateLike = {
	GoalPosition: Vector3?,
}

export type TEnemyModelRefLike = {
	Model: Model?,
}

export type TEnemyRoleLike = {
	Role: string,
}

export type TEnemyEntityFactoryLike = {
	GetPathState: (self: TEnemyEntityFactoryLike, entity: number) -> TEnemyPathStateLike?,
	SetPathMoving: (self: TEnemyEntityFactoryLike, entity: number, isMoving: boolean) -> (),
	GetModelRef: (self: TEnemyEntityFactoryLike, entity: number) -> TEnemyModelRefLike?,
	GetCurrentMoveSpeed: (self: TEnemyEntityFactoryLike, entity: number) -> number?,
	GetRole: (self: TEnemyEntityFactoryLike, entity: number) -> TEnemyRoleLike?,
	QueryAliveEntities: (self: TEnemyEntityFactoryLike) -> { number },
}

export type TLockOnServiceLike = {
	SetBoidsFacingFlatForward: (self: TLockOnServiceLike, entity: number, flatForward: Vector3?) -> (),
}

export type TCombatLoopServiceLike = {
	ForEachRunnableSession: (self: TCombatLoopServiceLike, callback: (userId: number) -> (boolean?)) -> (),
}

export type TRegistryLike = {
	Get: (self: TRegistryLike, name: string) -> any,
}

export type TFlowSchedulerServices = {
	TickId: number?,
	DeltaTime: number?,
	Dt: number?,
	TickStartedAt: number?,
	TickBudgetSeconds: number?,
}

export type TMovementTempEntityArray = { number }
export type TMovementTempMap = { [number]: boolean }

export type TFlowfieldLike = {
	GetDirection: (self: TFlowfieldLike, cell: Vector2) -> Vector2?,
}

export type TFastFlowWallsLike = {
	_Grid: { [number]: boolean }?,
	_GetCellPos: ((self: TFastFlowWallsLike, index: number) -> Vector2)?,
	_Size: number?,
	IsCellInBounds: ((self: TFastFlowWallsLike, cell: Vector2) -> boolean)?,
	GetCell: ((self: TFastFlowWallsLike, cell: Vector2) -> boolean?)?,
}

export type TFlowfieldDebugRenderer = (flowfield: TFlowfieldLike, mapping: TFastFlowGridMapping, goalPosition: Vector3) -> ()

export type TFlowPipelineStateMachineLike = {
	Transition: (self: TFlowPipelineStateMachineLike, nextState: TFlowPipelineState) -> Result.Result<TFlowPipelineState>,
	GetState: (self: TFlowPipelineStateMachineLike) -> TFlowPipelineState,
	Destroy: (self: TFlowPipelineStateMachineLike) -> (),
}

--[=[
    @type TFlowPipelineState
    @within Types
    Flow pipeline state label used to drive the separation solve lifecycle.
]=]
export type TFlowPipelineState =
	"Idle"
	| "BuildingSnapshot"
	| "PreparingSharedPacket"
	| "PreparingRunRequest"
	| "Dispatching"
	| "Waiting"
	| "Publishing"

--[=[
    @interface TPathMovementState
    @within Types
    Path-based movement runtime state tracked while a path promise is active.
    .Mode string -- Movement mode discriminator.
    .Promise any -- Running path promise owned by the path movement branch.
]=]
export type TPathMovementState = {
	Mode: "Path",
	Promise: TPathPromiseLike,
}

--[=[
    @interface TFlowMovementState
    @within Types
    Flow-based movement runtime state tracked while an entity follows a shared flowfield.
    .Mode string -- Movement mode discriminator.
    .GoalSnapshot Vector3 -- Last resolved goal position used to detect goal changes.
    .GoalKey string -- Shared flowfield key for the current goal.
    .GoalWorldSample Vector3 -- Goal position projected into the flowfield grid.
    .RecoveryMoveTarget Vector3? -- Latched recovery target used when escaping invalid cells.
    .RecoveryOpenCell Vector2? -- Open grid cell that backs the current recovery target.
    .RecoveryMode string -- Recovery state discriminator.
]=]
export type TFlowMovementState = {
	Mode: "Flow",
	GoalSnapshot: Vector3,
	GoalKey: string,
	GoalWorldSample: Vector3,
	RecoveryMoveTarget: Vector3?,
	RecoveryOpenCell: Vector2?,
	RecoveryMode: "None" | "EscapingInvalidCell",
}

--[=[
    @type TMovementState
    @within Types
    Runtime movement state union used by the service entry module.
]=]
export type TMovementState = TPathMovementState | TFlowMovementState

--[=[
    @interface TSharedFlowfieldEntry
    @within Types
    Cached shared flowfield entry keyed by goal hash.
    .Flowfield any -- Generated flowfield object reused by all entities targeting the same goal.
    .GoalCell Vector2 -- Goal grid cell used to derive the cache key.
    .GoalWorldSample Vector3 -- World-space sample point used to build the flowfield.
    .LastRefreshClock number -- Timestamp of the last flowfield refresh.
    .RefreshInProgress boolean -- Whether a refresh is already underway.
    .RefCount number -- Active entity references using this shared entry.
]=]
export type TSharedFlowfieldEntry = {
	Flowfield: TFlowfieldLike,
	GoalCell: Vector2,
	GoalWorldSample: Vector3,
	LastRefreshClock: number,
	RefreshInProgress: boolean,
	RefCount: number,
}

--[=[
    @interface TFlowActorRefs
    @within Types
    Cached model, root-part, and humanoid references used by flow movement.
    .Model Model? -- Current resolved entity model.
    .RootPart BasePart? -- Cached primary part reference.
    .Humanoid Humanoid? -- Cached humanoid reference.
    .LastWalkSpeed number? -- Last walk speed written to the humanoid.
]=]
export type TFlowActorRefs = {
	Model: Model?,
	RootPart: BasePart?,
	Humanoid: Humanoid?,
	LastWalkSpeed: number?,
}

--[=[
    @interface TFlowSeparationSolveSnapshot
    @within Types
    Structure-of-arrays snapshot consumed by the parallel flow separation solve.
    .TickId number -- Solver tick identifier.
    .EntityCount number -- Number of entities packed into the snapshot.
    .EntityIds { number } -- Entity ids in packed order.
    .GoalGroupId { number } -- Goal-group id per entity index.
    .GoalGroupCellRecordStartIndex { number } -- Start index into the cell-record arrays per entity index.
    .GoalGroupCellRecordCount { number } -- Number of cell-record entries per goal group.
    .GoalGroupCellWidthStuds { number } -- Cell width used for each goal group.
    .GroupCellX { number } -- Packed group cell X coordinate per entity index.
    .GroupCellY { number } -- Packed group cell Y coordinate per entity index.
    .CellPackedKey { number } -- Packed cell key per cell-record entry.
    .CellMemberStartIndex { number } -- Start index into the member arrays per cell-record entry.
    .CellMemberCount { number } -- Number of entities in each cell-record entry.
    .CellMemberEntityIndex { number } -- Packed entity index per cell member.
    .FlatPositionX { number } -- Packed X position per entity index.
    .FlatPositionY { number } -- Packed Y position per entity index.
    .Radius { number } -- Agent radius per entity index.
    .FlowVelocityX { number } -- Current flow velocity X component per entity index.
    .FlowVelocityY { number } -- Current flow velocity Y component per entity index.
    .PreviousVelocityX { number } -- Previous frame velocity X component per entity index.
    .PreviousVelocityY { number } -- Previous frame velocity Y component per entity index.
    .WalkSpeed { number } -- Current walk speed per entity index.
    .VelAlpha { number } -- Velocity blend factor per entity index.
    .IsSettled { boolean } -- Whether the entity is settled at the current goal.
    .DeltaTime number -- Frame delta used for the solve.
    .CellWidthStuds number -- Separation cell width in studs.
    .OriginX number -- World origin X coordinate.
    .OriginY number -- World origin Z coordinate projected into Y.
    .WallGridHalfSize number -- Half-size of the wall grid used for wall collision lookup.
    .WallPackedKeys { number } -- Packed wall cell keys used by the solve.
    .KForce number -- Separation force constant.
    .MinSeparationDistance number -- Minimum allowed distance between agents.
    .WallCollisionEnabled boolean -- Whether wall collision handling is enabled.
    .WallCollisionAxisClampEnabled boolean -- Whether axis clamp logic is enabled.
    .WallCollisionCornerClampEnabled boolean -- Whether corner clamp logic is enabled.
    .WallCollisionUseUnitRadiusPadding boolean -- Whether unit-radius padding is applied.
    .WallCollisionCellProbePaddingStuds number -- Additional cell probe padding in studs.
    .WallCollisionVelocityEpsilon number -- Velocity epsilon used for wall collision tests.
    .ClumpTouchPaddingStuds number -- Padding used when detecting clump-touch neighbors.
]=]
export type TFlowSeparationSolveSnapshot = {
	TickId: number,
	EntityCount: number,
	EntityIds: { number },
	GoalGroupId: { number },
	GoalGroupCellRecordStartIndex: { number },
	GoalGroupCellRecordCount: { number },
	GoalGroupCellWidthStuds: { number },
	GroupCellX: { number },
	GroupCellY: { number },
	CellPackedKey: { number },
	CellMemberStartIndex: { number },
	CellMemberCount: { number },
	CellMemberEntityIndex: { number },
	FlatPositionX: { number },
	FlatPositionY: { number },
	Radius: { number },
	FlowVelocityX: { number },
	FlowVelocityY: { number },
	PreviousVelocityX: { number },
	PreviousVelocityY: { number },
	WalkSpeed: { number },
	VelAlpha: { number },
	IsSettled: { boolean },
	DeltaTime: number,
	CellWidthStuds: number,
	OriginX: number,
	OriginY: number,
	WallGridHalfSize: number,
	WallPackedKeys: { number },
	KForce: number,
	MinSeparationDistance: number,
	WallCollisionEnabled: boolean,
	WallCollisionAxisClampEnabled: boolean,
	WallCollisionCornerClampEnabled: boolean,
	WallCollisionUseUnitRadiusPadding: boolean,
	WallCollisionCellProbePaddingStuds: number,
	WallCollisionVelocityEpsilon: number,
	ClumpTouchPaddingStuds: number,
}

--[=[
    @interface TFlowFrameStateHandle
    @within Types
    Mutable frame-state handle used to assemble separation snapshots.
    .Reset function -- Clears the frame for a new tick.
    .AddEntity function -- Appends one entity to the frame-state arrays.
    .BuildSeparationSnapshot function -- Produces the packed snapshot used by the solver.
    .Destroy function -- Releases the frame-state tables back to the recycler.
]=]
export type TFlowFrameStateHandle = {
	Reset: (self: TFlowFrameStateHandle) -> (),
	EnsureGoalGroup: (self: TFlowFrameStateHandle, goalKey: string) -> number,
	AddEntity: (
		self: TFlowFrameStateHandle,
		goalKey: string,
		entityId: number,
		position: Vector3,
		flowDirectionXZ: Vector2,
		walkSpeed: number,
		radius: number,
		previousVelocityXZ: Vector2,
		isSettled: boolean
	) -> number,
	GetEntityCount: (self: TFlowFrameStateHandle) -> number,
	GetGoalBuckets: (self: TFlowFrameStateHandle) -> { [string]: { number } },
	GetEntityId: (self: TFlowFrameStateHandle, entityIndex: number) -> number?,
	GetGoalGroupId: (self: TFlowFrameStateHandle, entityIndex: number) -> number?,
	GetFlatPositionX: (self: TFlowFrameStateHandle, entityIndex: number) -> number?,
	GetFlatPositionY: (self: TFlowFrameStateHandle, entityIndex: number) -> number?,
	GetRadius: (self: TFlowFrameStateHandle, entityIndex: number) -> number?,
	GetFlowVelocityX: (self: TFlowFrameStateHandle, entityIndex: number) -> number?,
	GetFlowVelocityY: (self: TFlowFrameStateHandle, entityIndex: number) -> number?,
	GetPreviousVelocityX: (self: TFlowFrameStateHandle, entityIndex: number) -> number?,
	GetPreviousVelocityY: (self: TFlowFrameStateHandle, entityIndex: number) -> number?,
	GetWalkSpeed: (self: TFlowFrameStateHandle, entityIndex: number) -> number?,
	GetVelAlpha: (self: TFlowFrameStateHandle, entityIndex: number) -> number?,
	IsSettled: (self: TFlowFrameStateHandle, entityIndex: number) -> boolean,
	SetVelAlpha: (self: TFlowFrameStateHandle, entityIndex: number, velAlpha: number) -> (),
	Destroy: (self: TFlowFrameStateHandle) -> (boolean, string?),
	BuildSeparationSnapshot: (
		self: TFlowFrameStateHandle,
		tickId: number,
		deltaTime: number,
		cellWidthStuds: number,
		originX: number,
		originY: number,
		wallGridHalfSize: number,
		wallPackedKeys: { number },
		kForce: number,
		minSeparationDistance: number,
		wallCollisionEnabled: boolean,
		wallCollisionAxisClampEnabled: boolean,
		wallCollisionCornerClampEnabled: boolean,
		wallCollisionUseUnitRadiusPadding: boolean,
		wallCollisionCellProbePaddingStuds: number,
		wallCollisionVelocityEpsilon: number,
		clumpTouchPaddingStuds: number
	) -> TFlowSeparationSolveSnapshot,
}

--[=[
    @interface TFlowSeparationSolveRow
    @within Types
    Row returned by the parallel flow separation solve for one entity.
    .EntityIndex number -- Packed entity index in the snapshot.
    .VelocityX number -- Solved velocity X component.
    .VelocityY number -- Solved velocity Y component.
    .TouchedSettledNeighbor boolean -- Whether the solver touched a settled neighbor.
]=]
export type TFlowSeparationSolveRow = {
	EntityIndex: number,
	VelocityX: number,
	VelocityY: number,
	TouchedSettledNeighbor: boolean,
}

--[=[
    @interface TFlowPublishedSolve
    @within Types
    Published solve output cached by the main thread after the parallel job completes.
    .TickId number -- Solve tick identifier.
    .VelocityByEntity table -- Final velocity vector per entity id.
    .TouchedSettledNeighborByEntity table -- Settled-neighbor flag per entity id.
    .GoalKeyByEntity table -- Published goal key per entity id.
]=]
export type TFlowPublishedSolve = {
	TickId: number,
	VelocityByEntity: { [number]: Vector2 },
	TouchedSettledNeighborByEntity: { [number]: boolean },
	GoalKeyByEntity: { [number]: string },
}

--[=[
    @interface TFlowPublishedFrameState
    @within Types
    Published frame-state cache reused by the flow advance step.
    .GoalKeyByEntity table -- Goal key per entity id.
    .GoalPositionByEntity table -- Goal position per entity id.
    .GoalWorldSampleByEntity table -- Goal world sample per entity id.
    .PositionByEntity table -- Current world position per entity id.
    .WalkSpeedByEntity table -- Current walk speed per entity id.
    .IsSettledByEntity table -- Settled flag per entity id.
]=]
export type TFlowPublishedFrameState = {
	GoalKeyByEntity: { [number]: string },
	GoalPositionByEntity: { [number]: Vector3 },
	GoalWorldSampleByEntity: { [number]: Vector3 },
	PositionByEntity: { [number]: Vector3 },
	WalkSpeedByEntity: { [number]: number },
	IsSettledByEntity: { [number]: boolean },
}

export type TFastFlowPathfinder = {
	_Walls: TFastFlowWallsLike?,
	FindOpenCell: (self: TFastFlowPathfinder, cell: Vector2) -> Vector2?,
	GenerateFlowfieldWorld: (self: TFastFlowPathfinder, goal: Vector3, starts: { Vector3 }?) -> TFlowfieldLike?,
}

export type TResolvedFlowGoal = {
	Pathfinder: TFastFlowPathfinder,
	Mapping: TFastFlowGridMapping,
	GoalCell: Vector2,
	GoalWorldSample: Vector3,
}

export type TResolvedSharedFlowfield = {
	GoalKey: string,
	GoalWorldSample: Vector3,
}

export type TFlowRepairResult = {
	Direction: Vector2?,
	Status: "Recovered" | "RetryLater",
}

export type TFlowBuildFrameStatePayload = {
	Skip: boolean?,
	GoalKey: string,
	GoalPosition: Vector3,
	GoalWorldSample: Vector3,
	Position: Vector3,
	FlowDirectionXZ: Vector2,
	WalkSpeed: number,
	Radius: number,
	PreviousVelocityXZ: Vector2,
	IsSettled: boolean,
}

export type TFlowSoftSeparationConfig = {
	VelAlpha: number?,
	ClumpIdleRadiusStuds: number?,
	ClumpTouchDistancePaddingStuds: number?,
}

export type TFlowAdvanceStepResult = {
	IsDone: boolean,
}

export type TFlowSeparationRunRequest = {
	Args: {
		TickId: number,
	},
	LogicalWorkCount: number,
	BatchSize: number,
}

--[=[
    @interface TFlowSeparationDispatchPayload
    @within Types
    MovementService-owned payload prepared before handing the solve to the managed job.
    .Snapshot TFlowSeparationSolveSnapshot -- Packed snapshot used by the worker solve.
    .WorkerPayload table -- Dynamic worker payload encoded per dispatch.
    .RunRequest table -- Per-dispatch run request forwarded to ParallelRunner.
]=]
export type TFlowSeparationDispatchPayload = {
	Snapshot: TFlowSeparationSolveSnapshot,
	WorkerPayload: TFlowSeparationWorkerPayload,
	RunRequest: TFlowSeparationRunRequest,
}

--[=[
    @type TManagedJob
    @within Types
    ParallelRunner managed job handle used by the flow separation pipeline.
]=]
export type TManagedJob = ParallelRunner.TManagedJob
export type TParallelRunnerLike = ParallelRunner.TRunner
export type TSharedPacket = ParallelRunner.TSharedPacket
export type TSharedCompiledHandle = ParallelRunner.TSharedCompiledHandle

export type TFlowSeparationWorkerSharedMemory = {
	WallPackedKeys: { number },
	CellWidthStuds: number?,
	OriginX: number?,
	OriginY: number?,
	WallGridHalfSize: number?,
	KForce: number?,
	MinSeparationDistance: number?,
	WallCollisionEnabled: boolean?,
	WallCollisionAxisClampEnabled: boolean?,
	WallCollisionCornerClampEnabled: boolean?,
	WallCollisionUseUnitRadiusPadding: boolean?,
	WallCollisionCellProbePaddingStuds: number?,
	WallCollisionVelocityEpsilon: number?,
	ClumpTouchPaddingStuds: number?,
}

export type TFlowSeparationWorkerPayload = {
	EntityCount: number,
	GoalGroupCellRecordStartIndex: { number },
	GoalGroupCellRecordCount: { number },
	GoalGroupCellWidthStuds: { number },
	GroupCellX: { number },
	GroupCellY: { number },
	CellPackedKey: { number },
	CellMemberStartIndex: { number },
	CellMemberCount: { number },
	CellMemberEntityIndex: { number },
	FlatPositionX: { number },
	FlatPositionY: { number },
	Radius: { number },
	FlowVelocityX: { number },
	FlowVelocityY: { number },
	PreviousVelocityX: { number },
	PreviousVelocityY: { number },
	WalkSpeed: { number },
	VelAlpha: { number },
	IsSettled: { boolean },
	DeltaTime: number?,
}

export type TFlowSeparationWorkerRequest = {
	JobName: string?,
	RunId: number?,
	ShardIndex: number?,
	StartTaskId: number,
	BatchSize: number,
	LogicalWorkCount: number,
	Args: { [string]: any }?,
	SharedMemory: TFlowSeparationWorkerSharedMemory?,
	WorkerPayload: TFlowSeparationWorkerPayload?,
}

export type TMovementService = {
	_registry: TRegistryLike?,
	_combatLoopService: TCombatLoopServiceLike?,
	_enemyEntityFactory: TEnemyEntityFactoryLike,
	_lockOnService: TLockOnServiceLike?,
	_fastFlowPathfinder: TFastFlowPathfinder?,
	_fastFlowMapping: TFastFlowGridMapping?,
	_flowfieldDebugRenderer: TFlowfieldDebugRenderer?,
	_movementByEntity: { [number]: TMovementState },
	_movementTempTableRecycler: TTableRecyclerLike?,
	_sharedFlowfieldsByGoalKey: { [string]: TSharedFlowfieldEntry },
	_flowGoalKeyByEntity: { [number]: string },
	_activeFlowEntitiesByGoalKey: { [string]: { [number]: boolean } },
	_flowSettledByEntity: { [number]: boolean },
	_flowActorRefsByEntity: { [number]: TFlowActorRefs },
	_flowVelocityByEntity: { [number]: Vector2 },
	_flowFrameSerial: number,
	_flowPipelineStateMachine: TFlowPipelineStateMachineLike,
	_flowPipelineTickId: number?,
	_flowInvalidReasonByEntity: { [number]: string? },
	_flowRecoveredOpenCellByEntity: { [number]: Vector2 },
	_flowCurrentSessionUserId: number?,
	_flowSeparationParallelRunner: TParallelRunnerLike?,
	_flowSeparationManagedJob: TManagedJob?,
	_flowFrameStateRecycler: TTableRecyclerLike?,
	_flowFrameState: TFlowFrameStateHandle?,
	_flowLatestParallelSolve: TFlowPublishedSolve?,
	_flowReusableGoalKeyByEntity: { [number]: string },
	_flowReusableGoalPositionByEntity: { [number]: Vector3 },
	_flowReusableGoalWorldSampleByEntity: { [number]: Vector3 },
	_flowReusablePositionByEntity: { [number]: Vector3 },
	_flowReusableWalkSpeedByEntity: { [number]: number },
	_flowReusableIsSettledByEntity: { [number]: boolean },
	_flowPublishedVelocityByEntity: { [number]: Vector2 },
	_flowPublishedTouchedSettledNeighborByEntity: { [number]: boolean },
	_flowPublishedGoalKeyByEntity: { [number]: string },
	_flowPublishedGoalPositionByEntity: { [number]: Vector3 },
	_flowPublishedGoalWorldSampleByEntity: { [number]: Vector3 },
	_flowPublishedPositionByEntity: { [number]: Vector3 },
	_flowPublishedWalkSpeedByEntity: { [number]: number },
	_flowPublishedIsSettledByEntity: { [number]: boolean },
	_flowPublishedSolve: TFlowPublishedSolve,
	_flowReusableFrameState: TFlowPublishedFrameState,
	_flowPublishedFrameState: TFlowPublishedFrameState,
	_flowRepresentativeStarts: { Vector3 },
	_flowDispatchedSeparationSnapshot: TFlowSeparationSolveSnapshot?,
	_flowDispatchedGoalKeyByEntity: { [number]: string }?,
	_flowDispatchedFrameState: TFlowPublishedFrameState?,
	_flowStaticSharedMemory: SharedTable?,
	_flowStaticSharedMemoryHandle: TSharedCompiledHandle?,
	_flowStaticSharedMemoryPathfinder: TFastFlowPathfinder?,
	_flowPreparedWorkerPayload: TFlowSeparationWorkerPayload?,
	_flowDispatchPayload: TFlowSeparationDispatchPayload?,
	_flowWallKeyCachePathfinder: TFastFlowPathfinder?,
	_flowWallPackedKeys: { number }?,
	_flowWallGridHalfSize: number?,
	Init: (self: TMovementService, registry: TRegistryLike, name: string) -> (),
	Start: (self: TMovementService) -> (),
	ConfigureEnemyEntityFactory: (self: TMovementService, enemyEntityFactory: TEnemyEntityFactoryLike) -> (),
	ConfigureLockOnService: (self: TMovementService, lockOnService: TLockOnServiceLike) -> (),
	ConfigureFastFlow: (self: TMovementService, pathfinder: TFastFlowPathfinder?, mapping: TFastFlowGridMapping?) -> (),
	ConfigureFlowfieldDebugRenderer: (self: TMovementService, renderer: TFlowfieldDebugRenderer?) -> (),
	FinalizeAdvanceFrame: (self: TMovementService) -> (),
	ResetFastFlowRuntime: (self: TMovementService) -> (),
	StartAdvance: (self: TMovementService, entity: number, movementMode: EnemyMovementMode) -> (boolean, string?),
	StepAdvance: (self: TMovementService, entity: number, services: TFlowSchedulerServices?) -> (boolean, string?),
	StopMovement: (self: TMovementService, entity: number) -> (),
	CleanupAll: (self: TMovementService) -> (),
	Destroy: (self: TMovementService) -> (),
	_GetOrCreateMovementTempTableRecycler: (self: TMovementService) -> TTableRecyclerLike,
	_AcquireMovementTempArray: (self: TMovementService, capacityHint: number?) -> TMovementTempEntityArray,
	_AcquireMovementTempMap: (self: TMovementService) -> TMovementTempMap,
	_ReleaseMovementTempArray: (self: TMovementService, tbl: TMovementTempEntityArray) -> (),
	_ReleaseMovementTempMap: (self: TMovementService, tbl: TMovementTempMap) -> (),
	_ResolveActiveSessionUserId: (self: TMovementService) -> number?,
	_ClearMovementRuntimeState: (self: TMovementService, entity: number) -> (),
	_GetOrCreateFlowActorRefs: (self: TMovementService, entity: number) -> TFlowActorRefs,
	_InvalidateFlowActorRefs: (self: TMovementService, entity: number) -> (),
	_GetEntityModel: (self: TMovementService, entity: number) -> Model?,
	_GetEntityRootPart: (self: TMovementService, entity: number) -> BasePart?,
	_GetEntityPosition: (self: TMovementService, entity: number) -> Vector3?,
	_GetHumanoid: (self: TMovementService, entity: number) -> Humanoid?,
	_GetWalkSpeedWriteEpsilon: (self: TMovementService) -> number,
	_ApplyCurrentMoveSpeed: (self: TMovementService, entity: number) -> number,
	_IssueHumanoidMoveTo: (self: TMovementService, entity: number, targetPosition: Vector3?, velocityXZ: Vector2) -> boolean,
	_StopHumanoid: (self: TMovementService, entity: number) -> (),
	_GetRoleName: (self: TMovementService, entity: number) -> string?,
	_GetAgentParams: (self: TMovementService, entity: number) -> TAgentParams,
	_GetMinGroupSize: (self: TMovementService) -> number,
	_CanEntityUseFlowAtGoal: (self: TMovementService, entity: number, goalPosition: Vector3) -> boolean,
	_CountFlowEligibleAtGoal: (self: TMovementService, goalPosition: Vector3) -> number,
	_ResolveAdvanceMode: (self: TMovementService, movementMode: EnemyMovementMode, goalPosition: Vector3) -> ("Path" | "Flow")?,
	_StartPath: (self: TMovementService, entity: number, goalPosition: Vector3) -> boolean,
	_TickPath: (self: TMovementService, entity: number, movementState: TPathMovementState) -> ("Running" | "Success" | "Fail", string?),
	_ClearFlowRecoveryState: (self: TMovementService, entity: number, movementState: TFlowMovementState?) -> (),
	_IsFastFlowDebugEnabled: (self: TMovementService) -> boolean,
	_ResolveFastFlowRuntime: (self: TMovementService) -> (TFastFlowPathfinder?, TFastFlowGridMapping?),
	_ClassifyFlowCellState: (self: TMovementService, position: Vector3) -> (FastFlowHelper.TFlowCellState?, Vector2?, TFastFlowPathfinder?, TFastFlowGridMapping?),
	_IsFlowCellStateInvalid: (self: TMovementService, cellState: FastFlowHelper.TFlowCellState?) -> boolean,
	_HasLatchedInvalidCellEscape: (self: TMovementService, movementState: TFlowMovementState) -> boolean,
	_SanitizeFlowMoveTarget: (self: TMovementService, targetPosition: Vector3?) -> Vector3?,
	_SetLatchedInvalidCellEscape: (self: TMovementService, entity: number, movementState: TFlowMovementState, openCell: Vector2, mapping: TFastFlowGridMapping, yLevel: number) -> Vector3,
	_TryClearLatchedInvalidCellEscape: (self: TMovementService, entity: number, movementState: TFlowMovementState, position: Vector3) -> boolean,
	_SampleFlowDirectionFromCell: (self: TMovementService, movementState: TFlowMovementState, cell: Vector2) -> Vector2?,
	_TryRecoverFlowDirectionFromOpenCell: (self: TMovementService, entity: number, movementState: TFlowMovementState, position: Vector3, pathfinder: TFastFlowPathfinder, mapping: TFastFlowGridMapping) -> Vector2?,
	_ResolveFlowGoal: (self: TMovementService, goalPosition: Vector3) -> Result.Result<TResolvedFlowGoal>,
	_GetSharedRepresentativeStarts: (self: TMovementService, goalKey: string) -> { Vector3 }?,
	_CreateSharedFlowfield: (self: TMovementService, goalKey: string, goalCell: Vector2, goalWorldSample: Vector3, forceUnpruned: boolean?) -> Result.Result<TSharedFlowfieldEntry>,
	_ResolveSharedFlowfield: (self: TMovementService, goalPosition: Vector3, forceRefresh: boolean?, forceUnpruned: boolean?) -> Result.Result<TResolvedSharedFlowfield>,
	_GetSharedFlowfieldEntry: (self: TMovementService, goalKey: string?) -> TSharedFlowfieldEntry?,
	_DetachSharedFlowfield: (self: TMovementService, goalKey: string?) -> (),
	_RemoveEntityFromActiveFlowGoal: (self: TMovementService, entity: number, goalKey: string?) -> (),
	_AddEntityToActiveFlowGoal: (self: TMovementService, entity: number, goalKey: string?) -> (),
	_RefreshActiveFlowGoalMembership: (self: TMovementService, entity: number, previousGoalKey: string?) -> (),
	_AttachEntityToSharedFlowfield: (self: TMovementService, entity: number, goalKey: string) -> (),
	_AttachEntityToFlowGoal: (self: TMovementService, entity: number, goalPosition: Vector3, forceRefresh: boolean?, forceUnpruned: boolean?) -> Result.Result<TResolvedSharedFlowfield>,
	_EmitFlowfieldDebug: (self: TMovementService, flowfield: TFlowfieldLike, goalPosition: Vector3) -> (),
	_RepairFlowDirectionXZ: (self: TMovementService, entity: number, movementState: TFlowMovementState, goalPosition: Vector3, position: Vector3) -> Result.Result<TFlowRepairResult>,
	_BuildPackedWallKeys: (self: TMovementService) -> { number },
	_GetOrCreateFlowFrameStateRecycler: (self: TMovementService) -> TTableRecyclerLike,
	_GetOrCreateFlowFrameState: (self: TMovementService) -> TFlowFrameStateHandle,
	_DestroyFlowFrameState: (self: TMovementService) -> (),
	_GetOrCreateFlowSeparationStaticSharedMemoryHandle: (self: TMovementService) -> TSharedCompiledHandle,
	_CreateFlowSeparationStaticSharedPacket: (self: TMovementService, snapshot: TFlowSeparationSolveSnapshot) -> TSharedPacket,
	_BuildFlowSeparationStaticSharedMemory: (self: TMovementService, snapshot: TFlowSeparationSolveSnapshot) -> SharedTable,
	_CreateFlowSeparationWorkerPayload: (self: TMovementService, snapshot: TFlowSeparationSolveSnapshot) -> TFlowSeparationWorkerPayload,
	_PrepareFlowSeparationWorkerPayload: (self: TMovementService, snapshot: TFlowSeparationSolveSnapshot) -> TFlowSeparationWorkerPayload,
	_EnsureFlowSeparationStaticSharedMemory: (self: TMovementService, snapshot: TFlowSeparationSolveSnapshot) -> (),
	_CreateFlowSeparationRunRequest: (self: TMovementService, snapshot: TFlowSeparationSolveSnapshot) -> TFlowSeparationRunRequest,
	_AssembleFlowSeparationDispatchPayload: (self: TMovementService, snapshot: TFlowSeparationSolveSnapshot, workerPayload: TFlowSeparationWorkerPayload, runRequest: TFlowSeparationRunRequest) -> TFlowSeparationDispatchPayload,
	_ApplyFlowVelocityRows: (self: TMovementService, snapshot: TFlowSeparationSolveSnapshot, rows: { TFlowSeparationSolveRow }, velocityByEntity: { [number]: Vector2 }?, touchedSettledNeighborByEntity: { [number]: boolean }?) -> ({ [number]: Vector2 }, { [number]: boolean }),
	_ResolveFlowBuildFrameState: (self: TMovementService, entity: number, movementState: TFlowMovementState) -> Result.Result<TFlowBuildFrameStatePayload>,
	_ResolveFlowTickId: (self: TMovementService, services: TFlowSchedulerServices?) -> number,
	_ResolveFlowDeltaTime: (self: TMovementService, services: TFlowSchedulerServices?) -> number,
	_BuildFlowDispatchSnapshot: (self: TMovementService, tickId: number, dt: number) -> (TFlowSeparationSolveSnapshot?, { [number]: string }?, TFlowPublishedFrameState?),
	_ReleaseFlowDispatchPayload: (self: TMovementService) -> (),
	_ReleaseFlowLatestParallelSolve: (self: TMovementService) -> (),
	_ReleaseFlowDispatchedSeparationSnapshot: (self: TMovementService) -> (),
	_GetFlowPipelineState: (self: TMovementService) -> TFlowPipelineState,
	_CanAdvanceFlowPipelineStage: (self: TMovementService, services: TFlowSchedulerServices?, stageName: TFlowPipelineState) -> boolean,
	_GetFlowVelocityParallelMinEntityCount: (self: TMovementService) -> number,
	_GetFlowSeparationParallelActorCount: (self: TMovementService) -> number,
	_GetFlowSeparationParallelBatchSize: (self: TMovementService) -> number,
	_GetFlowSeparationParallelMaxInFlightSeconds: (self: TMovementService) -> number,
	_IsFlowSeparationParallelEnabled: (self: TMovementService) -> boolean,
	_GetOrCreateFlowSeparationRunner: (self: TMovementService) -> Result.Result<TParallelRunnerLike>,
	_CreateFlowSeparationManagedJob: (self: TMovementService) -> Result.Result<TManagedJob>,
	_GetOrCreateFlowSeparationManagedJob: (self: TMovementService) -> Result.Result<TManagedJob>,
	_PrimeFlowSeparationParallelRuntime: (self: TMovementService) -> (),
	_ResetFlowInfrastructureRuntime: (self: TMovementService) -> (),
	_DestroyFlowInfrastructure: (self: TMovementService) -> (),
	_ConsumeCompletedFlowSeparationSolve: (self: TMovementService) -> Result.Result<boolean>,
	_TryDispatchFlowSeparationSolve: (self: TMovementService, payload: TFlowSeparationDispatchPayload) -> Result.Result<boolean>,
	_PublishCompletedFlowSolve: (self: TMovementService) -> (),
	_AdvanceFlowPipeline: (self: TMovementService, services: TFlowSchedulerServices?) -> (),
	_GetFlowConfig: (self: TMovementService) -> TFlowSoftSeparationConfig,
	_GetFlowVelocityAlpha: (self: TMovementService) -> number,
	_GetFlowClumpRadiusStuds: (self: TMovementService) -> number,
	_GetFlowClumpTouchPaddingStuds: (self: TMovementService) -> number,
	_GetFlowAgentRadiusStuds: (self: TMovementService, entity: number) -> number,
	_StartFlow: (self: TMovementService, entity: number, goalPosition: Vector3) -> Result.Result<boolean>,
	_HandleFlowGoalChange: (self: TMovementService, entity: number, movementState: TFlowMovementState, goalPosition: Vector3) -> Result.Result<nil>,
	_SampleFlowDirectionXZ: (self: TMovementService, movementState: TFlowMovementState, position: Vector3) -> Vector2?,
	_BuildFlowSolutionForInput: (self: TMovementService, goalPosition: Vector3, goalWorldSample: Vector3, position: Vector3, walkSpeed: number, isSettled: boolean, finalVelocityXZ: Vector2, touchedSettledNeighbor: boolean) -> (Vector2, Vector3?, boolean, boolean, boolean),
	_IsFlowAdvanceStalled: (self: TMovementService, goalPosition: Vector3, goalWorldSample: Vector3, position: Vector3, velocityXZ: Vector2, moveTarget: Vector3?) -> boolean,
	_ShouldForceFlowCellRecovery: (self: TMovementService, goalPosition: Vector3, goalWorldSample: Vector3, position: Vector3) -> boolean,
	_BuildRecoveredFlowAdvanceInput: (self: TMovementService, entity: number, movementState: TFlowMovementState, goalPosition: Vector3, position: Vector3, walkSpeed: number) -> (Vector2?, Vector3?, "Recovered" | "RetryLater" | "Fatal", string?),
	_TryContinueLatchedEscapeWithoutSolve: (self: TMovementService, entity: number, movementState: TFlowMovementState, reason: string) -> boolean,
	_TryRepairFlowGoalMembership: (self: TMovementService, entity: number, movementState: TFlowMovementState) -> (boolean, string?),
	_StepFlowAdvance: (self: TMovementService, entity: number, movementState: TFlowMovementState, services: TFlowSchedulerServices?) -> Result.Result<TFlowAdvanceStepResult>,
}

return table.freeze(MovementServiceTypes)
