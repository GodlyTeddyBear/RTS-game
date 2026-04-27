--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local AppFrame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local Button = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Button)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local HStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.HStack)
local VStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.VStack)
local useRunPhaseHud = require(script.Parent.Parent.Parent.Application.Hooks.useRunPhaseHud)
local useBaseHud = require(script.Parent.Parent.Parent.Application.Hooks.useBaseHud)
local useCommanderHud = require(script.Parent.Parent.Parent.Application.Hooks.useCommanderHud)
local useResourceHud = require(script.Parent.Parent.Parent.Application.Hooks.useResourceHud)
local AbilityBar = require(script.Parent.AbilityBar)
local PlacementPalette = require(script.Parent.PlacementPalette)
local PrepTimerBar = require(script.Parent.PrepTimerBar)

export type TRunHUDProps = {
	onStructureSelected: ((string) -> ())?,
	onToggleInventory: (() -> ())?,
}

local function _ComputeHealthFillScale(hp: number, maxHp: number): number
	if maxHp <= 0 then
		return 0
	end

	local ratio = hp / maxHp
	return math.clamp(ratio, 0, 1)
end

local function _CreateHealthReadout(label: string, hp: number, maxHp: number, color: Color3, order: number)
	return e(AppFrame, {
		Size = UDim2.fromScale(1, 0.46),
		LayoutOrder = order,
		BackgroundTransparency = 1,
	}, {
		Label = e(Text, {
			Size = UDim2.fromScale(1, 0.45),
			Position = UDim2.fromScale(0, 0),
			Text = ("%s: %d / %d"):format(label, hp, maxHp),
			Variant = "caption",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		BarBackground = e(AppFrame, {
			Size = UDim2.fromScale(1, 0.34),
			Position = UDim2.fromScale(0, 0.88),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Color3.fromRGB(38, 42, 54),
			BackgroundTransparency = 0.12,
			CornerRadius = UDim.new(0, 8),
			ClipsDescendants = true,
		}, {
			Fill = e(AppFrame, {
				Size = UDim2.fromScale(_ComputeHealthFillScale(hp, maxHp), 1),
				Position = UDim2.fromScale(0, 0),
				AnchorPoint = Vector2.new(0, 0),
				BackgroundColor3 = color,
				CornerRadius = UDim.new(0, 8),
			}),
		}),
	})
end

local function RunHUD(props: TRunHUDProps)
	local phaseHud = useRunPhaseHud()
	local commanderHud = useCommanderHud()
	local baseHud = useBaseHud()
	local resourceHud = useResourceHud()

	return e(AppFrame, {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	}, {
		PlacementPalette = e(PlacementPalette, {
			onStructureSelected = props.onStructureSelected,
		}),
		PrepTimerBar = e(PrepTimerBar),
		AbilityBar = e(AbilityBar),
		InventoryButton = props.onToggleInventory and e(Button, {
			Size = UDim2.fromScale(0.1, 0.045),
			Position = UDim2.fromScale(0.93, 0.84),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = "Inventory",
			Variant = "secondary",
			TextScaled = true,
			[React.Event.Activated] = props.onToggleInventory,
		}) or nil,
		Bar = e(AppFrame, {
			Size = UDim2.fromScale(1, 0.12),
			Position = UDim2.fromScale(0.5, 0.99),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
		}, {
			Panel = e(AppFrame, {
				Size = UDim2.fromScale(0.96, 0.9),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(16, 18, 28),
				BackgroundTransparency = 0.2,
				CornerRadius = UDim.new(0, 10),
			}, {
				LeftCluster = e(VStack, {
					Size = UDim2.fromScale(0.36, 1),
					Position = UDim2.fromScale(0.02, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Gap = 2,
					Align = "Start",
					Justify = "Center",
				}, {
					CommanderHealth = _CreateHealthReadout(
						"Commander HP",
						commanderHud.hp,
						commanderHud.maxHp,
						Color3.fromRGB(214, 67, 74),
						1
					),
					BaseHealth = _CreateHealthReadout(
						"Base HP",
						baseHud.hp,
						baseHud.maxHp,
						Color3.fromRGB(74, 156, 232),
						2
					),
				}),
				CenterCluster = e(VStack, {
					Size = UDim2.fromScale(0.28, 0.82),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Gap = 1,
					Align = "Center",
					Justify = "Center",
				}, {
					Phase = e(Text, {
						Size = UDim2.fromScale(1, 0.22),
						Text = phaseHud.phaseLabel,
						Variant = "label",
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
					Wave = e(Text, {
						Size = UDim2.fromScale(1, 0.34),
						Text = phaseHud.waveLabel,
						Variant = "heading",
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
					Status = e(Text, {
						Size = UDim2.fromScale(1, 0.22),
						Text = ("%s | %s"):format(phaseHud.statusText, phaseHud.countdownText),
						Variant = "caption",
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
					Reward = phaseHud.rewardText and e(Text, {
						Size = UDim2.fromScale(1, 0.2),
						Text = phaseHud.rewardText,
						Variant = "caption",
						TextColor3 = Color3.fromRGB(108, 227, 146),
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}) or nil,
				}),
				RightCluster = e(HStack, {
					Size = UDim2.fromScale(0.34, 0.7),
					Position = UDim2.fromScale(0.98, 0.5),
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					Gap = 12,
					Align = "Center",
					Justify = "End",
				}, {
					Energy = e(Text, {
						Size = UDim2.fromScale(0.33, 1),
						Text = if resourceHud.isSyncing then "Energy: Syncing..." else ("Energy: %d"):format(resourceHud.energy),
						Variant = "body",
						TextXAlignment = Enum.TextXAlignment.Right,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
					Metal = e(Text, {
						Size = UDim2.fromScale(0.33, 1),
						Text = ("Metal: %d"):format(resourceHud.metal),
						Variant = "body",
						TextXAlignment = Enum.TextXAlignment.Right,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
					Crystal = e(Text, {
						Size = UDim2.fromScale(0.34, 1),
						Text = ("Crystal: %d"):format(resourceHud.crystal),
						Variant = "body",
						TextXAlignment = Enum.TextXAlignment.Right,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				}),
			}),
		}),
	})
end

return RunHUD
