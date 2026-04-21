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
	Per-player wallet atom keyed by `userId`.
]=]
export type ResourceAtom = { [number]: ResourceWallet }

return table.freeze(EconomyTypes)
