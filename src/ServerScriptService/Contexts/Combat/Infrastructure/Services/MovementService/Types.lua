--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyTypes = require(ReplicatedStorage.Contexts.Enemy.Types.EnemyTypes)
local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)

local MovementServiceTypes = {}

type TManagedAsyncState = ParallelQuery.TManagedAsyncState

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

export type TFlowVelocitySolveInput = {
	Entity: number,
	FlowXZ: Vector2,
	SeparationXZ: Vector2,
	PreviousVelocityXZ: Vector2,
	WalkSpeed: number,
	VelAlpha: number,
}

export type TFlowVelocitySolveSnapshot = {
	EntityIds: { number },
	EntityIndexById: { [number]: number },
	FlowX: { [number]: number },
	FlowY: { [number]: number },
	SeparationX: { [number]: number },
	SeparationY: { [number]: number },
	PreviousVelocityX: { [number]: number },
	PreviousVelocityY: { [number]: number },
	WalkSpeed: { [number]: number },
	VelAlpha: { [number]: number },
}

export type TFlowVelocitySolveRow = {
	EntityIndex: number,
	VelocityX: number,
	VelocityY: number,
	ShouldMove: boolean,
}

export type TFlowSeparationPairSnapshotBuildInput = {
	CandidateCellKeys: { number },
	CellEntityStarts: { [number]: number },
	CellEntityCounts: { [number]: number },
	EligibleEntityIds: { [number]: number },
	TaskCellIndices: { [number]: number },
	TaskOuterStartOffsets: { [number]: number },
	TaskOuterEndOffsets: { [number]: number },
	TaskEntityStartIndices: { [number]: number },
	TaskEntityCounts: { [number]: number },
	EntityPositionXById: { [number]: number },
	EntityPositionYById: { [number]: number },
	EntityRadiusById: { [number]: number },
	KForce: number,
	MinSeparationDistance: number,
}

export type TFlowSeparationPairSnapshotBuildAsyncState = TManagedAsyncState

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
	ParallelPairDispatches: number,
	ParallelPairsDispatched: number,
	ParallelPairRowsApplied: number,
	ParallelPairSnapshotBuilds: number,
	ParallelPairSnapshotEntities: number,
	ParallelPairSnapshotPairs: number,
	ParallelPairSnapshotBuildMilliseconds: number,
	ParallelPairSnapshotAsyncDispatches: number,
	ParallelPairSnapshotAsyncCompleted: number,
	ParallelPairSnapshotAsyncApplied: number,
	ParallelPairSnapshotAsyncStaleResults: number,
	ParallelPairSnapshotAsyncDroppedResults: number,
	ParallelPairSnapshotAsyncInFlightSkips: number,
	ParallelPairSnapshotAsyncErrorFallbacks: number,
	ParallelPairSnapshotChunkedCells: number,
	ParallelPairSnapshotTasksGenerated: number,
	ParallelPairSnapshotOverflowLocalFallbacks: number,
	ParallelPairBelowThresholdSkips: number,
	ParallelPairFailedFallbacks: number,
	ParallelPairAsyncErrorFallbacks: number,
	ParallelVelocityDispatches: number,
	ParallelVelocityEntitiesDispatched: number,
	ParallelVelocityRowsApplied: number,
	ParallelVelocityAsyncDispatches: number,
	ParallelVelocityAsyncCompleted: number,
	ParallelVelocityAsyncApplied: number,
	ParallelVelocityAsyncStaleResults: number,
	ParallelVelocityAsyncDroppedResults: number,
	ParallelVelocityAsyncInFlightSkips: number,
	ParallelVelocityAsyncErrorFallbacks: number,
	ParallelFallbacks: number,
	ParallelAsyncDispatches: number,
	ParallelAsyncCompleted: number,
	ParallelAsyncApplied: number,
	ParallelAsyncStaleResults: number,
	ParallelAsyncDroppedResults: number,
	ParallelAsyncInFlightSkips: number,
}

export type TFlowActorRefs = {
	Model: Model?,
	RootPart: BasePart?,
	Humanoid: Humanoid?,
	LastWalkSpeed: number?,
}

return table.freeze(MovementServiceTypes)
