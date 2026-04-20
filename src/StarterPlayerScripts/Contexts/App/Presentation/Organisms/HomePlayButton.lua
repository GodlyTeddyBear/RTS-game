--!strict
--[=[
	@class HomePlayButton
	Organism rendering the large animated play button on the Home screen with shimmer and pulse effects.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useHomePlayButtonController = require(script.Parent.Parent.Parent.Application.Hooks.useHomePlayButtonController)
local HomePlayButtonView = require(script.Parent.HomePlayButtonView)

export type THomePlayButtonProps = {
	isPlaying: boolean,
	onPlayStart: () -> (),
	onPlayHover: () -> (),
	onPlayComplete: () -> (),
}

local function HomePlayButton(props: THomePlayButtonProps)
	local controller = useHomePlayButtonController(
		props.isPlaying,
		props.onPlayStart,
		props.onPlayHover,
		props.onPlayComplete
	)

	return e(HomePlayButtonView, {
		isPlaying = props.isPlaying,
		buttonRef = controller.buttonRef,
		shimmerRef = controller.shimmerRef,
		onActivated = controller.onActivated,
		onMouseEnter = controller.onMouseEnter,
		onMouseLeave = controller.onMouseLeave,
	})
end

return HomePlayButton
