--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyTypes = require(ReplicatedStorage.Contexts.Enemy.Types.EnemyTypes)

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

export type TAdvanceStatus = "Running" | "Success" | "Fail"

export type TAdvanceFrameResult = {
	Status: TAdvanceStatus,
	Reason: string?,
	FrameId: number,
}

export type TSharedFlowfieldEntry = {
	Flowfield: any,
	GoalCell: Vector2,
	GoalWorldSample: Vector3,
	LastRefreshClock: number,
	RefreshInProgress: boolean,
	RefCount: number,
}

export type TFlowSeparationCoveredCell = {
	Key: number,
	Gx: number,
	Gz: number,
}

export type TFlowSeparationEntityState = {
	Position: Vector3?,
	FlatPosition: Vector2?,
	Radius: number,
	GoalKey: string?,
	Settled: boolean,
	Active: boolean,
	CoveredCells: { TFlowSeparationCoveredCell },
	Separation: Vector2,
	NearGoalScale: number,
	LastSpatialRefreshFlatPosition: Vector2?,
	IsInsideNearGoalBand: boolean,
	LastGoalKey: string?,
	LastDirtyMarkFlatPosition: Vector2?,
}

export type TFlowSeparationRuntime = {
	SessionUserId: number?,
	CurrentTime: number?,
	CellWidthStuds: number,
	EntityStateById: { [number]: TFlowSeparationEntityState },
	BucketsByCell: { [number]: { [number]: boolean } },
	DirtyEntities: { [number]: boolean },
	DirtyCells: { [number]: boolean },
	TrackedFlowEntities: { [number]: boolean },
	ActiveFlowEntities: { [number]: boolean },
	ActiveSolveEntities: { [number]: boolean },
}

export type TFastFlowProfileCounters = {
	SharedFieldCreations: number,
	SharedFieldRefreshes: number,
	MergeAttempts: number,
	TrackedFlowEntities: number,
	ActiveSeparationEntities: number,
	DenseCellsEncountered: number,
	DenseCellFallbackActivations: number,
	DirtyEntitiesProcessed: number,
	DirtyCellsProcessed: number,
	LocalPairSolves: number,
	BucketMembershipUpdates: number,
	CachedRootPartHits: number,
	CachedRootPartMisses: number,
	CachedHumanoidHits: number,
	CachedHumanoidMisses: number,
	SpatialRefreshCalls: number,
	CoveredCellRecomputes: number,
	NearGoalBandRecomputes: number,
	DirtyMarksTriggered: number,
	DirtyMarksSkipped: number,
}

export type TFlowActorRefs = {
	Model: Model?,
	RootPart: BasePart?,
	Humanoid: Humanoid?,
	LastWalkSpeed: number?,
}

return table.freeze(MovementServiceTypes)
