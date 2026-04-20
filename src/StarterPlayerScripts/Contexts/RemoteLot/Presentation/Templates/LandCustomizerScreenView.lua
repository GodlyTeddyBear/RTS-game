--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local Typography = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)
local RemoteLotAreaCard = require(script.Parent.Parent.Organisms.RemoteLotAreaCard)
local RemoteLotAreaViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.RemoteLotAreaViewModel)

local e = React.createElement

export type TLandCustomizerScreenViewProps = {
	ContainerRef: { current: Frame? },
	Rows: { RemoteLotAreaViewModel.TRemoteLotAreaRow },
	PendingAreaId: string?,
	ErrorMessage: string?,
	OnBack: () -> (),
	OnPurchaseArea: (areaId: string) -> (),
}

local function _BuildAreaCards(props: TLandCustomizerScreenViewProps): { [string]: any }
	local children = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
	}

	for _, row in props.Rows do
		children[row.AreaId] = e(RemoteLotAreaCard, {
			Row = row,
			IsPending = props.PendingAreaId == row.AreaId,
			OnPurchase = props.OnPurchaseArea,
		})
	end

	return children
end

local function LandCustomizerScreenView(props: TLandCustomizerScreenViewProps)
	return e("Frame", {
		ref = props.ContainerRef,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Header = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(1, 0.094),
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.BAR_GRADIENT,
			}),
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = 3,
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.GOLD_STROKE,
				}),
			}),
			BackButton = e("TextButton", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Font = Typography.Font.Bold,
				Position = UDim2.fromScale(0.02, 0.5),
				Size = UDim2.fromScale(0.1, 0.7),
				Text = "< Back",
				TextColor3 = Colors.Accent.Yellow,
				TextSize = Typography.FontSize.Body,
				[React.Event.Activated] = props.OnBack,
			}),
			Title = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Typography.Font.Bold,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.55, 0.7),
				Text = "Land Customizer",
				TextColor3 = Colors.Text.Primary,
				TextSize = Typography.FontSize.H3,
				TextWrapped = true,
			}),
		}),
		Content = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0.094),
			Size = UDim2.fromScale(1, 0.906),
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.LIST_CONTAINER_GRADIENT,
				Rotation = -16,
			}),
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = 3,
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.GOLD_STROKE,
				}),
			}),
			Intro = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Font = Typography.Font.Regular,
				Position = UDim2.fromScale(0.5, 0.025),
				Size = UDim2.fromScale(0.82, 0.08),
				Text = "Expand your remote lot with unlocked land sections.",
				TextColor3 = Colors.Text.Secondary,
				TextSize = Typography.FontSize.Body,
				TextWrapped = true,
			}),
			Error = if props.ErrorMessage
				then e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Font = Typography.Font.Bold,
					Position = UDim2.fromScale(0.5, 0.105),
					Size = UDim2.fromScale(0.82, 0.05),
					Text = props.ErrorMessage,
					TextColor3 = Color3.fromRGB(255, 120, 120),
					TextSize = Typography.FontSize.Small,
					TextWrapped = true,
				})
				else nil,
			AreaList = e("ScrollingFrame", {
				AnchorPoint = Vector2.new(0.5, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(),
				Position = UDim2.fromScale(0.5, 0.17),
				Size = UDim2.fromScale(0.82, 0.78),
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Colors.Accent.Yellow,
			}, _BuildAreaCards(props)),
		}),
	})
end

return LandCustomizerScreenView
