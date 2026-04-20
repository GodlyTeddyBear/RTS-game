--!strict
--[=[
	@class StatisticsScreen
	Placeholder screen for the statistics feature.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local PlaceholderScreen = require(script.Parent.PlaceholderScreen)

local function StatisticsScreen()
	return e(PlaceholderScreen, {
		Title = "📊 Statistics",
		Description = "Coming soon! View your progress and achievements.",
	})
end

return StatisticsScreen
