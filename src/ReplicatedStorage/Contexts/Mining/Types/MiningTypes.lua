--!strict

--[=[
	@class MiningTypes
	Defines shared data shapes for extractor-based mining.
	@server
	@client
]=]
local MiningTypes = {}

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

return table.freeze(MiningTypes)
