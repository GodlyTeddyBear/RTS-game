--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AdventurerEquipUiTokens = require(script.Parent.Parent.Parent.Config.AdventurerEquipUiTokens)

export type TEquipmentSlotTileProps = {
	Label: string,
	ItemName: string,
	BackendSlotType: string?,
	IsFuture: boolean,
	IsSelected: boolean,
	LayoutOrder: number?,
	OnSelect: () -> (),
	OnUnequip: (backendSlotType: string?) -> (),
}

local function EquipmentSlotTile(props: TEquipmentSlotTileProps)
	local buttonChildren = {
		UICorner = e("UICorner", {
			CornerRadius = AdventurerEquipUiTokens.SLOT_CORNER_RADIUS,
		}),
		UIGradient = e("UIGradient", {
			Color = GradientTokens.SLOT_GRADIENT,
			Rotation = -140.856,
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
				Thickness = if props.IsSelected then 4 else 3,
			}, {
				UIGradient = e("UIGradient", {
					Color = if props.IsSelected then GradientTokens.GOLD_STROKE else GradientTokens.SLOT_DECORE_STROKE,
					Rotation = -43.907,
				}),
			}),
			UICorner = e("UICorner", {
				CornerRadius = AdventurerEquipUiTokens.SLOT_DECORE_CORNER_RADIUS,
			}),
		}),
		Icon = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0.415),
			Size = UDim2.fromScale(0.68, 0.51),
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.SLOT_ICON_GRADIENT,
				Rotation = -140.856,
			}),
			UICorner = e("UICorner"),
			ItemName = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.9, 0.5),
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				Text = props.ItemName,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 15,
				TextWrapped = true,
			}),
		}),
		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.9, 5),
			Size = UDim2.new(0.9, 9, 0.12, 9),
			FontFace = Font.new("rbxasset://fonts/families/GothicA1.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			Text = props.Label,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = AdventurerEquipUiTokens.SLOT_FONT_SIZE,
			TextWrapped = true,
		}, {
			UIStroke = e("UIStroke", {
				Color = Color3.fromRGB(4, 4, 4),
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 4.5,
			}),
		}),
		FutureTag = if props.IsFuture
			then e("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.96, 0.08),
				Size = UDim2.fromScale(0.38, 0.16),
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				Text = "FUTURE",
				TextColor3 = Color3.fromRGB(255, 214, 84),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			else nil,
		UnequipButton = if (not props.IsFuture) and props.BackendSlotType ~= nil and props.ItemName ~= "Empty"
			then e("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.97, 0.05),
				Size = UDim2.fromScale(0.3, 0.16),
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				Text = "Unequip",
				TextColor3 = Color3.fromRGB(255, 122, 122),
				TextSize = 13,
				ZIndex = 3,
				[React.Event.Activated] = function()
					props.OnUnequip(props.BackendSlotType)
				end,
			})
			else nil,
	}

	return e("TextButton", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(0.90909, 0.20633),
		Text = "",
		TextSize = 1,
		AutoButtonColor = false,
		[React.Event.Activated] = props.OnSelect,
	}, buttonChildren)
end

return EquipmentSlotTile
