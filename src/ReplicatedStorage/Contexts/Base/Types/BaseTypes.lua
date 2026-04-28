--!strict

--[=[
	@class BaseTypes
	Defines shared base state and ECS component shapes.
	@server
	@client
]=]
local BaseTypes = {}

export type BaseState = {
	Hp: number,
	MaxHp: number,
}

export type BaseAtomState = BaseState?

export type HealthComponent = {
	Hp: number,
	MaxHp: number,
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
