--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local DialogueHeader = require(script.Parent.Parent.Molecules.DialogueHeader)
local DialogueBody = require(script.Parent.Parent.Molecules.DialogueBody)
local DialogueOptionList = require(script.Parent.Parent.Molecules.DialogueOptionList)

local e = React.createElement

local PANEL_BG = Colors.NPC.PanelBackground
local PANEL_BORDER = Colors.NPC.PanelBorder

--[=[
	@type TDialogueOption
	@within DialogueModalView
	.Id string -- Unique identifier for the option
	.Text string -- Display text shown to the player
]=]
export type TDialogueOption = {
	Id: string,
	Text: string,
}

--[=[
	@interface TDialogueModalViewProps
	@within DialogueModalView
	.PanelRef { current: Frame? } -- Ref to the root frame (for entrance animation)
	.ScrollLayoutRef { current: UIListLayout? } -- Ref for dialogue scroll canvas auto-sizing
	.OptionScaleRefs { current: { [string]: UIScale? } } -- Per-option UIScale refs for stagger animation
	.NPCName string -- Name of the speaking NPC
	.DisplayedText string -- Currently revealed dialogue text
	.Options { TDialogueOption } -- Available dialogue choices
	.OptionsCanvasHeight number -- Precomputed canvas height for the options scroll container
	.PanelPosition UDim2 -- Current panel position (driven by animation controller)
	.OnSelectOption (optionId: string) -> () -- Callback when player selects an option
	.OnClose () -> () -- Callback when player closes the dialogue
]=]
export type TDialogueModalViewProps = {
	PanelRef: { current: Frame? },
	ScrollLayoutRef: { current: UIListLayout? },
	OptionScaleRefs: { current: { [string]: UIScale? } },
	NPCName: string,
	DisplayedText: string,
	Options: { TDialogueOption },
	OptionsCanvasHeight: number,
	PanelPosition: UDim2,
	OnSelectOption: (optionId: string) -> (),
	OnClose: () -> (),
}

--[=[
	Pure view for the dialogue modal. No effects, no animation logic — renders
	only what it receives from props.
	@within DialogueModalView
	@param props TDialogueModalViewProps
	@return Frame
	@client
]=]
local function DialogueModalView(props: TDialogueModalViewProps)
	return e("Frame", {
		ref = props.PanelRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.PanelPosition,
		Size = UDim2.fromScale(0.62, 0.34),
		BackgroundColor3 = PANEL_BG,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 100,
		ClipsDescendants = true,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 10),
		}),
		Stroke = e("UIStroke", {
			Color = PANEL_BORDER,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),

		Header = e(DialogueHeader, {
			NPCName = props.NPCName,
			OnClose = props.OnClose,
		}),

		Divider = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.2),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = PANEL_BORDER,
			BorderSizePixel = 0,
			ZIndex = 101,
		}),

		Body = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.6),
			Size = UDim2.fromScale(1, 0.8),
			BackgroundTransparency = 1,
			ZIndex = 101,
		}, {
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0.05, 0),
				PaddingBottom = UDim.new(0.06, 0),
				PaddingLeft = UDim.new(0.03, 0),
				PaddingRight = UDim.new(0.03, 0),
			}),

			DialogueTextScroll = e(DialogueBody, {
				DisplayedText = props.DisplayedText,
				ScrollLayoutRef = props.ScrollLayoutRef,
			}),

			OptionsDivider = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = PANEL_BORDER,
				BorderSizePixel = 0,
				ZIndex = 101,
			}),

			OptionsContainer = e(DialogueOptionList, {
				Options = props.Options,
				OptionsCanvasHeight = props.OptionsCanvasHeight,
				OptionScaleRefs = props.OptionScaleRefs,
				OnSelectOption = props.OnSelectOption,
			}),
		}),
	})
end

return DialogueModalView
