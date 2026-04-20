--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)

--[=[
	@interface TQuestEntryRowProps
	Props for a single quest zone entry row.
	@within QuestEntryRow
	.ZoneId string -- Unique identifier for the zone
	.DisplayName string -- Human-readable zone name
	.TierLabel string -- Difficulty tier label (e.g. "Apprentice")
	.RecommendedATKLabel string -- Formatted recommended ATK stat
	.RecommendedDEFLabel string -- Formatted recommended DEF stat
	.WaveCountLabel string -- Formatted wave count (e.g. "3 Waves")
	.Description string -- Zone description text
	.IsExpeditionActive boolean -- Whether an expedition is in progress (disables button)
	.IsLocked boolean -- Whether the zone is currently locked for the player
	.LayoutOrder number? -- Optional layout order for list positioning
	.OnAccept (zoneId: string) -> () -- Called when "Send Party" button is clicked
]=]
export type TQuestEntryRowProps = {
	ZoneId: string,
	DisplayName: string,
	TierLabel: string,
	RecommendedATKLabel: string,
	RecommendedDEFLabel: string,
	WaveCountLabel: string,
	Description: string,
	IsExpeditionActive: boolean,
	IsLocked: boolean,
	LayoutOrder: number?,
	OnAccept: (zoneId: string) -> (),
}

local GREY_TEXT = Color3.fromRGB(135, 135, 135)

--[=[
	@class QuestEntryRow
	Row component displaying a single quest zone with stats and send party button.
	Button is disabled if an expedition is currently active.
	@client
]=]
local function QuestEntryRow(props: TQuestEntryRowProps)
	local acceptBtnRef = useRef(nil :: TextButton?)
	local acceptHover = useHoverSpring(acceptBtnRef, AnimationTokens.Interaction.ActionButton)
	local isDisabled = props.IsExpeditionActive or props.IsLocked

	return e(Frame, {
		Size = UDim2.new(1, 0, 0, 65),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Gradient = GradientTokens.TAB_INACTIVE_GRADIENT,
		GradientRotation = -2,
		StrokeColor = GradientTokens.QUEST_ROW_STROKE,
		StrokeThickness = 1,
		StrokeMode = Enum.ApplyStrokeMode.Border,
		LayoutOrder = props.LayoutOrder,
		ClipsDescendants = true,
		children = {
			-- Zone name + tier label (left section)
			TypeInfo = e("Frame", {
				Active = true,
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.04691, 0.5),
				Size = UDim2.fromScale(0.1258, 0.72857),
			}, {
				Name = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/GothicA1.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.new(0.47458, 0, 0, -2),
					Size = UDim2.new(0.94915, 4, 0.4902, 4),
					Text = props.DisplayName,
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 25,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}, {
					UIStroke = e("UIStroke", {
						Color = Color3.fromRGB(4, 4, 4),
						LineJoinMode = Enum.LineJoinMode.Miter,
						Thickness = 2,
					}),
				}),

				Level = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
					LayoutOrder = 1,
					Position = UDim2.fromScale(0.4435, 1),
					Size = UDim2.fromScale(0.88701, 0.43137),
					Text = props.TierLabel,
					TextColor3 = GREY_TEXT,
					TextSize = 21,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),

			-- Stats section (center)
			Info = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Position = UDim2.fromScale(0.50036, 0.5),
				Size = UDim2.fromScale(0.15778, 0.72857),
			}, {
				Atk = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
					Position = UDim2.fromScale(0.25, 0),
					Size = UDim2.fromScale(0.5, 0.43137),
					Text = props.RecommendedATKLabel,
					TextColor3 = GREY_TEXT,
					TextSize = 21,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				Def = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
					LayoutOrder = 1,
					Position = UDim2.fromScale(0.25, 1),
					Size = UDim2.fromScale(0.5, 0.43137),
					Text = props.RecommendedDEFLabel,
					TextColor3 = GREY_TEXT,
					TextSize = 21,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				Wave = e("TextLabel", {
					AnchorPoint = Vector2.new(1, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
					LayoutOrder = 2,
					Position = UDim2.fromScale(1, -0.03922),
					Size = UDim2.fromScale(0.5, 0.43137),
					Text = props.WaveCountLabel,
					TextColor3 = GREY_TEXT,
					TextSize = 21,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),

			-- Description (clipped TextLabel, no nested scroll)
			Description = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				LayoutOrder = 2,
				Position = UDim2.fromScale(0.29709, 0.5),
				Size = UDim2.fromScale(0.15778, 0.72857),
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
				Text = props.Description,
				TextColor3 = GREY_TEXT,
				TextSize = 14,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),

			-- Send Party button (right section)
			AcceptButton = e("TextButton", {
				ref = acceptBtnRef,
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				LayoutOrder = 3,
				Position = UDim2.fromScale(0.83937, 0.5),
				Size = UDim2.fromScale(0.13788, 0.72857),
				Text = "",
				TextSize = 1,
				AutoButtonColor = not isDisabled,
				[React.Event.MouseEnter] = acceptHover.onMouseEnter,
				[React.Event.MouseLeave] = acceptHover.onMouseLeave,
				[React.Event.Activated] = acceptHover.onActivated(function()
					if not isDisabled then
						props.OnAccept(props.ZoneId)
					end
				end),
			}, {
				UIGradient = e("UIGradient", {
					Color = if isDisabled
						then GradientTokens.SLOT_GRADIENT
						else GradientTokens.ASSIGN_BUTTON_GRADIENT,
					Rotation = -4,
				}),

				UICorner = e("UICorner"),

				Decore = e(Frame, {
					Size = UDim2.new(0.94845, 0, 0.82353, 0),
					Position = UDim2.fromScale(0.5, 0.4902),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					CornerRadius = UDim.new(0, 4),
					StrokeColor = if isDisabled
						then GradientTokens.SLOT_DECORE_STROKE
						else GradientTokens.ASSIGN_BUTTON_STROKE,
					StrokeThickness = 2,
					StrokeMode = Enum.ApplyStrokeMode.Border,
					StrokeBorderPosition = Enum.BorderStrokePosition.Inner,
					ClipsDescendants = true,
				}),

				Label = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/GothicA1.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Interactable = false,
					LayoutOrder = 1,
					Position = UDim2.fromScale(0.5, 0.4902),
					Size = UDim2.new(0.94845, 4, 0.58824, 4),
					Text = if props.IsLocked then "Locked" elseif props.IsExpeditionActive then "Busy" else "Send Party",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 25,
					TextWrapped = true,
				}, {
					UIStroke = e("UIStroke", {
						Color = if isDisabled
							then Color3.fromRGB(30, 30, 30)
							else Color3.fromRGB(96, 2, 4),
						LineJoinMode = Enum.LineJoinMode.Miter,
						Thickness = 2,
					}),
				}),
			}),
		},
	})
end

return QuestEntryRow
