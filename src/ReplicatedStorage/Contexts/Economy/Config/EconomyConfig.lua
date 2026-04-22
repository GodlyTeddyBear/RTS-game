--!strict

--[[
	Module: EconomyConfig
	Purpose: Defines the shared economy constants used by server and client code.
	Used In System: Imported by wallet, validation, and UI-adjacent economy modules.
	Boundaries: Owns static configuration only; does not own mutable state or per-player runtime values.
]]

-- [Constants]

--[=[
	@class EconomyConfig
	Defines the shared economy constants used by server and client code.
	@server
	@client
]=]
local EconomyConfig = {}

--[=[
	@prop STARTING_WALLET table
	@within EconomyConfig
	The wallet assigned at the start of each run.
]=]
EconomyConfig.STARTING_WALLET = {
	energy = 20,
	resources = {},
}

--[=[
	@prop WAVE_CLEAR_BONUS number
	@within EconomyConfig
	The energy reward granted when a wave enters `Resolution`.
]=]
EconomyConfig.WAVE_CLEAR_BONUS = 10

--[=[
	@prop RESOURCE_TYPES { string }
	@within EconomyConfig
	The configured zone resource names supported by the wallet.
]=]
EconomyConfig.RESOURCE_TYPES = {
	"Metal",
	"Crystal",
}

--[=[
	@prop RESOURCE_CAPS table<string, number>
	@within EconomyConfig
	The maximum balance allowed for each resource type.
]=]
EconomyConfig.RESOURCE_CAPS = {
	Energy = 100,
	Metal = 50,
	Crystal = 50,
}

-- Freeze nested tables so config consumers cannot mutate shared defaults.
table.freeze(EconomyConfig.STARTING_WALLET.resources)
table.freeze(EconomyConfig.STARTING_WALLET)
table.freeze(EconomyConfig.RESOURCE_TYPES)
table.freeze(EconomyConfig.RESOURCE_CAPS)

return table.freeze(EconomyConfig)
