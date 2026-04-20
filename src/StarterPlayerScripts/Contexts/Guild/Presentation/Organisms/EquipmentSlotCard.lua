--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local HStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.HStack)
local VStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.VStack)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local Button = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Button)

local AdventurerViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.AdventurerViewModel)

export type TEquipmentSlotCardProps = {
	SlotType: string,
	Equipment: AdventurerViewModel.TEquipmentSlotViewModel?,
	OnEquip: () -> (),
	OnUnequip: () -> (),
	LayoutOrder: number?,
}

local function EquipmentSlotCard(props: TEquipmentSlotCardProps)
	local equip = props.Equipment
	local isEquipped = equip ~= nil

	return e(HStack, {
		Size = UDim2.fromScale(1, 0.28),
		Padding = 10,
		Gap = 8,
		Align = "Center",
		Justify = "Start",
		Bg = "Surface.Secondary",
		BorderRadius = UDim.new(0, 6),
		LayoutOrder = props.LayoutOrder,
	}, {
		-- Left: Slot label
		SlotLabel = e(Text, {
			Text = props.SlotType,
			Variant = "label",
			Size = UDim2.fromScale(0.2, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 1,
		}),

		-- Middle: Item info or empty
		ItemInfo = e(VStack, {
			Size = UDim2.fromScale(0.45, 1),
			Gap = 2,
			Align = "Start",
			Justify = "Center",
			LayoutOrder = 2,
		}, {
			ItemName = e(Text, {
				Text = if isEquipped then equip.ItemName else "Empty",
				Variant = "body",
				Color = if isEquipped then "Text.Primary" else "Text.Muted",
				Size = UDim2.fromScale(1, 0.45),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
			}),
			StatsLabel = if isEquipped and equip.StatsLabel ~= ""
				then e(Text, {
					Text = equip.StatsLabel,
					Variant = "caption",
					Color = "Text.Secondary",
					Size = UDim2.fromScale(1, 0.35),
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 2,
				})
				else nil,
		}),

		-- Right: Equip/Unequip button
		ActionArea = e(VStack, {
			Size = UDim2.fromScale(0.25, 1),
			Align = "Center",
			Justify = "Center",
			LayoutOrder = 3,
		}, {
			ActionButton = e(Button, {
				Text = if isEquipped then "Unequip" else "Equip",
				Size = UDim2.fromScale(1, 0.6),
				Variant = if isEquipped then "secondary" else "primary",
				LayoutOrder = 1,
				[React.Event.Activated] = if isEquipped then props.OnUnequip else props.OnEquip,
			}),
		}),
	})
end

return EquipmentSlotCard
