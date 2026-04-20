--!strict
--[=[
	@class ColorTokens
	Design token constants for colour palettes across surfaces, text, accents, semantic states, borders, and NPC UI.
	@client
]=]

--[=[
	@prop ColorTokens { [string]: { [string]: Color3 } }
	@within ColorTokens
	Frozen table of colour tokens organized by category (Surface, Text, Accent, Semantic, Border, NPC).
]=]

local ColorTokens = {
	Surface = table.freeze({
		Primary = Color3.fromRGB(30, 30, 30),
		Secondary = Color3.fromRGB(50, 50, 50),
		Tertiary = Color3.fromRGB(60, 60, 60),
		Hover = Color3.fromRGB(100, 100, 100),
		White = Color3.fromRGB(255, 255, 255),
	}),

	Text = table.freeze({
		Primary = Color3.fromRGB(255, 255, 255),
		Secondary = Color3.fromRGB(200, 200, 200),
		Muted = Color3.fromRGB(150, 150, 150),
		OnDark = Color3.fromRGB(255, 255, 255),
		OnLight = Color3.fromRGB(30, 30, 30),
	}),

	Accent = table.freeze({
		Blue = Color3.fromRGB(100, 200, 255),
		Green = Color3.fromRGB(100, 255, 150),
		Red = Color3.fromRGB(255, 100, 100),
		Yellow = Color3.fromRGB(255, 220, 100),
		Purple = Color3.fromRGB(180, 120, 255),
	}),

	Semantic = table.freeze({
		Success = Color3.fromRGB(100, 255, 150),
		Error = Color3.fromRGB(255, 100, 100),
		Warning = Color3.fromRGB(255, 220, 100),
		Info = Color3.fromRGB(180, 120, 255),
	}),

	Border = table.freeze({
		Default = Color3.fromRGB(70, 70, 70),
		Subtle = Color3.fromRGB(50, 50, 50),
		Strong = Color3.fromRGB(100, 100, 100),
	}),

	Rarity = table.freeze({
		Common = Color3.fromRGB(150, 150, 150),
		Uncommon = Color3.fromRGB(100, 255, 150),
		Rare = Color3.fromRGB(100, 200, 255),
		Epic = Color3.fromRGB(180, 120, 255),
		Legendary = Color3.fromRGB(255, 220, 100),
	}),

	NPC = table.freeze({
		-- Adventurer class accent colors (from combat NPC UI design)
		WarriorRose = Color3.fromRGB(255, 180, 172),
		ScoutGold = Color3.fromRGB(233, 195, 73),
		ArcherRose = Color3.fromRGB(255, 180, 172),
		-- Panel chrome
		PanelBackground = Color3.fromRGB(12, 10, 9),
		PanelBackdrop = Color3.fromRGB(0, 0, 0),
		PanelHeaderDark = Color3.fromRGB(28, 25, 23),
		PanelBorder = Color3.fromRGB(41, 37, 36),
		PanelEntryBackground = Color3.fromRGB(28, 27, 27),
		PanelMuted = Color3.fromRGB(120, 113, 108),
		PanelSubtle = Color3.fromRGB(168, 162, 158),
		PanelText = Color3.fromRGB(229, 226, 225),
		PanelNameWarm = Color3.fromRGB(226, 190, 186),
		-- Tactical actions
		AttackCrimson = Color3.fromRGB(166, 29, 29),
		-- HP bar
		HPBackground = Color3.fromRGB(14, 14, 14),
	}),
}

export type TColorTokens = typeof(ColorTokens)
return table.freeze(ColorTokens)
