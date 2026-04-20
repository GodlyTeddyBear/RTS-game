--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)

local e = React.createElement

local PANEL_BORDER = Colors.NPC.PanelBorder
local BODY_COLOR = Colors.NPC.PanelText

--[=[
	@interface TDialogueBodyProps
	@within DialogueBody
	.DisplayedText string -- The currently revealed dialogue text (may be mid-typewrite)
	.ScrollLayoutRef { current: UIListLayout? } -- Ref for the scroll content layout, used to auto-size canvas
]=]
export type TDialogueBodyProps = {
	DisplayedText: string,
	ScrollLayoutRef: { current: UIListLayout? },
}

--[=[
	Scrollable dialogue text region. Receives the currently-revealed text from
	the animation controller and a layout ref for canvas auto-sizing.
	@within DialogueBody
	@param props TDialogueBodyProps
	@return ScrollingFrame
	@client
]=]
local function DialogueBody(props: TDialogueBodyProps)
	return e("ScrollingFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.225),
		Size = UDim2.fromScale(1, 0.45),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = PANEL_BORDER,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.fromScale(1, 0),
		ZIndex = 101,
	}, {
		Layout = e("UIListLayout", {
			ref = props.ScrollLayoutRef,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", {
			PaddingRight = UDim.new(0.05, 0),
		}),
		DialogueText = e(Text, {
			Text = props.DisplayedText,
			Variant = "body",
			TextColor3 = BODY_COLOR,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
	})
end

return DialogueBody
