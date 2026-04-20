--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useState = React.useState
local useRef = React.useRef

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local Typography = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)
local useSoundActions = require(script.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)

local BuildingPickerViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.BuildingPickerViewModel)

--[=[
	@type TBuildingPickerPanelProps
	@within BuildingPickerPanel
	.SlotIndex number -- Slot index (for display in title)
	.ViewData BuildingPickerViewModel.TBuildingPickerViewData -- Pre-built option data
	.IsLoading boolean? -- Whether construction is in progress
	.ErrorMessage string? -- Error message to display (or nil)
	.OnConfirm (buildingType: string) -> () -- Build button callback
	.OnCancel () -> () -- Cancel button callback
]=]
export type TBuildingPickerPanelProps = {
	SlotIndex: number,
	ViewData: BuildingPickerViewModel.TBuildingPickerViewData,
	IsLoading: boolean?,
	ErrorMessage: string?,
	OnConfirm: (buildingType: string) -> (),
	OnCancel: () -> (),
}

--[=[
	@class BuildingPickerPanel
	Displays available buildings to construct. Receives pre-computed affordability via ViewData.
	@client
]=]

local function OptionRow(props: {
	Option: BuildingPickerViewModel.TBuildingPickerOption,
	IsSelected: boolean,
	OnActivated: () -> (),
})
	local opt = props.Option
	local isSelectable = opt.IsAffordable and not opt.IsLocked
	local soundActions = useSoundActions()
	local btnRef = useRef(nil :: TextButton?)
	local hover = useHoverSpring(btnRef, {
		HoverScale = AnimationTokens.Interaction.ActionButton.HoverScale,
		PressScale = AnimationTokens.Interaction.ActionButton.PressScale,
		SpringPreset = AnimationTokens.Interaction.ActionButton.SpringPreset,
		Disabled = not isSelectable,
	})

	return e("TextButton", {
		ref = btnRef,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, 48),
		Text = "",
		TextSize = 1,
		[React.Event.MouseEnter] = hover.onMouseEnter,
		[React.Event.MouseLeave] = hover.onMouseLeave,
		[React.Event.Activated] = if isSelectable
			then hover.onActivated(function()
				soundActions.playButtonClick()
				props.OnActivated()
			end)
			else function()
				soundActions.playError()
			end,
	}, {
		UIGradient = e("UIGradient", {
			Color = if props.IsSelected
				then GradientTokens.TAB_ACTIVE_GRADIENT
				else GradientTokens.SLOT_GRADIENT,
			Rotation = -16,
		}),

		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 5),
		}),

		UIStroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			Thickness = if props.IsSelected then 2 else 1,
		}, {
			UIGradient = e("UIGradient", {
				Color = if props.IsSelected
					then GradientTokens.GOLD_STROKE
					else GradientTokens.GOLD_STROKE_SUBTLE,
			}),
		}),

		DimOverlay = if opt.IsLocked or not opt.IsAffordable
			then e("Frame", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.55,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 5,
			}, {
				UICorner = e("UICorner", { CornerRadius = UDim.new(0, 5) }),
			})
			else nil,

		Name = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Font = Typography.Font.Bold,
			Position = UDim2.fromScale(0.04, 0.35),
			Size = UDim2.fromScale(0.7, 0.4),
			Text = opt.BuildingType,
			TextColor3 = if isSelectable then Colors.Text.Primary else Colors.Text.Muted,
			TextSize = Typography.FontSize.Body,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
		}),

		LockedLabel = if opt.IsLocked
			then e("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Font = Typography.Font.Bold,
				Position = UDim2.fromScale(0.96, 0.08),
				Size = UDim2.fromScale(0.24, 0.26),
				Text = "Locked",
				TextColor3 = Colors.Semantic.Error,
				TextSize = Typography.FontSize.Caption,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			else nil,

		Cost = e("TextLabel", {
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
			Font = Typography.Font.Body,
			Position = UDim2.fromScale(0.04, 0.85),
			Size = UDim2.fromScale(0.7, 0.3),
			Text = opt.CostText,
			TextColor3 = if isSelectable then Colors.Accent.Yellow else Colors.Text.Muted,
			TextSize = Typography.FontSize.Caption,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		MaxLevel = e("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Font = Typography.Font.Body,
			Position = UDim2.fromScale(0.96, 0.5),
			Size = UDim2.fromScale(0.22, 0.4),
			Text = opt.MaxLevelText,
			TextColor3 = Colors.Text.Muted,
			TextSize = Typography.FontSize.Caption,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})
end

local function BuildingPickerPanel(props: TBuildingPickerPanelProps)
	local options = props.ViewData.options
	local selectedType, setSelectedType = useState(nil :: string?)
	local isLoading = props.IsLoading == true

	local canConfirm = BuildingPickerViewModel.canConfirm(options, selectedType, isLoading)

	local cancelBtnRef = useRef(nil :: TextButton?)
	local confirmBtnRef = useRef(nil :: TextButton?)
	local cancelHover = useHoverSpring(cancelBtnRef, AnimationTokens.Interaction.ActionButton)
	local confirmHover = useHoverSpring(confirmBtnRef, {
		HoverScale = AnimationTokens.Interaction.ActionButton.HoverScale,
		PressScale = AnimationTokens.Interaction.ActionButton.PressScale,
		SpringPreset = AnimationTokens.Interaction.ActionButton.SpringPreset,
		Disabled = not canConfirm,
	})

	local listChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 7),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0.025, 0),
			PaddingRight = UDim.new(0.025, 0),
			PaddingTop = UDim.new(0, 4),
		}),
	}
	for i, opt in options do
		listChildren["Option_" .. opt.BuildingType] = e(OptionRow, {
			Option = opt,
			IsSelected = selectedType == opt.BuildingType,
			OnActivated = function()
				setSelectedType(opt.BuildingType)
			end,
		})
		local _ = i
	end

	return e("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
	}, {
		UIGradient = e("UIGradient", {
			Color = GradientTokens.LIST_CONTAINER_GRADIENT,
			Rotation = -16,
		}),

		UIStroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			Thickness = 2,
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.GOLD_STROKE_SUBTLE,
			}),
		}),

		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),

		Title = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Font = Typography.Font.Bold,
			Position = UDim2.fromScale(0.5, 0.03),
			Size = UDim2.fromScale(0.9, 0.08),
			Text = "Choose Building — Slot " .. tostring(props.SlotIndex),
			TextColor3 = Colors.Text.Primary,
			TextSize = Typography.FontSize.H3,
			TextWrapped = true,
		}),

		OptionsList = e("ScrollingFrame", {
			AnchorPoint = Vector2.new(0.5, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0.13),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Colors.Accent.Yellow,
			Size = UDim2.fromScale(0.92, 0.72),
		}, listChildren),

		ErrorLabel = if props.ErrorMessage
			then e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Font = Typography.Font.Body,
				Position = UDim2.fromScale(0.5, 0.88),
				Size = UDim2.fromScale(0.92, 0.06),
				Text = props.ErrorMessage,
				TextColor3 = Colors.Semantic.Error,
				TextSize = Typography.FontSize.Caption,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			else nil,

		Actions = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.97),
			Size = UDim2.fromScale(0.92, 0.1),
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),

			CancelButton = e("TextButton", {
				ref = cancelBtnRef,
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				LayoutOrder = 1,
				Size = UDim2.fromScale(0.35, 1),
				Text = "",
				TextSize = 1,
				[React.Event.MouseEnter] = cancelHover.onMouseEnter,
				[React.Event.MouseLeave] = cancelHover.onMouseLeave,
				[React.Event.Activated] = if not isLoading
					then cancelHover.onActivated(props.OnCancel)
					else function() end,
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.ASSIGN_BUTTON_GRADIENT,
					Rotation = -4,
				}),
				UICorner = e("UICorner"),
				Label = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Font = Typography.Font.Bold,
					Interactable = false,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.9, 0.7),
					Text = "Cancel",
					TextColor3 = Colors.Text.Primary,
					TextSize = Typography.FontSize.Small,
				}),
			}),

			ConfirmButton = e("TextButton", {
				ref = confirmBtnRef,
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				LayoutOrder = 2,
				Size = UDim2.fromScale(0.45, 1),
				Text = "",
				TextSize = 1,
				[React.Event.MouseEnter] = confirmHover.onMouseEnter,
				[React.Event.MouseLeave] = confirmHover.onMouseLeave,
				[React.Event.Activated] = if canConfirm
					then confirmHover.onActivated(function()
						if selectedType then
							props.OnConfirm(selectedType)
						end
					end)
					else function() end,
			}, {
				UIGradient = e("UIGradient", {
					Color = if canConfirm
						then GradientTokens.GREEN_ACTION_GRADIENT
						else GradientTokens.TAB_INACTIVE_GRADIENT,
					Rotation = -3,
				}),
				UICorner = e("UICorner"),
				Label = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Font = Typography.Font.Bold,
					Interactable = false,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.9, 0.7),
					Text = if isLoading then "Building..." elseif canConfirm then "Build" else "Select one",
					TextColor3 = if canConfirm then Colors.Text.Primary else Colors.Text.Muted,
					TextSize = Typography.FontSize.Small,
				}),
			}),
		}),
	})
end

return BuildingPickerPanel
