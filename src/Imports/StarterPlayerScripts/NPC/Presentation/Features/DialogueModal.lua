--!strict

--[[
	DialogueModal - React component for NPC dialogue UI

	Renders a bottom-of-screen dialogue panel with:
	- NPC name header
	- NPC dialogue text (or displayText response after option selection)
	- Player response options as clickable buttons

	Subscribes to DialogueState atom for reactive updates.
	Calls NPCController to handle option selection.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local Knit = require(ReplicatedStorage.Packages.Knit)

local DialogueState = require(script.Parent.Parent.State.DialogueState)
local Theme = require(script.Parent.Parent.Parent.Parent.UI.Presentation.Theme.Theme)
local Text = require(script.Parent.Parent.Parent.Parent.UI.Presentation.Components.Atoms.Text)
local Divider = require(script.Parent.Parent.Parent.Parent.UI.Presentation.Components.Atoms.Divider)
local Button = require(script.Parent.Parent.Parent.Parent.UI.Presentation.Components.Atoms.Button)
local Panel = require(script.Parent.Parent.Parent.Parent.UI.Presentation.Components.Atoms.Panel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

local function DialogueModal()
	local state = useAtom(DialogueState.dialogueAtom)

	if not state.Active then
		return nil
	end

	-- Build option buttons table
	local optionsChildren: { [string]: any } = {
		OptionsLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for _, option in ipairs(state.Options) do
		optionsChildren["Option_" .. option.Index] = e(Button, {
			text = option.Text,
			variant = "Secondary",
			size = UDim2.new(1, 0, 0, 40),
			layoutOrder = option.Index,
			textXAlignment = Enum.TextXAlignment.Left,
			backgroundColor = Theme.Colors.Surface,
			backgroundTransparency = 0.2,
			onClick = function()
				local npcController = Knit.GetController("NPCController")
				if npcController then
					npcController:SelectDialogueOption(option.Index)
				end
			end,
		})
	end

	local displayedText = state.DisplayText or state.NPCText

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		DialoguePanel = e(Panel, {
			size = UDim2.new(0.7, 0, 0, 0),
			automaticSize = Enum.AutomaticSize.Y,
			position = UDim2.fromScale(0.5, 0.92),
			anchorPoint = Vector2.new(0.5, 1),
			backgroundColor = Theme.Colors.Background,
			backgroundTransparency = 0.1,
			cornerRadius = UDim.new(0, 12),
			padding = UDim.new(0, 20),
			strokeColor = Theme.Colors.HUD.BorderAccent,
			strokeThickness = 2,
			children = {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					Padding = UDim.new(0, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				NPCName = e(Text, {
					text = state.NPCName,
					variant = "Subheading",
					color = Theme.Colors.HUD.GoldAccent,
					textXAlignment = Enum.TextXAlignment.Left,
					layoutOrder = 1,
				}),

				Separator = e(Divider, {
					color = Theme.Colors.HUD.BorderAccent,
					transparency = 0.5,
					layoutOrder = 2,
				}),

				DialogueText = e(Text, {
					text = displayedText,
					variant = "Body",
					textXAlignment = Enum.TextXAlignment.Left,
					layoutOrder = 3,
				}),

				OptionsContainer = e("Frame", {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 4,
				}, optionsChildren),
			},
		}),
	})
end

return DialogueModal
