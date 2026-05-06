--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)

local useWeldingActions = require(script.Parent.Parent.Parent.Application.Hooks.useWeldingActions)
local useSettingsState = require(script.Parent.Parent.Parent.Parent.Settings.Application.Hooks.useSettingsState)
local useSettingsActions = require(script.Parent.Parent.Parent.Parent.Settings.Application.Hooks.useSettingsActions)
local WeldingActionsPanel = require(script.Parent.Parent.Organisms.WeldingActionsPanel)

local SECTION_ID = "welding_actions"
local WELDING_SECTION_IDS = { SECTION_ID }

local function isSectionExpanded(sectionExpansionById: { [string]: boolean }, sectionId: string): boolean
	local value = sectionExpansionById[sectionId]
	if value == nil then
		return true
	end

	return value
end

local function WeldingScreen()
	local weldingActions = useWeldingActions()
	local settingsState = useSettingsState()
	local settingsActions = useSettingsActions()

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
					settingsActions.SetSectionsExpanded(WELDING_SECTION_IDS, true)
				end,
				Size = UDim2.new(0.5, -4, 0, 24),
				Text = "Expand All",
			}),
			CollapseAll = React.createElement(StudioComponents.Button, {
				LayoutOrder = 2,
				OnActivated = function()
					settingsActions.SetSectionsExpanded(WELDING_SECTION_IDS, false)
				end,
				Size = UDim2.new(0.5, -4, 0, 24),
				Text = "Collapse All",
			}),
		}),
		WeldingActions = React.createElement(WeldingActionsPanel, {
			SectionId = SECTION_ID,
			IsExpanded = isSectionExpanded(settingsState.SectionExpansionById, SECTION_ID),
			OnExpandedChanged = settingsActions.SetSectionExpanded,
			OnCreateSingleWeld = weldingActions.CreateSingleWeld,
			OnCreateMassWeld = weldingActions.CreateMassWeld,
		}),
	})
end

return WeldingScreen
