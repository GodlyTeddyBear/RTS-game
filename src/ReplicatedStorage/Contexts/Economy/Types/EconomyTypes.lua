--!strict

--[=[
	@class EconomyTypes
	Defines the shared economy wallet and atom types used by sync and context code.
	@server
	@client
]=]
local EconomyTypes = {}

--[=[
	@type ResourceType string
	@within EconomyTypes
	Names a resource entry in the economy wallet.
]=]
export type ResourceType = "Energy" | string

--[=[
	@type ZoneResourceMap table<string, number>
	@within EconomyTypes
	Maps zone resource names to their current balances.
]=]
export type ZoneResourceMap = { [string]: number }

--[=[
	@interface ResourceWallet
	@within EconomyTypes
	.energy number -- Current energy balance.
	.resources ZoneResourceMap -- Current zone resource balances.
]=]
export type ResourceWallet = {
	energy: number,
	resources: ZoneResourceMap,
}

--[=[
	@type ResourceAtom table<number, ResourceWallet>
	@within EconomyTypes
	Per-player wallet atom keyed by `userId`.
]=]
export type ResourceAtom = { [number]: ResourceWallet }

return table.freeze(EconomyTypes)
