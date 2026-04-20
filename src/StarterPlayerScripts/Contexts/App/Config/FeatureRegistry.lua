--!strict
--[=[
	@class FeatureRegistry
	Table of feature metadata including availability status and corresponding screen names.
	@client
]=]

--[=[
	@interface TFeature
	@within FeatureRegistry
	.Id string -- Unique feature identifier.
	.Name string -- Display name shown in the UI.
	.Icon string -- Unicode emoji representing the feature.
	.Status "available" | "coming-soon" -- Feature availability status.
	.ScreenName string -- Name of the screen to navigate to when selected.
]=]
export type TFeature = {
	Id: string,
	Name: string,
	Icon: string,
	Status: "available" | "coming-soon",
	ScreenName: string,
}

return table.freeze({
	{
		Id = "Workers",
		Name = "Workers",
		Icon = "👷",
		Status = "available",
		ScreenName = "Workers",
	},
	{
		Id = "Production",
		Name = "Production",
		Icon = "⚙️",
		Status = "coming-soon",
		ScreenName = "Production",
	},
	{
		Id = "Research",
		Name = "Research",
		Icon = "🔬",
		Status = "coming-soon",
		ScreenName = "Research",
	},
	{
		Id = "Automation",
		Name = "Automation",
		Icon = "🤖",
		Status = "coming-soon",
		ScreenName = "Automation",
	},
	{
		Id = "Prestige",
		Name = "Prestige",
		Icon = "✨",
		Status = "coming-soon",
		ScreenName = "Prestige",
	},
	{
		Id = "Forge",
		Name = "Forge",
		Icon = "🔨",
		Status = "available",
		ScreenName = "Forge",
	},
	{
		Id = "Brewery",
		Name = "Brewery",
		Icon = "🧪",
		Status = "available",
		ScreenName = "Brewery",
	},
	{
		Id = "Workshop",
		Name = "Workshop",
		Icon = "🔧",
		Status = "coming-soon",
		ScreenName = "Workshop",
	},
	{
		Id = "Buildings",
		Name = "Buildings",
		Icon = "🏗️",
		Status = "available",
		ScreenName = "Buildings",
	},
	{
		Id = "Market",
		Name = "Shop",
		Icon = "🏪",
		Status = "available",
		ScreenName = "Shop",
	},
	{
		Id = "LandCustomizer",
		Name = "Land Customizer",
		Icon = "L",
		Status = "available",
		ScreenName = "LandCustomizer",
	},
	{
		Id = "Guild",
		Name = "Guild",
		Icon = "🗡️",
		Status = "available",
		ScreenName = "Guild",
	},
	{
		Id = "Tasks",
		Name = "Tasks",
		Icon = "T",
		Status = "available",
		ScreenName = "Tasks",
	},
} :: { TFeature })
