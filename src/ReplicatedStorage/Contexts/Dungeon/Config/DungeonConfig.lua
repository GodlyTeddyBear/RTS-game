--!strict

--[[
	DungeonConfig - Configuration for procedural dungeon generation.

	PLAYER_X_OFFSET_SPACING: Studs between each player's dungeon on the X-axis.
	AreaVariantWeights: Per-zone weighted selection for area piece variants.
		Each entry maps a model name (under Assets/Quests/[Zone]/Areas/) to a Weight.
		Higher weight = more frequent selection.
]]

return table.freeze({
	PLAYER_X_OFFSET_SPACING = 1000,

	AreaVariantWeights = table.freeze({
		GoblinCave = table.freeze({
			{ VariantName = "Area", Weight = 1 },
		}),

		OrcFortress = table.freeze({
			{ VariantName = "Area", Weight = 1 },
		}),

		TrollDen = table.freeze({
			{ VariantName = "Area", Weight = 1 },
		}),

		Default = table.freeze({
			{ VariantName = "Area", Weight = 1 },
		}),
	}),
})
