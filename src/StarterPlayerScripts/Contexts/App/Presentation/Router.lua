--!strict
--[=[
	@class Router
	Simple (non-animated) screen router that renders the current screen from `NavigationAtom`.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

local useNavigation = require(script.Parent.Parent.Application.Hooks.useNavigation)
local ScreenRegistry = require(script.Parent.Parent.Config.ScreenRegistry)

local function NotFoundScreen()
	return e("TextLabel", {
		Text = "Screen not found",
		Size = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 0, 0),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 24,
	})
end

local function Router()
	local navigation = useNavigation()
	local currentScreenName = navigation.CurrentScreen

	local ScreenComponent = ScreenRegistry[currentScreenName] or NotFoundScreen

	return e(ScreenComponent, {
		params = navigation.Params,
	})
end

return Router
