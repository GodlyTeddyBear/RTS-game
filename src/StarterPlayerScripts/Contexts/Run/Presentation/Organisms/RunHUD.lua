--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local AppFrame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local HStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.HStack)
local VStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.VStack)
local useRunPhaseHud = require(script.Parent.Parent.Parent.Application.Hooks.useRunPhaseHud)
local useCommanderHud = require(script.Parent.Parent.Parent.Application.Hooks.useCommanderHud)
local useResourceHud = require(script.Parent.Parent.Parent.Application.Hooks.useResourceHud)
local AbilityBar = require(script.Parent.AbilityBar)
local PlacementPalette = require(script.Parent.PlacementPalette)
local PrepTimerBar = require(script.Parent.PrepTimerBar)

export type TRunHUDProps = {
	onStructureSelected: ((string) -> ())?,
}

local function _ComputeHealthFillScale(hp: number, maxHp: number): number
	if maxHp <= 0 then
		return 0
	end

	local ratio = hp / maxHp
	return math.clamp(ratio, 0, 1)
end

local function RunHUD(props: TRunHUDProps)
	local phaseHud = useRunPhaseHud()
	local commanderHud = useCommanderHud()
	local resourceHud = useResourceHud()

	local hpScale = _ComputeHealthFillScale(commanderHud.hp, commanderHud.maxHp)

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
				LeftCluster = e(AppFrame, {
					Size = UDim2.fromScale(0.36, 1),
					Position = UDim2.fromScale(0.02, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
				}, {
					HealthLabel = e(Text, {
						Size = UDim2.fromScale(1, 0.38),
						Position = UDim2.fromScale(0, 0.1),
						Text = ("Commander HP: %d / %d"):format(commanderHud.hp, commanderHud.maxHp),
						Variant = "label",
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
					HealthBarBackground = e(AppFrame, {
						Size = UDim2.fromScale(1, 0.28),
						Position = UDim2.fromScale(0, 0.72),
						AnchorPoint = Vector2.new(0, 1),
						BackgroundColor3 = Color3.fromRGB(60, 24, 30),
						BackgroundTransparency = 0.2,
						CornerRadius = UDim.new(0, 8),
						ClipsDescendants = true,
					}, {
						HealthBarFill = e(AppFrame, {
							Size = UDim2.fromScale(hpScale, 1),
							Position = UDim2.fromScale(0, 0),
							AnchorPoint = Vector2.new(0, 0),
							BackgroundColor3 = Color3.fromRGB(214, 67, 74),
							CornerRadius = UDim.new(0, 8),
						}),
					}),
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
						Text = ("Energy: %d"):format(resourceHud.energy),
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
