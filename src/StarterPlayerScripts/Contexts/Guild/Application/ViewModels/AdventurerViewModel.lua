--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local AdventurerConfig = require(ReplicatedStorage.Contexts.Guild.Config.AdventurerConfig)
local AdventurerTypes = require(ReplicatedStorage.Contexts.Guild.Types.AdventurerTypes)

type TAdventurer = AdventurerTypes.TAdventurer

export type TEquipmentSlotViewModel = {
	ItemId: string,
	ItemName: string,
	SlotType: string,
	StatsLabel: string,
}

export type TAdventurerViewModel = {
	Id: string,
	Type: string,
	TypeLabel: string,
	Description: string,
	BaseHP: number,
	BaseATK: number,
	BaseDEF: number,
	EffectiveHP: number,
	EffectiveATK: number,
	EffectiveDEF: number,
	HPLabel: string,
	ATKLabel: string,
	DEFLabel: string,
	StatsLabel: string,
	WeaponSlot: TEquipmentSlotViewModel?,
	ArmorSlot: TEquipmentSlotViewModel?,
	AccessorySlot: TEquipmentSlotViewModel?,
}

local AdventurerViewModel = {}

local function _buildEquipmentSlotVM(equipSlot: AdventurerTypes.TEquipmentSlot?): TEquipmentSlotViewModel?
	-- Guard: empty slot has no ViewModel
	if not equipSlot then
		return nil
	end

	-- Look up item metadata
	local itemData = ItemConfig[equipSlot.ItemId]
	local itemName = itemData and itemData.name or equipSlot.ItemId
	local statsLabel = ""

	-- Build stats label from item bonuses (e.g. "+5 STR, +3 DEF")
	if itemData and itemData.stats then
		local parts = {}
		for stat, value in pairs(itemData.stats) do
			table.insert(parts, "+" .. tostring(value) .. " " .. stat)
		end
		statsLabel = table.concat(parts, ", ")
	end

	return {
		ItemId = equipSlot.ItemId,
		ItemName = itemName,
		SlotType = equipSlot.SlotType,
		StatsLabel = statsLabel,
	}
end

local function _getEquipmentBonuses(adventurer: TAdventurer): (number, number)
	local bonusATK = 0
	local bonusDEF = 0

	-- Aggregate all bonuses from equipped items
	if adventurer.Equipment then
		for _, slot in pairs(adventurer.Equipment) do
			if slot and slot.ItemId then
				local itemData = ItemConfig[slot.ItemId]
				if itemData and itemData.stats then
					bonusATK = bonusATK + (itemData.stats.STR or 0)
					bonusDEF = bonusDEF + (itemData.stats.DEF or 0)
				end
			end
		end
	end

	return bonusATK, bonusDEF
end

function AdventurerViewModel.fromAdventurer(adventurer: TAdventurer): TAdventurerViewModel
	-- Load config and description
	local config = AdventurerConfig[adventurer.Type]
	local description = config and config.Description or ""

	-- Calculate effective stats (base + equipment bonuses)
	local bonusATK, bonusDEF = _getEquipmentBonuses(adventurer)
	local effectiveHP = adventurer.BaseHP
	local effectiveATK = adventurer.BaseATK + bonusATK
	local effectiveDEF = adventurer.BaseDEF + bonusDEF

	-- Format bonus labels: only show if > 0 (e.g. "ATK: 15 (+5)")
	local hpBonus = ""
	local atkBonus = if bonusATK > 0 then " (+" .. tostring(bonusATK) .. ")" else ""
	local defBonus = if bonusDEF > 0 then " (+" .. tostring(bonusDEF) .. ")" else ""

	return table.freeze({
		Id = adventurer.Id,
		Type = adventurer.Type,
		TypeLabel = config and config.DisplayName or adventurer.Type,
		Description = description,
		BaseHP = adventurer.BaseHP,
		BaseATK = adventurer.BaseATK,
		BaseDEF = adventurer.BaseDEF,
		EffectiveHP = effectiveHP,
		EffectiveATK = effectiveATK,
		EffectiveDEF = effectiveDEF,
		HPLabel = "HP: " .. tostring(effectiveHP) .. hpBonus,
		ATKLabel = "ATK: " .. tostring(effectiveATK) .. atkBonus,
		DEFLabel = "DEF: " .. tostring(effectiveDEF) .. defBonus,
		StatsLabel = "DEF:" .. tostring(effectiveDEF) .. " HP:" .. tostring(effectiveHP) .. " ATK:" .. tostring(effectiveATK),
		WeaponSlot = _buildEquipmentSlotVM(adventurer.Equipment.Weapon),
		ArmorSlot = _buildEquipmentSlotVM(adventurer.Equipment.Armor),
		AccessorySlot = _buildEquipmentSlotVM(adventurer.Equipment.Accessory),
	} :: TAdventurerViewModel)
end

return AdventurerViewModel
