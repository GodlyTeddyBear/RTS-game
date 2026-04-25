--!strict

--[=[
	@class MiningTypes
	Defines shared data shapes for extractor-based mining.
	@server
	@client
]=]
local MiningTypes = {}

export type TExtractorRecord = {
	instanceId: number,
	ownerUserId: number,
	resourceType: string,
	intervalSeconds: number,
	amountPerCycle: number,
}

export type TResourceNodeRecord = {
	nodeId: string,
	instance: BasePart,
	resourceType: string,
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
