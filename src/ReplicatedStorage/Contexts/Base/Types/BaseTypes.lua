--!strict

--[=[
	@class BaseTypes
	Defines shared base state and ECS component shapes.
	@server
	@client
]=]
local BaseTypes = {}

export type BaseState = {
	hp: number,
	maxHp: number,
}

export type BaseAtomState = BaseState?

export type HealthComponent = {
	hp: number,
	maxHp: number,
}

export type InstanceRefComponent = {
	Instance: Instance,
	Anchor: BasePart,
}

export type IdentityComponent = {
	BaseId: string,
}

export type ActiveTag = boolean

return table.freeze(BaseTypes)
