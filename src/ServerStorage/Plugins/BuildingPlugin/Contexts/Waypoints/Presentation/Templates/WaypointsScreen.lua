--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)

local useWaypointsState = require(script.Parent.Parent.Parent.Application.Hooks.useWaypointsState)
local useWaypointsActions = require(script.Parent.Parent.Parent.Application.Hooks.useWaypointsActions)
local WaypointsViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.WaypointsViewModel)
local useSettingsState = require(script.Parent.Parent.Parent.Parent.Settings.Application.Hooks.useSettingsState)
local useSettingsActions = require(script.Parent.Parent.Parent.Parent.Settings.Application.Hooks.useSettingsActions)
local WaypointPanel = require(script.Parent.Parent.Organisms.WaypointPanel)

local SECTION_ID = "waypoint_manager"
local WAYPOINTS_SECTION_IDS = { SECTION_ID }

local function isSectionExpanded(sectionExpansionById: { [string]: boolean }, sectionId: string): boolean
	local value = sectionExpansionById[sectionId]
	if value == nil then
		return true
	end

	return value
end

local function WaypointsScreen()
	local waypointsState = useWaypointsState()
	local waypointsActions = useWaypointsActions()
	local settingsState = useSettingsState()
	local settingsActions = useSettingsActions()

	React.useEffect(function()
		waypointsActions.RefreshWaypoints()
	end, {})

	local viewModel = React.useMemo(function()
		return WaypointsViewModel.FromState(waypointsState)
	end, { waypointsState })

	return React.createElement(StudioComponents.ScrollFrame, {
		Layout = {
			ClassName = "UIListLayout",
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 10),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
	}, {
		SectionControls = React.createElement("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 24),
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			ExpandAll = React.createElement(StudioComponents.Button, {
				LayoutOrder = 1,
				OnActivated = function()
					settingsActions.SetSectionsExpanded(WAYPOINTS_SECTION_IDS, true)
				end,
				Size = UDim2.new(0.5, -4, 0, 24),
				Text = "Expand All",
			}),
			CollapseAll = React.createElement(StudioComponents.Button, {
				LayoutOrder = 2,
				OnActivated = function()
					settingsActions.SetSectionsExpanded(WAYPOINTS_SECTION_IDS, false)
				end,
				Size = UDim2.new(0.5, -4, 0, 24),
				Text = "Collapse All",
			}),
		}),
		WaypointManager = React.createElement(WaypointPanel, {
			SectionId = SECTION_ID,
			IsExpanded = isSectionExpanded(settingsState.SectionExpansionById, SECTION_ID),
			OnExpandedChanged = settingsActions.SetSectionExpanded,
			WaypointNameInput = viewModel.WaypointNameInput,
			WaypointNames = viewModel.WaypointNames,
			SelectedWaypointName = viewModel.SelectedWaypointName,
			OnWaypointNameInputChanged = waypointsActions.SetWaypointNameInput,
			OnSelectedWaypointNameChanged = waypointsActions.SetSelectedWaypointName,
			OnSaveWaypoint = waypointsActions.SaveWaypoint,
			OnGoToWaypoint = waypointsActions.GoToSelectedWaypoint,
		}),
	})
end

return WaypointsScreen
