--!strict
--[=[
	@class ScreenRegistry
	Map of screen names to screen component modules, used by the router to render screens by name.
	@client
]=]

local HomeScreen = require(script.Parent.Parent.Presentation.Screens.HomeScreen)
local GameView = require(script.Parent.Parent.Presentation.Screens.GameView)
local SettingsScreen = require(script.Parent.Parent.Presentation.Screens.SettingsScreen)
local StatisticsScreen = require(script.Parent.Parent.Presentation.Screens.StatisticsScreen)
local RunPresentation = require(script.Parent.Parent.Parent.Run.Presentation)

return table.freeze({
	Home = HomeScreen,
	Game = GameView,
	Settings = SettingsScreen,
	Statistics = StatisticsScreen,
	Results = RunPresentation.ResultsScreen,
})
