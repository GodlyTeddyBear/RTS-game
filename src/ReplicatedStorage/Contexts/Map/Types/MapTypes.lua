--!strict

local MapTypes = {}

export type MapRootComponent = {
	MapId: string,
	Template: string,
	CreatedAt: number,
}

export type MapInstanceComponent = {
	Instance: Model,
}

export type ZoneComponent = {
	ZoneName: string,
	Instance: Instance,
}

export type GoalComponent = {
	Instance: BasePart,
}

export type SpawnComponent = {
	Instance: BasePart,
}

export type BaseComponent = {
	Instance: Instance,
	Anchor: BasePart,
}

export type GoalZoneTag = boolean
export type SpawnZoneTag = boolean
export type BaseZoneTag = boolean

return table.freeze(MapTypes)
