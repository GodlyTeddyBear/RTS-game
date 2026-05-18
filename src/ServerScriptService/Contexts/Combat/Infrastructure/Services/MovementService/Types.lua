--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyTypes = require(ReplicatedStorage.Contexts.Enemy.Types.EnemyTypes)
local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)

local MovementServiceTypes = {}

export type EnemyMovementMode = EnemyTypes.EnemyMovementMode

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

export type TFlowFrameInput = {
	Entity: number,
	GoalGroupId: number,
	GoalKey: string,
	GoalPosition: Vector3,
	GoalWorldSample: Vector3,
	Position: Vector3,
	FlatPosition: Vector2,
	FlowDirectionXZ: Vector2,
	WalkSpeed: number,
	Radius: number,
	PreviousVelocityXZ: Vector2,
	IsSettled: boolean,
}

export type TFlowFrameSolution = {
	VelocityXZ: Vector2,
	MoveTarget: Vector3?,
	DidArrive: boolean,
	ShouldSettle: boolean,
	HasSteering: boolean,
}

export type TFlowSeparationSolveSnapshot = {
	TickId: number,
	EntityIds: { number },
	GoalGroupId: { number },
	FlatPositionX: { number },
	FlatPositionY: { number },
	Radius: { number },
	FlowVelocityX: { number },
	FlowVelocityY: { number },
	PreviousVelocityX: { number },
	PreviousVelocityY: { number },
	WalkSpeed: { number },
	VelAlpha: { number },
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
}

export type TFlowSeparationSolveRow = {
	EntityIndex: number,
	VelocityX: number,
	VelocityY: number,
}

export type TManagedJob = ParallelQuery.TManagedJob

return table.freeze(MovementServiceTypes)
