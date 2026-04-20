--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AdventurerEquipUiTokens = require(script.Parent.Parent.Parent.Config.AdventurerEquipUiTokens)

export type TEquippableItemTileProps = {
	Name: string,
	StatsText: string,
	Quantity: number,
	LayoutOrder: number?,
	OnSelect: () -> (),
}

local function EquippableItemTile(props: TEquippableItemTileProps)
	return e("TextButton", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(0.94, 0.24),
		Text = "",
		TextSize = 1,
		AutoButtonColor = false,
		[React.Event.Activated] = props.OnSelect,
	}, {
		UIGradient = e("UIGradient", {
			Color = GradientTokens.SLOT_GRADIENT,
			Rotation = -140.856,
		}),
		UICorner = e("UICorner", {
			CornerRadius = AdventurerEquipUiTokens.ITEM_TILE_CORNER_RADIUS,
		}),
		Decore = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.9, 6, 0.9, 6),
		}, {
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = 3,
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.SLOT_DECORE_STROKE,
					Rotation = -43.907,
				}),
			}),
		}),
		Name = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.09),
			Size = UDim2.fromScale(0.88, 0.36),
			FontFace = Font.new("rbxasset://fonts/families/GothicA1.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			Text = props.Name .. " x" .. tostring(props.Quantity),
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = AdventurerEquipUiTokens.ITEM_TILE_FONT_SIZE,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			UIStroke = e("UIStroke", {
				Color = Color3.fromRGB(4, 4, 4),
				Thickness = 3,
			}),
		}),
		Stats = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.92),
			Size = UDim2.fromScale(0.88, 0.34),
			FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
			Text = if props.StatsText ~= "" then props.StatsText else "No bonus stats",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = AdventurerEquipUiTokens.ITEM_TILE_STATS_SIZE,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
		}),
	})
end

return EquippableItemTile
