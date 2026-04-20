--!strict
--[=[
	@class TypographyTokens
	Design token constants for typography: font families and size scales.
	@client
]=]

--[=[
	@prop TypographyTokens { Font: { [string]: Enum.Font }, FontSize: { [string]: number } }
	@within TypographyTokens
	Frozen table of typography tokens with font families (`Font`) and font sizes (`FontSize`).
]=]

local GOTHAM = "rbxasset://fonts/families/GothamSSm.json"

local TypographyTokens = {
	Font = table.freeze({
		Body = Enum.Font.Gotham,
		Heading = Enum.Font.GothamMedium,
		Bold = Enum.Font.GothamBold,
		Monospace = Enum.Font.RobotoMono,
	}),

	-- FontFace variants for APIs that require Font.new() (weight/style control).
	FontFace = table.freeze({
		Body = Font.new(GOTHAM),
		Bold = Font.new(GOTHAM, Enum.FontWeight.Bold, Enum.FontStyle.Normal),
	}),

	FontSize = table.freeze({
		Display = 48,
		H1 = 32,
		H2 = 24,
		H3 = 20,
		Body = 16,
		Small = 14,
		Caption = 12,
		Tiny = 10,
	}),
}

export type TTypographyTokens = typeof(TypographyTokens)
return table.freeze(TypographyTokens)
