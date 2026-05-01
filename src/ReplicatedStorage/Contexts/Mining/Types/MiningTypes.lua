--!strict

--[=[
	@class MiningTypes
	Defines shared data shapes for extractor-based mining.
	@server
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MiningTypes = {}

local AIContractTypes = require(ReplicatedStorage.Utilities.AI.ContractTypes)

export type TExtractorRecord = {
	InstanceId: number,
	OwnerUserId: number,
	ResourceType: string,
	IntervalSeconds: number,
	AmountPerCycle: number,
}

export type TResourceNodeRecord = {
	NodeId: string,
	Instance: BasePart,
	ResourceType: string,
}

export type TOwnerComponent = {
	UserId: number,
}

export type TResourceComponent = {
	ResourceType: string,
	AmountPerCycle: number,
}

export type TTimingComponent = {
	IntervalSeconds: number,
	ElapsedSeconds: number,
}

export type TMiningActionState = {
	CurrentActionId: string?,
	ActionState: string,
	ActionData: any?,
	PendingActionId: string?,
	PendingActionData: any?,
	StartedAt: number?,
	FinishedAt: number?,
}

export type TInstanceRefComponent = {
	InstanceId: number,
}

export type TResourceNodeComponent = {
	NodeId: string,
	ResourceType: string,
}

export type TNodeInstanceComponent = {
	Instance: BasePart,
}

export type TMiningActorTypePayload = {
	ActorType: string,
	Conditions: { [string]: (any?) -> any },
	Commands: { [string]: (any?) -> any },
	Executors: { [string]: any },
	Hooks: { any }?,
	SemanticRequirements: AIContractTypes.TSemanticRequirements?,
	RuntimeBinding: AIContractTypes.TRuntimeBinding?,
	RuntimeOwner: any?,
}

export type TMiningActorAdapter = {
	IsActive: () -> boolean,
	GetActorLabel: (() -> string?)?,
	BuildFacts: (currentTime: number) -> { [string]: any },
	BuildServices: (currentTime: number) -> { [string]: any },
	OnCancel: (() -> ())?,
	OnRemoved: (() -> ())?,
	OnActionResult: ((any) -> ())?,
	OnActionStateChanged: ((TMiningActionState) -> ())?,
}

export type TMiningActorPayload = {
	ActorType: string,
	ActorHandle: string,
	BehaviorDefinition: any,
	TickInterval: number,
	Adapter: TMiningActorAdapter,
}

export type TMiningActorRecord = {
	RuntimeId: number,
	ActorType: string,
	ActorHandle: string,
	BehaviorTree: any,
	TickInterval: number,
	LastTickTime: number,
	ActionState: TMiningActionState,
	Adapter: TMiningActorAdapter,
}

return table.freeze(MiningTypes)
