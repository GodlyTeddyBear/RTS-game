--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local IconButton = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.IconButton)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local useScreenTransition = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useScreenTransition)

local OverlayContext = require(script.Parent.Parent.Parent.Infrastructure.OverlayContext)
local WorkersScreenView = require(script.Parent.WorkersScreenView)
local useWorkersScreenController =
	require(script.Parent.Parent.Parent.Application.Hooks.useWorkersScreenController)

--[=[
	@class WorkersScreen
	Screen container for the Workers feature. Manages screen transition animation and overlay context.
	@client
]=]

--[=[
	Render the Workers screen with header, list, and footer.
	@within WorkersScreen
	@return React.Element -- Rendered screen container
]=]
local function WorkersScreen()
	local anim = useScreenTransition("Standard")
	local ctrl = useWorkersScreenController()

	return e(OverlayContext.Provider, { value = ctrl.overlayContainer }, {
		Screen = e(WorkersScreenView, {
			containerRef = anim.containerRef,
			workerCount = ctrl.workerCount,
			onGoBack = ctrl.onGoBack,
			workerList = ctrl.workerList,
			onAssignRole = ctrl.onAssignRole,
			onOptionsSelect = ctrl.onOptionsSelect,
			hireRef = ctrl.hireRef,
			hireHover = ctrl.hireHover,
			onHireWorker = ctrl.onHireWorker,
			setOverlayContainer = ctrl.setOverlayContainer,
		}),
	})
end

return WorkersScreen
