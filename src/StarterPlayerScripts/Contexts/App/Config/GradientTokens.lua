--!strict
--[=[
	@class GradientTokens
	Design token constants for reusable colour gradients and icon asset IDs used throughout the UI.
	@client
]=]

--[=[
	@prop GradientTokens { [string]: ColorSequence | string }
	@within GradientTokens
	Frozen table of named gradients (e.g. BAR_GRADIENT, GOLD_STROKE) and icon asset IDs.
]=]

return table.freeze({
	-- Top bar background: dark → mid-grey → dark (horizontal)
	BAR_GRADIENT = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
		ColorSequenceKeypoint.new(0.534, Color3.fromRGB(45, 44, 44)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
	}),

	-- Gold border stroke gradient (used on bars, panels, buttons)
	GOLD_STROKE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 204, 0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(250, 242, 210)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 204, 0)),
	}),

	-- Icon button background gradient (slightly lighter center)
	BUTTON_GRADIENT = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
		ColorSequenceKeypoint.new(0.534, Color3.fromRGB(57, 57, 57)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
	}),

	-- Side panel background gradient (rotated)
	PANEL_GRADIENT = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
		ColorSequenceKeypoint.new(0.534, Color3.fromRGB(32, 30, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
	}),

	-- Active/hovered tab background gradient (gold tones)
	TAB_ACTIVE_GRADIENT = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 29, 0)),
		ColorSequenceKeypoint.new(0.164, Color3.fromRGB(44, 36, 7)),
		ColorSequenceKeypoint.new(0.504, Color3.fromRGB(247, 201, 110)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 204, 0)),
	}),

	-- Active/hovered tab stroke gradient
	TAB_ACTIVE_STROKE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 29, 0)),
		ColorSequenceKeypoint.new(0.174, Color3.fromRGB(40, 33, 2)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(250, 232, 94)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 238, 108)),
	}),

	-- Inactive tab background gradient (dark)
	TAB_INACTIVE_GRADIENT = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 23, 23)),
		ColorSequenceKeypoint.new(0.62, Color3.fromRGB(29, 23, 23)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(19, 17, 17)),
	}),

	-- Green button gradient (Hire Worker)
	GREEN_BUTTON_GRADIENT = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(52, 199, 89)),
		ColorSequenceKeypoint.new(0.519, Color3.fromRGB(190, 242, 203)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(52, 199, 89)),
	}),

	-- Green button decore stroke
	GREEN_BUTTON_STROKE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 44, 20)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(29, 141, 57)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 63, 28)),
	}),

	-- Red assign button gradient
	ASSIGN_BUTTON_GRADIENT = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 56, 60)),
		ColorSequenceKeypoint.new(0.462, Color3.fromRGB(255, 118, 121)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 56, 60)),
	}),

	-- Red assign button decore stroke
	ASSIGN_BUTTON_STROKE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 24, 28)),
		ColorSequenceKeypoint.new(0.558, Color3.fromRGB(233, 3, 8)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(86, 3, 5)),
	}),

	-- Red assign dropdown border stroke
	ASSIGN_DROPDOWN_STROKE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 6, 8)),
		ColorSequenceKeypoint.new(0.462, Color3.fromRGB(245, 50, 54)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(159, 3, 6)),
	}),

	-- Purple options button gradient
	OPTIONS_BUTTON_GRADIENT = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(203, 48, 224)),
		ColorSequenceKeypoint.new(0.440, Color3.fromRGB(238, 148, 251)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(203, 48, 224)),
	}),

	-- Purple options button decore stroke
	OPTIONS_BUTTON_STROKE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 16, 134)),
		ColorSequenceKeypoint.new(0.558, Color3.fromRGB(215, 48, 237)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(123, 2, 140)),
	}),

	-- Purple options dropdown border stroke
	OPTIONS_DROPDOWN_STROKE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(105, 3, 118)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(215, 48, 237)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(123, 2, 140)),
	}),

	-- Blue XP bar fill gradient
	XP_BAR_GRADIENT = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 16, 122)),
		ColorSequenceKeypoint.new(0.514, Color3.fromRGB(62, 88, 252)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(137, 149, 226)),
	}),

	-- Blue XP bar stroke gradient
	XP_BAR_STROKE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 70, 249)),
		ColorSequenceKeypoint.new(0.538, Color3.fromRGB(127, 195, 254)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(181, 218, 251)),
	}),

	-- Inventory-specific tokens
	LIST_CONTAINER_GRADIENT = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 18)),
		ColorSequenceKeypoint.new(0.481, Color3.fromRGB(33, 35, 27)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(33, 32, 32)),
	}),

	GOLD_STROKE_SUBTLE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 80, 0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(250, 242, 210)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 204, 0)),
	}),

	SLOT_GRADIENT = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
		ColorSequenceKeypoint.new(0.519, Color3.fromRGB(26, 19, 19)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
	}),

	SLOT_DECORE_STROKE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(63, 50, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
	}),

	SLOT_ICON_GRADIENT = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 55, 55)),
		ColorSequenceKeypoint.new(0.519, Color3.fromRGB(42, 37, 37)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(57, 51, 51)),
	}),

	DETAIL_ICON_STROKE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(57, 57, 57)),
		ColorSequenceKeypoint.new(0.519, Color3.fromRGB(26, 19, 19)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(43, 38, 38)),
	}),

	GREEN_ACTION_GRADIENT = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 111)),
		ColorSequenceKeypoint.new(0.510, Color3.fromRGB(105, 252, 169)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 153, 66)),
	}),

	GREEN_ACTION_DECORE_COLOR = Color3.fromRGB(2, 212, 93),
	GREEN_ACTION_LABEL_STROKE_COLOR = Color3.fromRGB(2, 87, 39),
	BUY_TAB_LABEL_STROKE_COLOR = Color3.fromRGB(5, 101, 47),
	SELL_TAB_LABEL_STROKE_COLOR = Color3.fromRGB(200, 24, 28),
	CATEGORY_TAB_LABEL_STROKE_COLOR = Color3.fromRGB(46, 38, 8),
	GOLD_SCROLLBAR_COLOR = Color3.fromRGB(255, 204, 0),
	NEAR_BLACK = Color3.fromRGB(4, 4, 4),

	-- Quest entry row warm-gold stroke
	QUEST_ROW_STROKE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(251, 233, 159)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 204, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(124, 99, 0)),
	}),

	-- Icon asset IDs
	ICON_SETTINGS = "rbxassetid://118038477469568",
	ICON_SIDEBAR = "rbxassetid://140346644030535",
	ICON_BACK_ARROW = "rbxassetid://138331787489393",
	ICON_MINUS = "rbxassetid://139613383055160",
	ICON_PLUS = "rbxassetid://134254046400292",
})
