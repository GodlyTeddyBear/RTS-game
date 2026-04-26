--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useScreenTransition = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useScreenTransition)
local useResultsScreenController = require(script.Parent.Parent.Parent.Application.Hooks.useResultsScreenController)
local ResultsScreenView = require(script.Parent.ResultsScreenView)

local function ResultsScreen()
	local anim = useScreenTransition("Simple")
	local controller = useResultsScreenController()

	return e(ResultsScreenView, {
		containerRef = anim.containerRef,
		waveNumber = controller.waveNumber,
		score = controller.score,
		isRestarting = controller.isRestarting,
		playAgainText = controller.playAgainText,
		onPlayAgain = controller.onPlayAgain,
	})
end

return ResultsScreen
