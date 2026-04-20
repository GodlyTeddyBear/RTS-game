--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local Button = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Button)
local VillagerOfferViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.VillagerOfferViewModel)

local e = React.createElement

export type TVillagerOfferPanelProps = {
	ViewModel: VillagerOfferViewModel.TVillagerOfferVM,
	OnAccept: () -> (),
	OnDecline: () -> (),
	OnClose: () -> (),
}

local function _TextLabel(text: string, size: UDim2, position: UDim2, textSize: number, order: number?)
	return e("TextLabel", {
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Position = position,
		Size = size,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextColor3 = Color3.fromRGB(245, 241, 232),
		TextSize = textSize,
		TextWrapped = true,
	})
end

local function VillagerOfferPanel(props: TVillagerOfferPanelProps)
	local vm = props.ViewModel

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(36, 35, 40),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.36, 0.46),
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		UIStroke = e("UIStroke", {
			Color = Color3.fromRGB(220, 183, 91),
			Thickness = 2,
		}),

		Header = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0.18),
		}, {
			Name = _TextLabel(vm.VillagerName, UDim2.fromScale(0.78, 1), UDim2.fromScale(0.06, 0), 24),
			Close = e(Button, {
				Text = "X",
				Variant = "ghost",
				Size = UDim2.fromOffset(36, 32),
				Position = UDim2.fromScale(0.94, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				[React.Event.Activated] = props.OnClose,
			}),
		}),

		ItemIcon = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(22, 22, 26),
			Image = vm.ItemIcon,
			Position = UDim2.fromScale(0.5, 0.31),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.2, 0.2),
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			UIStroke = e("UIStroke", {
				Color = Color3.fromRGB(89, 88, 96),
				Thickness = 1,
			}),
		}),

		Quantity = _TextLabel(vm.QuantityLabel, UDim2.fromScale(0.84, 0.1), UDim2.fromScale(0.08, 0.44), 22),
		Tier = _TextLabel(vm.TierLabel, UDim2.fromScale(0.84, 0.08), UDim2.fromScale(0.08, 0.53), 18),

		Rewards = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.08, 0.64),
			Size = UDim2.fromScale(0.84, 0.1),
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Gold = _TextLabel(vm.GoldReward, UDim2.fromScale(0.45, 1), UDim2.fromScale(0, 0), 18, 1),
			Tokens = _TextLabel(vm.TokenReward, UDim2.fromScale(0.45, 1), UDim2.fromScale(0, 0), 18, 2),
		}),

		Buttons = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.08, 0.8),
			Size = UDim2.fromScale(0.84, 0.12),
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Accept = e(Button, {
				Text = if vm.CanAccept then "Accept" else "Full",
				Variant = if vm.CanAccept then "primary" else "secondary",
				Size = UDim2.fromScale(0.42, 1),
				LayoutOrder = 1,
				[React.Event.Activated] = if vm.CanAccept then props.OnAccept else nil,
			}),
			Decline = e(Button, {
				Text = "Decline",
				Variant = "danger",
				Size = UDim2.fromScale(0.42, 1),
				LayoutOrder = 2,
				[React.Event.Activated] = props.OnDecline,
			}),
		}),
	})
end

return VillagerOfferPanel
