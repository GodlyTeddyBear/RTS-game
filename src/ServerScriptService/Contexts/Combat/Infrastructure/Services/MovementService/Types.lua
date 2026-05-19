--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyTypes = require(ReplicatedStorage.Contexts.Enemy.Types.EnemyTypes)
local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)

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

--[=[
    @type TFlowPipelineState
    @within Types
    Flow pipeline state label used to drive the separation solve lifecycle.
]=]
export type TFlowPipelineState = "Idle" | "Dispatching" | "Waiting" | "Publishing"

--[=[
    @interface TPathMovementState
    @within Types
    Path-based movement runtime state tracked while a path promise is active.
    .Mode string -- Movement mode discriminator.
    .Promise any -- Running path promise owned by the path movement branch.
]=]
export type TPathMovementState = {
	Mode: "Path",
	Promise: any,
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
	Flowfield: any,
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

--[=[
    @type TManagedJob
    @within Types
    ParallelQuery managed job handle used by the flow separation pipeline.
]=]
export type TManagedJob = ParallelQuery.TManagedJob

return table.freeze(MovementServiceTypes)
