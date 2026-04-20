--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local Typography = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)
local RemoteLotAreaViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.RemoteLotAreaViewModel)

local e = React.createElement

export type TRemoteLotAreaCardProps = {
	Row: RemoteLotAreaViewModel.TRemoteLotAreaRow,
	IsPending: boolean,
	OnPurchase: (areaId: string) -> (),
}

local function RemoteLotAreaCard(props: TRemoteLotAreaCardProps)
	local row = props.Row
	local disabled = row.IsUnlocked or props.IsPending
	local buttonColor = if row.IsUnlocked
		then Color3.fromRGB(50, 90, 60)
		elseif row.CanAfford
			then Colors.Accent.Yellow
			else Color3.fromRGB(95, 95, 95)

	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(28, 30, 32),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		UIStroke = e("UIStroke", {
			Color = if row.IsUnlocked then Color3.fromRGB(85, 170, 95) else Color3.fromRGB(140, 120, 70),
			Thickness = 2,
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
		}),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		Title = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Typography.Font.Bold,
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = row.DisplayName .. " - " .. row.StatusText,
			TextColor3 = Colors.Text.Primary,
			TextSize = Typography.FontSize.H3,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Description = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Typography.Font.Regular,
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = row.Description,
			TextColor3 = Colors.Text.Secondary,
			TextSize = Typography.FontSize.Body,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Requirements = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Typography.Font.Regular,
			LayoutOrder = 3,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = row.RequirementText,
			TextColor3 = Colors.Text.Muted,
			TextSize = Typography.FontSize.Small,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		PurchaseButton = e("TextButton", {
			Active = not disabled,
			AutoButtonColor = not disabled,
			BackgroundColor3 = buttonColor,
			Font = Typography.Font.Bold,
			LayoutOrder = 4,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = if props.IsPending then "Unlocking..." else row.ButtonText,
			TextColor3 = if row.CanAfford or row.IsUnlocked then Color3.fromRGB(20, 20, 20) else Colors.Text.Primary,
			TextSize = Typography.FontSize.Body,
			TextWrapped = true,
			[React.Event.Activated] = function()
				if not disabled then
					props.OnPurchase(row.AreaId)
				end
			end,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
			}),
		}),
	})
end

return RemoteLotAreaCard
