--!strict
--[=[
	@class HomeScreen
	Screen template displaying the home menu with animated play button and logo.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useHomeScreenController = require(script.Parent.Parent.Parent.Application.Hooks.useHomeScreenController)
local HomeScreenView = require(script.Parent.HomeScreenView)

local function HomeScreen()
	local controller = useHomeScreenController()

	return e(HomeScreenView, {
		containerRef = controller.containerRef,
		isPlaying = controller.isPlaying,
		onPlayStart = controller.onPlayStart,
		onPlayHover = controller.onPlayHover,
		onPlayComplete = controller.onPlayComplete,
	})
end

return HomeScreen
