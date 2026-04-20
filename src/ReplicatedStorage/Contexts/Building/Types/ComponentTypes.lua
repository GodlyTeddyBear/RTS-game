--!strict

export type TBuildingComponent = {
	BuildingId: string,
	UserId: number,
	ZoneName: string,
	SlotIndex: number,
	BuildingType: string,
	Level: number,
}

export type TBuildingGameObjectComponent = {
	Instance: Model,
}

export type TBuildingDirtyTag = boolean

return {}
