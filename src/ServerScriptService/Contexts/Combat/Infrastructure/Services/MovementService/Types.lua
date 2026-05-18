--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyTypes = require(ReplicatedStorage.Contexts.Enemy.Types.EnemyTypes)
local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)

local MovementServiceTypes = {}

export type EnemyMovementMode = EnemyTypes.EnemyMovementMode
export type TFlowPipelineState = "Idle" | "Dispatching" | "Waiting" | "Publishing"

export type TPathMovementState = {
	Mode: "Path",
	Promise: any,
}

export type TFlowMovementState = {
	Mode: "Flow",
	GoalSnapshot: Vector3,
	GoalKey: string,
	GoalWorldSample: Vector3,
}

export type TMovementState = TPathMovementState | TFlowMovementState

export type TSharedFlowfieldEntry = {
	Flowfield: any,
	GoalCell: Vector2,
	GoalWorldSample: Vector3,
	LastRefreshClock: number,
	RefreshInProgress: boolean,
	RefCount: number,
}

export type TFlowActorRefs = {
	Model: Model?,
	RootPart: BasePart?,
	Humanoid: Humanoid?,
	LastWalkSpeed: number?,
}

export type TFlowSeparationSolveSnapshot = {
	TickId: number,
	EntityCount: number,
	EntityIds: { number },
	GoalGroupId: { number },
	GoalGroupStartIndex: { number },
	GoalGroupCount: { number },
	GoalGroupCellWidthStuds: { number },
	GroupCellX: { number },
	GroupCellY: { number },
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

export type TFlowSeparationSolveRow = {
	EntityIndex: number,
	VelocityX: number,
	VelocityY: number,
	TouchedSettledNeighbor: boolean,
}

export type TFlowPublishedSolve = {
	TickId: number,
	VelocityByEntity: { [number]: Vector2 },
	TouchedSettledNeighborByEntity: { [number]: boolean },
	GoalKeyByEntity: { [number]: string },
}

export type TFlowPublishedFrameState = {
	GoalKeyByEntity: { [number]: string },
	GoalPositionByEntity: { [number]: Vector3 },
	GoalWorldSampleByEntity: { [number]: Vector3 },
	PositionByEntity: { [number]: Vector3 },
	WalkSpeedByEntity: { [number]: number },
	IsSettledByEntity: { [number]: boolean },
}

export type TManagedJob = ParallelQuery.TManagedJob

return table.freeze(MovementServiceTypes)
