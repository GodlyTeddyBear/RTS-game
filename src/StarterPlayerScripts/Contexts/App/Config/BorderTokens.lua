--!strict
--[=[
	@class BorderTokens
	Design token constants for corner radius and stroke thickness scales.
	@client
]=]

--[=[
	@prop BorderTokens { Radius: { [string]: UDim }, Width: { [string]: number } }
	@within BorderTokens
	Frozen table of border tokens with corner radius sizes (`Radius`) and stroke thicknesses (`Width`).
]=]

local BorderTokens = {
	Radius = table.freeze({
		None = UDim.new(0, 0),
		SM = UDim.new(0, 4),
		MD = UDim.new(0, 8),
		LG = UDim.new(0, 12),
		XL = UDim.new(0, 16),
		Full = UDim.new(0.5, 0),
	}),

	Width = table.freeze({
		None = 0,
		Thin = 1,
		Medium = 2,
		Thick = 3,
	}),
}

export type TBorderTokens = typeof(BorderTokens)
return table.freeze(BorderTokens)
