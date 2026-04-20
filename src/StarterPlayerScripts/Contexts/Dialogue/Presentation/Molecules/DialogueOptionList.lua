--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local Button = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Button)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)

local e = React.createElement

local PANEL_BORDER = Colors.NPC.PanelBorder
local OPTION_ROW_HEIGHT = 0.2
local OPTION_ROW_PADDING = 0.03

--[=[
	@type TDialogueOption
	@within DialogueOptionList
	.Id string -- Unique identifier for the option
	.Text string -- Display text shown to the player
]=]
export type TDialogueOption = {
	Id: string,
	Text: string,
}

--[=[
	@interface TDialogueOptionListProps
	@within DialogueOptionList
	.Options { TDialogueOption } -- Available dialogue choices
	.OptionsCanvasHeight number -- Precomputed canvas height (scale) for the scroll container
	.OptionScaleRefs { current: { [string]: UIScale? } } -- Ref table for per-option UIScale instances
	.OnSelectOption (optionId: string) -> () -- Callback when player selects an option
]=]
export type TDialogueOptionListProps = {
	Options: { TDialogueOption },
	OptionsCanvasHeight: number,
	OptionScaleRefs: { current: { [string]: UIScale? } },
	OnSelectOption: (optionId: string) -> (),
}

--[=[
	Scrollable list of selectable dialogue options with per-option UIScale refs
	used by the animation controller for staggered entrance animation.
	@within DialogueOptionList
	@param props TDialogueOptionListProps
	@return ScrollingFrame
	@client
]=]
local function DialogueOptionList(props: TDialogueOptionListProps)
	local optionButtons: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(OPTION_ROW_PADDING, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(OPTION_ROW_PADDING, 0),
			PaddingBottom = UDim.new(OPTION_ROW_PADDING, 0),
		}),
	}

	for index, option in ipairs(props.Options) do
		optionButtons["OptionRow_" .. option.Id] = e("Frame", {
			Size = UDim2.fromScale(1, OPTION_ROW_HEIGHT),
			BackgroundTransparency = 1,
			LayoutOrder = index,
		}, {
			Scale = e("UIScale", {
				ref = function(instance: UIScale?)
					props.OptionScaleRefs.current[option.Id] = instance
				end,
				Scale = 1,
			}),
			Button = e(Button, {
				Text = option.Text,
				Size = UDim2.fromScale(1, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Variant = "secondary",
				[React.Event.Activated] = function()
					props.OnSelectOption(option.Id)
				end,
			}),
		})
	end

	return e("ScrollingFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.75),
		Size = UDim2.fromScale(1, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = PANEL_BORDER,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.fromScale(1, props.OptionsCanvasHeight),
		ZIndex = 101,
	}, optionButtons)
end

return DialogueOptionList
