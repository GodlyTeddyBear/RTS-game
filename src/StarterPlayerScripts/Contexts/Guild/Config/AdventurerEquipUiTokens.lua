--!strict

local AdventurerEquipUiTokens = table.freeze({
	ROOT_PANEL_SIZE = UDim2.fromScale(1, 0.76172),
	ROOT_PANEL_POSITION = UDim2.fromScale(0.5, 0.53826),

	LEFT_PANEL_SIZE = UDim2.fromScale(0.34444, 0.9239),
	RIGHT_PANEL_SIZE = UDim2.fromScale(0.35, 0.9239),
	LEFT_PANEL_POSITION = UDim2.fromScale(0.03, 0.5),
	RIGHT_PANEL_POSITION = UDim2.fromScale(0.97, 0.5),
	CENTER_GAP_SIZE = UDim2.fromScale(0.19167, 0.7396),

	SLOT_CORNER_RADIUS = UDim.new(0, 9),
	SLOT_DECORE_CORNER_RADIUS = UDim.new(0, 0),
	SLOT_FONT_SIZE = 22,

	ITEM_TILE_CORNER_RADIUS = UDim.new(0, 9),
	ITEM_TILE_FONT_SIZE = 22,
	ITEM_TILE_STATS_SIZE = 16,

	STAT_LABEL_SIZE = 25,
	STAT_VALUE_SIZE = 25,
})

return AdventurerEquipUiTokens
