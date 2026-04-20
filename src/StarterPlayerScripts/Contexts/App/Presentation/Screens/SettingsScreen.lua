--!strict
--[=[
	@class SettingsScreen
	Settings screen template with placeholder controls.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local PlaceholderScreen = require(script.Parent.PlaceholderScreen)

local function SettingsScreen()
	return e(PlaceholderScreen, {
		Title = "⚙ Settings",
		Description = "Coming soon! Adjust game settings and preferences.",
	})
end

return SettingsScreen
