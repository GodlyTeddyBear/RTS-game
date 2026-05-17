--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParallelQuery = require(ReplicatedStorage.Utilities.ParallelQuery)

local FlowSeparationTypes = {}

export type TFlowSeparationPairSnapshot = {
	EntityIds: { number },
	EntityIndexById: { [number]: number },
	PositionX: { [number]: number },
	PositionY: { [number]: number },
	Radius: { [number]: number },
	PairA: { [number]: number },
	PairB: { [number]: number },
	KForce: number,
	MinSeparationDistance: number,
}

export type TFlowSeparationPairRows = { [number]: { [string]: any } }

export type TManagedJob = ParallelQuery.TManagedJob
export type TManagedAsyncResult = ParallelQuery.TManagedAsyncResult

return table.freeze(FlowSeparationTypes)
