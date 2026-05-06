--!strict

return table.freeze({
	AssetRootName = "__Assets__",
	ToolbarName = "Builder",
	ButtonId = "BuildingPluginToggle",
	ButtonTooltip = "Open the personal building tools panel.",
	ButtonIcon = "rbxassetid://4458901886",
	WidgetId = "BuildingPluginWidget",
	WidgetTitle = "Building Plugin",
	StatusDuration = 4,
	DefaultWidgetSize = Vector2.new(360, 620),
	MinWidgetSize = Vector2.new(320, 460),
	MaxRecentAssets = 8,
	MaxWaypoints = 50,
	MaxFolderPresetIncludeDepth = 8,
	DefaultFolderPresets = {
		"Props",
		"Decor",
		"Structure",
		"Blockout",
		"Variant",
	},
	DefaultFolderPresetGroupLabel = "Default",
})
