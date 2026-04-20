--!strict
--[=[
	@class SpacingTokens
	Design token constants for spacing scales (padding, margins, gaps).
	@client
]=]

--[=[
	@prop SpacingTokens { [string]: number }
	@within SpacingTokens
	Frozen table of spacing tokens: None, XS, SM, MD, LG, XL, XXL, XXXL (in pixels).
]=]

return table.freeze({
	None = 0,
	XS = 4,
	SM = 8,
	MD = 12,
	LG = 16,
	XL = 20,
	XXL = 24,
	XXXL = 32,
})
