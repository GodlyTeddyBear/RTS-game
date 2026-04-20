--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useNavigationActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)
local useScreenTransition = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useScreenTransition)
local useLandCustomizerController = require(script.Parent.Parent.Parent.Application.Hooks.useLandCustomizerController)
local LandCustomizerScreenView = require(script.Parent.LandCustomizerScreenView)

local e = React.createElement

local function LandCustomizerScreen()
	local anim = useScreenTransition("Standard")
	local navActions = useNavigationActions()
	local controller = useLandCustomizerController()

	return e(LandCustomizerScreenView, {
		ContainerRef = anim.containerRef,
		Rows = controller.Rows,
		PendingAreaId = controller.PendingAreaId,
		ErrorMessage = controller.ErrorMessage,
		OnBack = navActions.goBack,
		OnPurchaseArea = controller.OnPurchaseArea,
	})
end

return LandCustomizerScreen
