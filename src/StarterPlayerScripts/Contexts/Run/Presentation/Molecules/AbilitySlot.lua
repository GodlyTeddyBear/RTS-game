--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Button = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Button)
local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local Border = require(script.Parent.Parent.Parent.Parent.App.Config.BorderTokens)
local useSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useSpring)
local useAbilityBarHud = require(script.Parent.Parent.Parent.Application.Hooks.useAbilityBarHud)

type TAbilitySlotHudData = useAbilityBarHud.TAbilitySlotHudData

export type TAbilitySlotProps = {
	slotData: TAbilitySlotHudData,
	onActivate: () -> (),
	LayoutOrder: number?,
}

local function _GetCooldownText(slotData: TAbilitySlotHudData): string
	local remaining = math.max(1, math.ceil(slotData.cooldownRemaining))
	return string.format("%ds", remaining)
end

local function AbilitySlot(props: TAbilitySlotProps)
	local spring = useSpring()
	local overlayRef = React.useRef(nil :: Frame?)

	React.useEffect(function()
		if overlayRef.current == nil then
			return
		end

		spring(overlayRef, {
			Size = UDim2.fromScale(1, if props.slotData.isOnCooldown then props.slotData.cooldownProgress else 0),
		}, "Smooth")
	end, { props.slotData.cooldownProgress, props.slotData.isOnCooldown })

	local onActivated = if props.slotData.isOnCooldown then nil else props.onActivate
	local costTextColor = if props.slotData.isOnCooldown or props.slotData.canAfford then Colors.Text.Secondary else Colors.Semantic.Error

	return e(Button, {
		Text = "",
		Size = UDim2.fromScale(0.18, 1),
		LayoutOrder = props.LayoutOrder,
		Variant = "secondary",
		DisableAnimations = props.slotData.isOnCooldown,
		ClipsDescendants = true,
		StrokeColor = ColorSequence.new(Colors.Border.Subtle, Colors.Border.Subtle),
		StrokeThickness = Border.Width.Thin,
		[React.Event.Activated] = onActivated,
	}, {
		CooldownOverlay = e(Frame, {
			ref = overlayRef,
			Size = UDim2.fromScale(1, if props.slotData.isOnCooldown then props.slotData.cooldownProgress else 0),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Colors.Surface.Primary,
			BackgroundTransparency = 0.35,
			ClipsDescendants = true,
			ZIndex = 2,
			CornerRadius = Border.Radius.MD,
		}),
		Content = e(Frame, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, {
			Name = e(Text, {
				Size = UDim2.fromScale(0.9, 0.26),
				Position = UDim2.fromScale(0.5, 0.08),
				AnchorPoint = Vector2.new(0.5, 0),
				Text = props.slotData.displayName,
				Variant = "label",
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
			Cost = e(Text, {
				Size = UDim2.fromScale(0.56, 0.18),
				Position = UDim2.fromScale(0.08, 0.78),
				AnchorPoint = Vector2.new(0, 0),
				Text = string.format("%d E", props.slotData.energyCost),
				Variant = "caption",
				TextColor3 = costTextColor,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
			Cooldown = props.slotData.isOnCooldown and e(Text, {
				Size = UDim2.fromScale(0.6, 0.2),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Text = _GetCooldownText(props.slotData),
				Variant = "heading",
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}) or nil,
		}),
	})
end

return AbilitySlot
