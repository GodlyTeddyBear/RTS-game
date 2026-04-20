--!strict

--[[
	FlagSerializer - Split/Merge player flags for Blink transport

	Blink requires static types per map. Player flags are boolean | string | number,
	so we split them into three typed maps for network transport and merge them
	back into a unified TPlayerFlags table on receive.

	Usage:
		-- Server (before sending over Blink):
		local split = FlagSerializer.SplitFlags(playerFlags)
		-- split.BoolFlags, split.NumberFlags, split.StringFlags

		-- Client (after receiving from Blink):
		local merged = FlagSerializer.MergeFlags(boolFlags, numberFlags, stringFlags)
		-- merged: TPlayerFlags
]]

local FlagSerializer = {}

export type TSplitFlags = {
	BoolFlags: { [string]: boolean },
	NumberFlags: { [string]: number },
	StringFlags: { [string]: string },
}

--[=[
	Splits a unified TPlayerFlags table into three typed maps.

	@param flags { [string]: boolean | string | number } - Unified flags
	@return TSplitFlags - Three typed maps: BoolFlags, NumberFlags, StringFlags
]=]
function FlagSerializer.SplitFlags(flags: { [string]: any }): TSplitFlags
	local boolFlags: { [string]: boolean } = {}
	local numberFlags: { [string]: number } = {}
	local stringFlags: { [string]: string } = {}

	for flagName, flagValue in pairs(flags) do
		local valueType = type(flagValue)
		if valueType == "boolean" then
			boolFlags[flagName] = flagValue
		elseif valueType == "number" then
			numberFlags[flagName] = flagValue
		elseif valueType == "string" then
			stringFlags[flagName] = flagValue
		end
	end

	return {
		BoolFlags = boolFlags,
		NumberFlags = numberFlags,
		StringFlags = stringFlags,
	}
end

--[=[
	Merges three typed maps back into a unified TPlayerFlags table.

	@param boolFlags { [string]: boolean }? - Boolean flags
	@param numberFlags { [string]: number }? - Number flags
	@param stringFlags { [string]: string }? - String flags
	@return { [string]: boolean | string | number } - Unified flags
]=]
function FlagSerializer.MergeFlags(
	boolFlags: { [string]: boolean }?,
	numberFlags: { [string]: number }?,
	stringFlags: { [string]: string }?
): { [string]: any }
	local merged: { [string]: any } = {}

	if boolFlags then
		for flagName, flagValue in pairs(boolFlags) do
			merged[flagName] = flagValue
		end
	end

	if numberFlags then
		for flagName, flagValue in pairs(numberFlags) do
			merged[flagName] = flagValue
		end
	end

	if stringFlags then
		for flagName, flagValue in pairs(stringFlags) do
			merged[flagName] = flagValue
		end
	end

	return merged
end

return FlagSerializer
