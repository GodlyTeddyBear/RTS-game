--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local HStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.HStack)
local Spacing = require(script.Parent.Parent.Parent.Parent.App.Config.SpacingTokens)
local AbilitySlot = require(script.Parent.Parent.Molecules.AbilitySlot)
local useAbilityBarHud = require(script.Parent.Parent.Parent.Application.Hooks.useAbilityBarHud)

local function AbilityBar()
	local abilityHud = useAbilityBarHud()

	return e(HStack, {
		Size = UDim2.fromScale(0.34, 0.075),
		Position = UDim2.fromScale(0.5, 0.835),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Gap = Spacing.SM,
		Align = "Center",
		Justify = "Center",
	}, (function()
		local children = {}
		for index, slot in abilityHud.slots do
			children[slot.key] = e(AbilitySlot, {
				slotData = slot,
				onActivate = function()
				end,
				LayoutOrder = index,
			})
		end
		return children
	end)())
end

return AbilityBar
