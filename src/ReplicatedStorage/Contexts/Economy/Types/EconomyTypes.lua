--!strict

--[[
	Module: EconomyTypes
	Purpose: Defines the shared economy wallet, atom, and run-stat types used by server and client code.
	Used In System: Imported anywhere Economy context code needs a stable replicated type shape.
	Boundaries: Owns type declarations only; does not own runtime logic, defaults, or validation.
]]

-- [Types]

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
	@type ResourceCostMap table<string, number>
	@within EconomyTypes
	Maps resource names to required spend amounts.
]=]
export type ResourceCostMap = { [string]: number }

--[=[
	@interface ProfileRunStats
	@within EconomyTypes
	.TotalRuns number -- Number of completed runs recorded for the player.
	.BestWave number -- Highest wave number reached across sessions.
	.TotalWavesCleared number -- Lifetime count of cleared waves.
]=]
export type ProfileRunStats = {
	TotalRuns: number,
	BestWave: number,
	TotalWavesCleared: number,
}

--[=[
	@interface ResourceWallet
	@within EconomyTypes
	.energy number -- Current energy balance.
	.resources ZoneResourceMap -- Current zone resource balances.
	.runStats ProfileRunStats? -- Optional persisted run stats snapshot for client HUDs.
]=]
export type ResourceWallet = {
	energy: number,
	resources: ZoneResourceMap,
	runStats: ProfileRunStats?,
}

--[=[
	@type ResourceAtom table<number, ResourceWallet>
	@within EconomyTypes
	Server-side per-player wallet atom keyed by `userId`.
]=]
export type ResourceAtom = { [number]: ResourceWallet }

--[=[
	@type ResourceClientState ResourceWallet?
	@within EconomyTypes
	Client-side player-scoped wallet snapshot received from sync payloads.
]=]
export type ResourceClientState = ResourceWallet?

return table.freeze(EconomyTypes)
