--!strict

local DEFAULT_WIDGET_SIZE = Vector2.new(340, 620)
local MIN_WIDGET_SIZE = Vector2.new(300, 420)
local MAX_RECENT_ASSETS = 8

local DEFAULT_FOLDER_PRESETS = {
	"Props",
	"Decor",
	"Structure",
	"Blockout",
	"Variant",
}

return table.freeze({
	AssetRootName = "__Assets__",
	ToolbarName = "Builder",
	ButtonId = "BuildingPluginToggle",
	ButtonTooltip = "Open the personal building tools panel.",
	ButtonIcon = "rbxassetid://4458901886",
	WidgetId = "BuildingPluginWidget",
	WidgetTitle = "Building Plugin",
	StatusDuration = 4,
	DefaultFolderPresets = DEFAULT_FOLDER_PRESETS,
	DefaultSectionState = {
		Library = true,
		Folders = true,
		Selection = true,
		Properties = true,
		Settings = false,
	},
	DefaultWidgetSize = DEFAULT_WIDGET_SIZE,
	MinWidgetSize = MIN_WIDGET_SIZE,
	MaxRecentAssets = MAX_RECENT_ASSETS,
	Theme = {
		Background = Color3.fromRGB(28, 30, 34),
		Panel = Color3.fromRGB(35, 38, 43),
		PanelAlt = Color3.fromRGB(43, 47, 54),
		Border = Color3.fromRGB(60, 65, 73),
		Text = Color3.fromRGB(235, 237, 240),
		MutedText = Color3.fromRGB(182, 187, 196),
		Accent = Color3.fromRGB(82, 168, 255),
		AccentAlt = Color3.fromRGB(69, 122, 199),
		Success = Color3.fromRGB(79, 191, 116),
		Warning = Color3.fromRGB(214, 173, 70),
		Danger = Color3.fromRGB(214, 93, 93),
		Input = Color3.fromRGB(24, 26, 30),
	},
})
