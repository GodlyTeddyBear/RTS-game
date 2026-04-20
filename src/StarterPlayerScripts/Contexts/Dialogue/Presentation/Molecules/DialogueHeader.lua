--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local Button = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Button)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local Typography = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)

local e = React.createElement

local PANEL_HEADER = Colors.NPC.PanelHeaderDark
local NPC_NAME_COLOR = Colors.NPC.ScoutGold

--[=[
	@interface TDialogueHeaderProps
	@within DialogueHeader
	.NPCName string -- Name of the speaking NPC
	.OnClose () -> () -- Callback when player closes the dialogue
]=]
export type TDialogueHeaderProps = {
	NPCName: string,
	OnClose: () -> (),
}

--[=[
	Header band showing the NPC name and a close button.
	@within DialogueHeader
	@param props TDialogueHeaderProps
	@return Frame
	@client
]=]
local function DialogueHeader(props: TDialogueHeaderProps)
	return e("Frame", {
		Size = UDim2.fromScale(1, 0.2),
		BackgroundColor3 = PANEL_HEADER,
		BorderSizePixel = 0,
		ZIndex = 101,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 10),
		}),
		-- Cover bottom corners so only top is rounded
		BottomCover = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.9),
			Size = UDim2.fromScale(1, 0.2),
			BackgroundColor3 = PANEL_HEADER,
			BorderSizePixel = 0,
			ZIndex = 101,
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0.03, 0),
			PaddingRight = UDim.new(0.03, 0),
		}),
		NPCName = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.39, 0.5),
			Size = UDim2.fromScale(0.78, 0.6),
			BackgroundTransparency = 1,
			Text = props.NPCName,
			TextColor3 = NPC_NAME_COLOR,
			Font = Typography.Font.Bold,
			TextSize = Typography.FontSize.Small,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 102,
		}),
		CloseButton = e(Button, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.955, 0.5),
			Size = UDim2.fromScale(0.06, 0.6),
			Text = "X",
			Variant = "ghost",
			ZIndex = 102,
			[React.Event.Activated] = props.OnClose,
		}),
	})
end

return DialogueHeader
