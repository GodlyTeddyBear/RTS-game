--!strict

export type TVillagerBehaviorType = "Customer" | "Merchant"
export type TVillagerState = "Spawning" | "WalkingToShop" | "WaitingForOffer" | "Departing" | "Complete"
export type TPathStatus = "Idle" | "Moving" | "Reached" | "Failed"

export type TVillagerArchetype = {
	Id: string,
	DisplayName: string,
	ModelKey: string,
	BehaviorType: TVillagerBehaviorType,
	SpawnWeight: number,
	MerchantShopId: string?,
}

export type TVillagerIdentityComponent = {
	VillagerId: string,
	ArchetypeId: string,
	DisplayName: string,
	BehaviorType: TVillagerBehaviorType,
	MerchantShopId: string?,
}

export type TPositionComponent = {
	CFrame: CFrame,
}

export type TModelRefComponent = {
	Instance: Model,
}

export type TRouteComponent = {
	CurrentTarget: Vector3?,
	PathStatus: TPathStatus,
	PathStartedAt: number,
}

export type TVisitComponent = {
	State: TVillagerState,
	TargetUserId: number?,
	Entrance: BasePart?,
	WaitPoint: BasePart?,
	ExitPoint: BasePart?,
	OfferId: string?,
	LastStateChangedAt: number,
}

export type TCleanupComponent = {
	Reason: string,
	RequestedAt: number,
}

export type TDirtyTag = boolean

return {}
