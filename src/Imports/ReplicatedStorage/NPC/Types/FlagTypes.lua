--!strict

--[[
	FlagTypes - Type definitions for player state flags

	Flags are persistent key-value pairs that drive dialogue conditions
	and track player progress. Values can be boolean, string, or number.
]]

export type TFlagValue = boolean | string | number
export type TPlayerFlags = { [string]: TFlagValue }
export type TClientFlags = TPlayerFlags -- Client stores just this player's flags
export type TAllPlayerFlags = { [number]: TPlayerFlags } -- Server: userId → flags

return {}
