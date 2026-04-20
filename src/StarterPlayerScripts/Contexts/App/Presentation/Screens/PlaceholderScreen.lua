--!strict
--[=[
	@class PlaceholderScreen
	Placeholder screen template for features under development with coming-soon messaging.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useNavigationActions = require(script.Parent.Parent.Parent.Application.Hooks.useNavigationActions)
local useScreenTransition = require(script.Parent.Parent.Parent.Application.Hooks.useScreenTransition)
local PlaceholderScreenView = require(script.Parent.PlaceholderScreenView)

export type TPlaceholderScreenProps = {
	Title: string,
	Description: string?,
}

local function PlaceholderScreen(props: TPlaceholderScreenProps)
	local anim = useScreenTransition("Simple")
	local actions = useNavigationActions()

	return e(PlaceholderScreenView, {
		containerRef = anim.containerRef,
		title = props.Title,
		description = props.Description,
		onBack = actions.goBack,
	})
end

return PlaceholderScreen
