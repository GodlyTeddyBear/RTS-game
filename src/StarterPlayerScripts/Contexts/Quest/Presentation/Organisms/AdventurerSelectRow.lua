--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)

local PartySelectionViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.PartySelectionViewModel)

--[=[
	@interface TAdventurerSelectRowProps
	Props for a single adventurer selection row.
	@within AdventurerSelectRow
	.vm PartySelectionViewModel.TPartyMemberViewModel -- Adventurer view model with stats
	.IsSelected boolean -- Whether this adventurer is currently selected
	.OnToggle (adventurerId: string) -> () -- Called when select/remove button is clicked
	.LayoutOrder number -- Layout order for list positioning
]=]
export type TAdventurerSelectRowProps = {
	vm: PartySelectionViewModel.TPartyMemberViewModel,
	IsSelected: boolean,
	OnToggle: (adventurerId: string) -> (),
	LayoutOrder: number,
}

local GREY_TEXT = Color3.fromRGB(135, 135, 135)

--[=[
	@class AdventurerSelectRow
	Row component for selecting an adventurer for a party.
	Shows name, type, stats, and select/remove button.
	Button is disabled if adventurer is already on an expedition.
	@client
]=]
local function AdventurerSelectRow(props: TAdventurerSelectRowProps)
	local vm = props.vm
	local btnRef = useRef(nil :: TextButton?)
	local btnHover = useHoverSpring(btnRef, AnimationTokens.Interaction.ActionButton)

	local isDisabled = not vm.IsSelectable
	local btnGradient = if isDisabled
		then GradientTokens.SLOT_GRADIENT
		elseif props.IsSelected then GradientTokens.SLOT_GRADIENT
		else GradientTokens.ASSIGN_BUTTON_GRADIENT

	local btnDecoreStroke = if isDisabled or props.IsSelected
		then GradientTokens.SLOT_DECORE_STROKE
		else GradientTokens.ASSIGN_BUTTON_STROKE

	local btnLabelStrokeColor = if isDisabled or props.IsSelected
		then Color3.fromRGB(30, 30, 30)
		else Color3.fromRGB(96, 2, 4)

	local btnLabel = if props.IsSelected then "Remove" else "Select"

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
			-- Col 1: name + type subtitle
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
					Text = vm.Name,
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
					Text = vm.AdventurerType,
					TextColor3 = GREY_TEXT,
					TextSize = 21,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),

			-- Col 2: ATK / DEF stats
			Info = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Position = UDim2.fromScale(0.2516, 0.5),
				Size = UDim2.fromScale(0.15778, 0.72857),
			}, {
				Atk = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
					Position = UDim2.fromScale(0.25, 0),
					Size = UDim2.fromScale(0.5, 0.43137),
					Text = vm.AtkLabel,
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
					Text = vm.DefLabel,
					TextColor3 = GREY_TEXT,
					TextSize = 21,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),

			-- Col 3: Select / Remove button
			SelectButton = e("TextButton", {
				ref = btnRef,
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				LayoutOrder = 2,
				Position = UDim2.fromScale(0.83937, 0.5),
				Size = UDim2.fromScale(0.13788, 0.72857),
				Text = "",
				TextSize = 1,
				AutoButtonColor = false,
				[React.Event.MouseEnter] = if not isDisabled then btnHover.onMouseEnter else nil,
				[React.Event.MouseLeave] = if not isDisabled then btnHover.onMouseLeave else nil,
				[React.Event.Activated] = if not isDisabled
					then btnHover.onActivated(function()
						props.OnToggle(vm.AdventurerId)
					end)
					else nil,
			}, {
				UIGradient = e("UIGradient", {
					Color = btnGradient,
					Rotation = -4,
				}),

				UICorner = e("UICorner"),

				Decore = e(Frame, {
					Size = UDim2.new(0.94845, 0, 0.82353, 0),
					Position = UDim2.fromScale(0.5, 0.4902),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					CornerRadius = UDim.new(0, 4),
					StrokeColor = btnDecoreStroke,
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
					Text = btnLabel,
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 25,
					TextWrapped = true,
				}, {
					UIStroke = e("UIStroke", {
						Color = btnLabelStrokeColor,
						LineJoinMode = Enum.LineJoinMode.Miter,
						Thickness = 2,
					}),
				}),
			}),
		},
	})
end

return AdventurerSelectRow
