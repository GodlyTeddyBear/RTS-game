--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)

export type TGuildSlotCellProps = {
	Name: string,
	CostDisplay: string?,
	IsSelected: boolean?,
	OnSelect: () -> (),
	LayoutOrder: number?,
}

local GRADIENT_ROTATION = -141

local function GuildSlotCell(props: TGuildSlotCellProps)
	local isSelected = props.IsSelected or false
	local decoreStroke = if isSelected then GradientTokens.GOLD_STROKE_SUBTLE else GradientTokens.SLOT_DECORE_STROKE

	local buttonRef = useRef(nil :: TextButton?)
	local hover = useHoverSpring(buttonRef, AnimationTokens.Interaction.SlotCell)

	-- Extract first 2 characters of name for icon display (e.g. "Knight" → "KN")
	local nameAbbr = string.sub(props.Name, 1, 2):upper()

	return e("TextButton", {
		ref = buttonRef,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 1,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = hover.onMouseEnter,
		[React.Event.MouseLeave] = hover.onMouseLeave,
		[React.Event.Activated] = hover.onActivated(function()
			props.OnSelect()
		end),
	}, {
		UIGradient = e("UIGradient", {
			Color = GradientTokens.SLOT_GRADIENT,
			Rotation = GRADIENT_ROTATION,
		}),

		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 9),
		}),

		Decore = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.9, 6, 0.9, 6),
		}, {
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = if isSelected then 4 else 3,
			}, {
				UIGradient = e("UIGradient", {
					Color = decoreStroke,
					Rotation = -44,
				}),
			}),

			UICorner = e("UICorner", {
				CornerRadius = UDim.new(),
			}),
		}),

		-- Adventurer name at bottom
		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothicA1.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Interactable = false,
			Position = UDim2.new(0.5, 0, 0.9, 5),
			Size = UDim2.new(0.9, 9, 0.12, 9),
			Text = props.Name,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 22,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, {
			UIStroke = e("UIStroke", {
				Color = Color3.fromRGB(4, 4, 4),
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 4.5,
			}),
		}),

		-- Icon area (portrait placeholder)
		Icon = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0.415),
			Size = UDim2.fromScale(0.68, 0.51),
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.SLOT_ICON_GRADIENT,
				Rotation = GRADIENT_ROTATION,
			}),

			UICorner = e("UICorner"),

			IconText = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = nameAbbr,
				TextColor3 = Color3.fromRGB(150, 150, 150),
				TextScaled = true,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothicA1.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
			}),
		}),

		-- Cost badge top-right (only shown for hire tab)
		Amount = if props.CostDisplay
			then e("TextLabel", {
				ZIndex = 2,
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothicA1.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Interactable = false,
				Position = UDim2.new(0.95333, 3, 0.04667, -3),
				Size = UDim2.new(0.29333, 6, 0.14667, 6),
				Text = props.CostDisplay,
				TextColor3 = Color3.fromRGB(255, 204, 0),
				TextSize = 21,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Right,
			}, {
				UIStroke = e("UIStroke", {
					Color = Color3.fromRGB(4, 4, 4),
					LineJoinMode = Enum.LineJoinMode.Miter,
					Thickness = 3,
				}),
			})
			else nil,
	})
end

return GuildSlotCell
