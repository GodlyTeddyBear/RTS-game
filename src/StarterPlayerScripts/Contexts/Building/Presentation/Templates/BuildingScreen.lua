--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useEffect = React.useEffect

local useScreenTransition = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useScreenTransition)
local useNavigationActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)
local useBuildingScreenController = require(script.Parent.Parent.Parent.Application.Hooks.useBuildingScreenController)
local useBuildingSounds = require(script.Parent.Parent.Parent.Application.Hooks.Sounds.useBuildingSounds)

local BuildingScreenView = require(script.Parent.BuildingScreenView)

--[=[
	@class BuildingScreen
	Thin template — wires screen transition, navigation, and building controller into BuildingScreenView.
	@client
]=]
local function BuildingScreen()
	local anim = useScreenTransition("Standard")
	local navActions = useNavigationActions()
	local controller = useBuildingScreenController()
	local sounds = useBuildingSounds()

	useEffect(function()
		sounds.onMenuOpen()
	end, {})

	return e(BuildingScreenView, {
		containerRef = anim.containerRef,
		onBack = function()
			sounds.onBack()
			navActions.goBack()
		end,
		selectedZone = controller.selectedZone,
		onSelectZone = controller.onSelectZone,
		playerBuildings = controller.buildings,
		selectedSlot = controller.selectedSlot,
		onSelectSlot = controller.onSelectSlot,
		rightPanel = controller.rightPanel,
	})
end

return BuildingScreen
